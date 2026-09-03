#!/usr/bin/env python3
"""Generate CNA-Lisp's private CFFI layer and its compiler probes.

The manifest names the bound native surface; it deliberately does not carry a
single C type.  Every type here is read out of the canonical CNA headers, so a
hand-copied signature cannot drift from the ABI it claims to describe.

Outputs
-------
  src/internal/ffi/constants.generated.lisp
  src/internal/ffi/structs.generated.lisp
  src/internal/ffi/functions.generated.lisp
  src/input/keys.generated.lisp
  src/framework/predefined-colors.generated.lisp
  tools/native-abi/probe.generated.c        compile-time prototype + layout gate
  tools/native-abi/valueprobe.generated.c   run-time by-value aggregate gate
  docs/generated/native-abi-manifest.json   the resolved, typed manifest

Usage
-----
  python3 tools/native-abi/generate.py --headers <cna>/modules/c-api/include \
      --baseline <cna>/tools/c-api/abi_baseline.json [--check]
"""
import argparse
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

DO_NOT_EDIT = """;;;; {name} --- GENERATED FILE, DO NOT EDIT.
;;;;
;;;; Produced by tools/native-abi/generate.py from tools/native-abi/manifest.json
;;;; and the canonical CNA C headers.  Edit the manifest, then regenerate:
;;;;
;;;;   python3 tools/native-abi/generate.py --headers <cna>/modules/c-api/include \\
;;;;       --baseline <cna>/tools/c-api/abi_baseline.json
;;;;
;;;; tests/structure/generated-files.lisp fails if this file is stale.
"""

PRIMITIVE = {
    "void": ":void",
    "char": ":char",
    "signed char": ":char",
    "unsigned char": ":unsigned-char",
    "short": ":short",
    "int": ":int",
    "unsigned int": ":unsigned-int",
    "long": ":long",
    "float": ":float",
    "double": ":double",
    "size_t": ":size",
    "int8_t": ":int8",
    "int16_t": ":int16",
    "int32_t": ":int32",
    "int64_t": ":int64",
    "uint8_t": ":uint8",
    "uint16_t": ":uint16",
    "uint32_t": ":uint32",
    "uint64_t": ":uint64",
}


class Error(Exception):
    pass


# --------------------------------------------------------------------------- headers
def read_headers(root):
    d = os.path.join(root, "CNA", "C")
    if not os.path.isdir(d):
        raise Error("no CNA/C directory under %s" % root)
    out = {}
    for name in sorted(os.listdir(d)):
        if name.endswith(".h"):
            with open(os.path.join(d, name), encoding="utf-8") as fh:
                out[name] = fh.read()
    return out


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"//[^\n]*", " ", text)
    return text


SCALAR_TYPEDEF = re.compile(
    r"typedef\s+((?:unsigned\s+|signed\s+)?[A-Za-z_][\w]*(?:\s*\*)?)\s+(CNA_\w+)\s*;")
FUNCPTR_TYPEDEF = re.compile(
    r"typedef\s+([A-Za-z_][\w]*)\s*\(\s*\*\s*(CNA_\w+)\s*\)\s*\(([^;]*?)\)\s*;", re.S)
DEFINE_BODY = re.compile(r"^[ \t]*#define[ \t]+(CNA_[A-Z0-9_]+)[ \t]+(.+?)[ \t]*$", re.M)
INT_C_CALL = re.compile(r"\bU?INT(?:8|16|32|64)_C\s*\(\s*(-?(?:0[xX])?[0-9A-Fa-f]+)\s*\)")
BOOL_CAST = re.compile(r"\(\s*\(\s*CNA_Bool\s*\)\s*(-?\d+)\s*\)")
SAFE_EXPR = re.compile(r"^[-0-9xXa-fA-F()<>|&+~ ]+$")


def const_value(body):
    """Evaluate a #define body that is a plain integral constant expression.

    Anything richer -- a cast to a non-integral type, a call, an identifier the
    header has not already defined -- answers None and is simply not bound.
    """
    body = body.strip()
    body = BOOL_CAST.sub(r"\1", body)
    body = INT_C_CALL.sub(r"(\1)", body)
    body = body.replace("UINT64_MAX", "18446744073709551615")
    if not SAFE_EXPR.match(body):
        return None
    try:
        return int(eval(body, {"__builtins__": {}}, {}))  # noqa: S307 -- guarded by SAFE_EXPR
    except Exception:
        return None


DEFINE_ALIAS = re.compile(r"^[ \t]*#define[ \t]+(CNA_[A-Z0-9_]+)[ \t]+(CNA_[A-Z0-9_]+)[ \t]*$", re.M)
PROTOTYPE = re.compile(
    r"CNA_C_API\s+([A-Za-z_][\w]*(?:\s*\*)?)\s+(cna_\w+)\s*\(([^;{}]*?)\)\s*;", re.S)
STRUCT_DEF = re.compile(r"typedef\s+struct\s+(CNA_\w+)\s*\{(.*?)\}\s*(CNA_\w+)\s*;", re.S)


class Abi:
    def __init__(self, headers, baseline):
        self.headers = headers
        self.baseline = baseline
        self.clean = {k: strip_comments(v) for k, v in headers.items()}
        self.scalar_typedefs = {}
        self.funcptr_typedefs = {}
        self.constants = {}
        self.prototypes = {}
        self.proto_header = {}
        self.struct_fields = {}
        self.struct_header = {}
        self._scan()

    def _scan(self):
        for name, text in self.clean.items():
            for base, alias in SCALAR_TYPEDEF.findall(text):
                self.scalar_typedefs[alias] = " ".join(base.split())
            for ret, alias, args in FUNCPTR_TYPEDEF.findall(text):
                self.funcptr_typedefs[alias] = (ret.strip(), " ".join(args.split()))
            for sname, body, alias in STRUCT_DEF.findall(text):
                try:
                    self.struct_fields[alias] = self._fields(body)
                except Error:
                    continue
                self.struct_header[alias] = name
            for ret, fname, args in PROTOTYPE.findall(text):
                self.prototypes[fname] = (" ".join(ret.split()), " ".join(args.split()))
                self.proto_header[fname] = name
        raw = dict(self.baseline["integers"])
        self.constants = raw
        for name, text in self.headers.items():
            clean = strip_comments(text)
            for alias, target in DEFINE_ALIAS.findall(clean):
                if alias not in self.constants and target in self.constants:
                    self.constants[alias] = self.constants[target]
            for cname, body in DEFINE_BODY.findall(clean):
                if cname in self.constants:
                    continue
                value = const_value(body)
                if value is not None:
                    self.constants[cname] = value

    @staticmethod
    def _fields(body):
        out = []
        for decl in body.split(";"):
            decl = " ".join(decl.split())
            if not decl:
                continue
            m = re.match(r"^(.*?)\s*(\w+)\s*(\[\s*([^\]]+?)\s*\])?$", decl)
            if not m:
                out.append(("<unparsed>", decl, None))
                continue
            ctype, fname, count = m.group(1), m.group(2), m.group(4)
            n = None
            if count is not None:
                try:
                    n = int(count, 0)
                except ValueError:
                    n = count
            out.append((ctype.strip(), fname, n))
        return out

    # ---- type resolution -------------------------------------------------
    def resolve(self, ctype):
        """Resolve a C type spelling to (kind, detail)."""
        t = " ".join(ctype.replace("const", " ").split())
        if t.endswith("*"):
            return ("pointer", t)
        if t in PRIMITIVE:
            return ("scalar", PRIMITIVE[t])
        if t in self.funcptr_typedefs:
            return ("pointer", t)
        seen = set()
        cur = t
        while cur in self.scalar_typedefs and cur not in seen:
            seen.add(cur)
            cur = self.scalar_typedefs[cur]
            if cur.endswith("*"):
                return ("pointer", t)
            if cur in PRIMITIVE:
                return ("scalar", PRIMITIVE[cur])
        if t in self.struct_fields:
            return ("aggregate", t)
        raise Error("unresolvable C type %r" % ctype)

    # ---- System V AMD64 classification for small aggregates --------------
    def eightbyte_classes(self, sname):
        """Return the SysV class of each eightbyte of a <=16 byte aggregate."""
        layout = self.baseline["structs"][sname]
        size = layout["size"]
        if size > 16:
            return None
        n = (size + 7) // 8
        classes = ["NO_CLASS"] * n
        for ctype, fname, count in self.struct_fields[sname]:
            off, fsize = layout["fields"][fname]
            elems = count or 1
            esize = fsize // elems
            base = self.resolve(ctype)
            for i in range(elems):
                o = off + i * esize
                for eb in range(o // 8, (o + esize - 1) // 8 + 1):
                    if base[0] == "scalar" and base[1] in (":float", ":double"):
                        cls = "SSE"
                    else:
                        cls = "INTEGER"
                    if classes[eb] == "NO_CLASS":
                        classes[eb] = cls
                    elif classes[eb] != cls:
                        classes[eb] = "INTEGER"
        return [c if c != "NO_CLASS" else "INTEGER" for c in classes]


# --------------------------------------------------------------------------- naming
def lisp_name(cname):
    """CNA_Texture2DDecodeInfo -> cna-texture-2d-decode-info; cna_game_run -> cna-game-run."""
    out = []
    for part in cname.split("_"):
        if not part:
            continue
        part = re.sub(r"(\d)D(?=[A-Z]|$)", r"\1d", part)
        chunks = re.findall(r"[A-Z]+(?![a-z])|[A-Z][a-z]*|\d+[a-z]*|[a-z]+", part)
        out.extend(c.lower() for c in chunks) if chunks else out.append(part.lower())
    return "-".join(out)


def lisp_const_name(cname):
    return "+" + cname[len("CNA_"):].replace("_", "-").lower() + "+"


def keyword_of(cname, prefix):
    return ":" + cname[len(prefix):].replace("_", "-").lower()


# --------------------------------------------------------------------------- emit
def cffi_type(kind, detail, abi):
    if kind == "scalar":
        return detail
    if kind == "pointer":
        return ":pointer"
    raise Error("aggregate reached cffi_type")


def flatten_aggregate(sname, abi):
    """Return the list of CFFI scalar types one by-value aggregate becomes."""
    layout = abi.baseline["structs"][sname]
    size = layout["size"]
    classes = abi.eightbyte_classes(sname)
    if classes is None:
        raise Error(
            "%s is %d bytes: the System V AMD64 ABI classifies it MEMORY, which CFFI "
            "cannot express without cffi-libffi. Route left unbound." % (sname, size))
    if any(c != "INTEGER" for c in classes):
        raise Error(
            "%s has a non-INTEGER eightbyte (%s): passing it in an SSE register is not "
            "expressible in CFFI without cffi-libffi. Route left unbound."
            % (sname, ",".join(classes)))
    out = []
    remaining = size
    for _ in classes:
        chunk = min(8, remaining)
        out.append({1: ":uint8", 2: ":uint16", 4: ":uint32", 8: ":uint64"}.get(chunk))
        if out[-1] is None:
            raise Error("%s has an eightbyte of %d bytes, which has no scalar of the same "
                        "width" % (sname, chunk))
        remaining -= chunk
    return out


def split_args(args):
    args = args.strip()
    if args in ("", "void"):
        return []
    out, depth, cur = [], 0, ""
    for ch in args:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def parse_param(decl):
    decl = " ".join(decl.split())
    m = re.match(r"^(.*?)([A-Za-z_]\w*)$", decl)
    if not m:
        raise Error("cannot parse parameter %r" % decl)
    ctype, pname = m.group(1).strip(), m.group(2)
    if not ctype:
        return (decl, "arg")
    return (ctype, pname)


def build(abi, manifest):
    resolved = {"functions": [], "structs": [], "constants": {}, "callbacks": []}

    # ---- constants -------------------------------------------------------
    consts = {}
    for name in manifest["constants"]["from_headers"]:
        if name not in abi.constants:
            raise Error("constant %s is not defined by the supplied headers" % name)
        consts[name] = abi.constants[name]
    families = {}
    for fam in manifest["constants"]["prefix_families"]:
        pref = fam["prefix"]
        excl = tuple(fam.get("exclude_prefixes", ()))
        members = {}
        for cname, value in sorted(abi.constants.items()):
            if cname.startswith(pref) and not cname.startswith(excl):
                if cname.endswith("_MAXIMUM") or cname.endswith("_COUNT"):
                    continue
                members[cname] = value
        if not members:
            raise Error("prefix family %s matched nothing" % pref)
        families[fam["lisp_family"]] = members
        consts.update(members)
    resolved["constants"] = consts

    # ---- structs ---------------------------------------------------------
    for spec in manifest["structs"]:
        sname = spec["name"]
        if sname not in abi.baseline["structs"]:
            raise Error("struct %s is absent from the ABI baseline" % sname)
        if sname not in abi.struct_fields:
            raise Error("struct %s is absent from the supplied headers" % sname)
        layout = abi.baseline["structs"][sname]
        fields = []
        for ctype, fname, count in abi.struct_fields[sname]:
            if fname not in layout["fields"]:
                raise Error("field %s.%s is absent from the ABI baseline" % (sname, fname))
            off, fsize = layout["fields"][fname]
            kind, detail = abi.resolve(ctype)
            fields.append({
                "name": fname, "c_type": ctype, "offset": off, "size": fsize,
                "count": count,
                "cffi_type": (":pointer" if kind in ("pointer", "aggregate") else detail)
                if not (kind == "aggregate") else "AGGREGATE:" + detail,
                "kind": kind,
            })
        entry = {
            "name": sname, "size": layout["size"], "align": layout["align"],
            "fields": fields, "header": abi.struct_header[sname],
            "direction": spec["direction"], "versioned": spec["versioned"],
        }
        if spec.get("by_value"):
            entry["by_value_flattening"] = flatten_aggregate(sname, abi)
            entry["eightbyte_classes"] = abi.eightbyte_classes(sname)
        resolved["structs"].append(entry)

    # ---- callbacks -------------------------------------------------------
    for spec in manifest["callbacks"]:
        name = spec["name"]
        if name not in abi.funcptr_typedefs:
            raise Error("callback typedef %s is absent from the supplied headers" % name)
        ret, args = abi.funcptr_typedefs[name]
        params = []
        for decl in split_args(args):
            ctype, pname = parse_param(decl)
            kind, detail = abi.resolve(ctype)
            if kind == "aggregate":
                raise Error("callback %s takes an aggregate by value" % name)
            params.append({"name": pname, "c_type": ctype,
                           "cffi_type": ":pointer" if kind == "pointer" else detail})
        rk, rd = abi.resolve(ret)
        resolved["callbacks"].append(
            {"name": name, "returns": rd if rk == "scalar" else ":pointer",
             "c_returns": ret, "params": params})

    # ---- functions -------------------------------------------------------
    byval_ok = {s["name"]: s.get("by_value_flattening") for s in resolved["structs"]}
    for spec in manifest["functions"]:
        fname = spec["name"]
        if fname not in abi.prototypes:
            raise Error("function %s is absent from the supplied headers" % fname)
        if fname not in abi.baseline["exports"]:
            raise Error("function %s is absent from the ABI baseline export list" % fname)
        hdr = abi.proto_header[fname]
        if hdr != spec["header"]:
            raise Error("function %s is declared in %s, not %s"
                        % (fname, hdr, spec["header"]))
        ret, args = abi.prototypes[fname]
        rk, rd = abi.resolve(ret)
        if rk == "aggregate":
            raise Error("function %s returns an aggregate by value" % fname)
        params = []
        for decl in split_args(args):
            ctype, pname = parse_param(decl)
            kind, detail = abi.resolve(ctype)
            if kind == "aggregate":
                flat = byval_ok.get(detail)
                if flat is None:
                    raise Error(
                        "function %s takes %s by value but the manifest does not admit that "
                        "aggregate for by-value passing" % (fname, detail))
                for i, cf in enumerate(flat):
                    params.append({"name": "%s-%d" % (pname, i), "c_type": detail,
                                   "cffi_type": cf, "flattened_from": detail,
                                   "eightbyte": i})
            else:
                params.append({"name": pname, "c_type": ctype,
                               "cffi_type": ":pointer" if kind == "pointer" else detail})
        resolved["functions"].append({
            "name": fname, "header": hdr, "c_returns": ret,
            "returns": rd if rk == "scalar" else ":pointer",
            "params": params, "thread": spec["thread"], "ownership": spec["ownership"],
            "string_rule": spec.get("string_rule"),
            "c_prototype": "%s %s(%s)" % (ret, fname, args or "void"),
        })
    # ---- blocked routes: the refusal is proved, not asserted -------------
    resolved["blocked_routes"] = []
    for spec in manifest.get("blocked_routes", []):
        fname = spec["name"]
        if fname not in abi.prototypes:
            raise Error("blocked route %s is absent from the supplied headers" % fname)
        if fname not in abi.baseline["exports"]:
            raise Error("blocked route %s is absent from the ABI baseline export list" % fname)
        ret, args = abi.prototypes[fname]
        proof = None
        for decl in split_args(args):
            ctype, _ = parse_param(decl)
            kind, detail = abi.resolve(ctype)
            if kind == "aggregate":
                try:
                    flatten_aggregate(detail, abi)
                except Error as exc:
                    proof = str(exc)
                    break
        if proof is None:
            raise Error("blocked route %s is not actually blocked by the manifest rule; "
                        "bind it instead of claiming it is blocked" % fname)
        resolved["blocked_routes"].append({
            "name": fname, "header": abi.proto_header[fname],
            "c_prototype": "%s %s(%s)" % (ret, fname, args or "void"),
            "reason_code": spec["reason_code"], "reason": spec["reason"],
            "generator_proof": proof,
        })
    return resolved, families


# --------------------------------------------------------------------------- writers
def emit_constants(resolved, families):
    out = [DO_NOT_EDIT.format(name="constants.generated.lisp"),
           "(in-package #:cna-lisp.internal.ffi)\n"]
    out.append(";;; Every integral constant this binding depends on, exactly as the\n"
               ";;; canonical headers define it.\n")
    for name in sorted(resolved["constants"]):
        out.append("(defconstant %s %d)" % (lisp_const_name(name), resolved["constants"][name]))
    out.append("")
    for fam, members in sorted(families.items()):
        out.append(";;; %s family: %d members." % (fam, len(members)))
        out.append("(defparameter *%s-table*" % fam)
        out.append("  '(" + "\n    ".join(
            "(%s . %d)" % (keyword_of(c, "CNA_" + fam.replace("-", "_").upper() + "_")
                           if False else keyword_of(c, _family_prefix(fam)), v)
            for c, v in sorted(members.items(), key=lambda kv: (kv[1], kv[0]))) + ")")
        out.append("  \"Keyword name and exact ABI value of every %s member.\")" % fam)
        out.append("")
    return "\n".join(out) + "\n"


def _family_prefix(fam):
    return {"keys": "CNA_KEY_", "surface-format": "CNA_SURFACE_FORMAT_"}[fam]


def emit_structs(resolved):
    out = [DO_NOT_EDIT.format(name="structs.generated.lisp"),
           "(in-package #:cna-lisp.internal.ffi)\n"]
    for s in resolved["structs"]:
        out.append(";;; %s -- %d bytes, %d-byte aligned, from %s."
                   % (s["name"], s["size"], s["align"], s["header"]))
        if "by_value_flattening" in s:
            out.append(";;; Passed by value as %s (System V AMD64 eightbyte classes: %s)."
                       % (" ".join(s["by_value_flattening"]),
                          " ".join(s["eightbyte_classes"])))
        out.append("(defcstruct (%s :size %d)" % (lisp_name(s["name"]), s["size"]))
        for f in s["fields"]:
            ctype = f["cffi_type"]
            if ctype.startswith("AGGREGATE:"):
                ctype = "(:struct %s)" % lisp_name(ctype[len("AGGREGATE:"):])
            if f["count"]:
                out.append("  (%s %s :offset %d :count %d)"
                           % (lisp_name(f["name"]), ctype, f["offset"], f["count"]))
            else:
                out.append("  (%s %s :offset %d)" % (lisp_name(f["name"]), ctype, f["offset"]))
        out[-1] += ")"
        out.append("")
        out.append("(defconstant +sizeof-%s+ %d)" % (lisp_name(s["name"]), s["size"]))
        out.append("(defconstant +alignof-%s+ %d)" % (lisp_name(s["name"]), s["align"]))
        out.append("")
    out.append(";;; Offsets and sizes the ABI gate re-checks against CFFI's own view.")
    out.append("(defparameter *native-struct-layouts*")
    rows = []
    for s in resolved["structs"]:
        fields = " ".join("(%s %d %d)" % (lisp_name(f["name"]), f["offset"], f["size"])
                          for f in s["fields"])
        rows.append("    (%s %d %d %s)" % (lisp_name(s["name"]), s["size"], s["align"],
                                           "(" + fields + ")"))
    out.append("  '(\n" + "\n".join(rows) + ")")
    out.append("  \"NAME SIZE ALIGN ((FIELD OFFSET SIZE)...) for every bound native struct.\")")
    out.append("")
    return "\n".join(out) + "\n"


def emit_functions(resolved):
    out = [DO_NOT_EDIT.format(name="functions.generated.lisp"),
           "(in-package #:cna-lisp.internal.ffi)\n"]
    out.append(";;; One DEFCFUN per bound native route. A by-value aggregate parameter\n"
               ";;; appears as one scalar per System V AMD64 eightbyte; see\n"
               ";;; docs/native-abi.md for why, and tools/native-abi/valueprobe.generated.c\n"
               ";;; for the run-time proof that it is exact.\n")
    for f in resolved["functions"]:
        out.append(";;; %s" % f["c_prototype"])
        args = " ".join("(%s %s)" % (lisp_name(p["name"]), p["cffi_type"]) for p in f["params"])
        out.append("(defcfun (\"%s\" %%%s) %s%s%s)"
                   % (f["name"], lisp_name(f["name"])[len("cna-"):], f["returns"],
                      "\n  " if args else "", args))
        out.append("")
    out.append("(defparameter *bound-native-functions*")
    out.append("  '(" + "\n    ".join(
        "(\"%s\" %s %s :thread %s :ownership %s)"
        % (f["name"], f["returns"],
           "(" + " ".join(p["cffi_type"] for p in f["params"]) + ")",
           ":" + f["thread"], "\"" + f["ownership"] + "\"")
        for f in resolved["functions"]) + ")")
    out.append("  \"Every native route this binding may call, with its bound CFFI shape.\")")
    out.append("")
    return "\n".join(out) + "\n"


def emit_colors(baseline):
    colors = baseline["colors"]
    out = [DO_NOT_EDIT.format(name="predefined-colors.generated.lisp"),
           "(in-package #:cna-lisp.internal.framework)\n"]
    out.append(";;; The %d predefined Microsoft.Xna.Framework.Color values, as unpacked\n"
               ";;; RGBA bytes.  CNA carries them because XNA does; the values here are\n"
               ";;; the ABI's own.\n" % len(colors))
    out.append("(defparameter *predefined-colors*")
    rows = []
    for cname in sorted(colors):
        r, g, b, a = colors[cname]
        rows.append("    (%s %d %d %d %d)"
                    % (keyword_of(cname, "CNA_COLOR_"), r, g, b, a))
    out.append("  '(\n" + "\n".join(rows) + "))")
    out.append("")
    return "\n".join(out) + "\n"


C_HEAD = """/* {name} --- GENERATED FILE, DO NOT EDIT.
 *
 * Produced by tools/native-abi/generate.py.  This translation unit is compiled
 * against the canonical CNA headers by tools/native-abi/verify.sh; it never
 * ships and is never linked into CNA-Lisp.
 */
#include <CNA/C/cna.h>
#include <stddef.h>
#include <stdint.h>
"""


def emit_probe(resolved):
    out = [C_HEAD.format(name="probe.generated.c")]
    out.append("/* --- struct layout: every size, alignment, field offset and field size --- */")
    for s in resolved["structs"]:
        out.append('_Static_assert(sizeof(%s) == %d, "%s size");'
                   % (s["name"], s["size"], s["name"]))
        out.append('_Static_assert(_Alignof(%s) == %d, "%s alignment");'
                   % (s["name"], s["align"], s["name"]))
        for f in s["fields"]:
            out.append('_Static_assert(offsetof(%s, %s) == %d, "%s.%s offset");'
                       % (s["name"], f["name"], f["offset"], s["name"], f["name"]))
            out.append('_Static_assert(sizeof(((%s *)0)->%s) == %d, "%s.%s size");'
                       % (s["name"], f["name"], f["size"], s["name"], f["name"]))
        out.append("")
    out.append("/* --- prototypes: assigning each route to its declared type is a compile\n"
               "   error unless the declaration matches exactly --- */")
    for f in resolved["functions"]:
        params = ", ".join(_c_param_types(f)) or "void"
        out.append("%s (*const cna_lisp_probe_%s)(%s) = %s;"
                   % (f["c_returns"], f["name"], params, f["name"]))
    out.append("")
    out.append("/* --- callbacks --- */")
    for c in resolved["callbacks"]:
        out.append('_Static_assert(sizeof(%s) == sizeof(void (*)(void)), "%s size");'
                   % (c["name"], c["name"]))
    out.append("")
    out.append("/* --- constants --- */")
    for name, value in sorted(resolved["constants"].items()):
        out.append('_Static_assert((int64_t)(%s) == INT64_C(%d), "%s value");'
                   % (name, value, name))
    out.append("")
    out.append("int cna_lisp_probe_ok(void) { return 1; }")
    return "\n".join(out) + "\n"


def _c_param_types(f):
    """Reconstruct the C parameter type list from the resolved prototype."""
    types, i = [], 0
    seen = set()
    for p in f["params"]:
        if "flattened_from" in p:
            if (p["flattened_from"], p["name"].rsplit("-", 1)[0]) in seen:
                continue
            seen.add((p["flattened_from"], p["name"].rsplit("-", 1)[0]))
            types.append(p["flattened_from"])
        else:
            types.append(p["c_type"])
        i += 1
    return types


def emit_valueprobe(resolved):
    """A tiny shared object whose functions receive each admitted by-value
    aggregate and report the bytes that actually arrived."""
    byval = [s for s in resolved["structs"] if "by_value_flattening" in s]
    out = [C_HEAD.format(name="valueprobe.generated.c")]
    out.append("#include <string.h>\n")
    out.append("/* Each function below has exactly the prototype a real CNA route has for\n"
               "   this aggregate.  CNA-Lisp calls it through the flattened CFFI shape the\n"
               "   generator produced; if the flattening were wrong for this platform the\n"
               "   bytes copied out would differ. */")
    for s in byval:
        n = s["name"]
        out.append("void cna_lisp_valueprobe_%s(%s value, unsigned char *out)"
                   % (n.lower(), n))
        out.append("{")
        out.append("    memcpy(out, &value, sizeof(value));")
        out.append("}")
        out.append("")
        out.append("void cna_lisp_valueprobe_%s_after(int32_t before, %s value, "
                   "int32_t after, unsigned char *out, int32_t *out_before, int32_t *out_after)"
                   % (n.lower(), n))
        out.append("{")
        out.append("    memcpy(out, &value, sizeof(value));")
        out.append("    *out_before = before;")
        out.append("    *out_after = after;")
        out.append("}")
        out.append("")
    out.append("int cna_lisp_valueprobe_count(void) { return %d; }" % len(byval))
    return "\n".join(out) + "\n"


# --------------------------------------------------------------------------- main
def sha256_of(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def write(path, text, check, changed):
    full = os.path.join(ROOT, path)
    old = None
    if os.path.exists(full):
        with open(full, encoding="utf-8") as fh:
            old = fh.read()
    if old == text:
        return
    changed.append(path)
    if check:
        return
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as fh:
        fh.write(text)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--headers", required=True)
    ap.add_argument("--baseline", required=True)
    ap.add_argument("--check", action="store_true",
                    help="write nothing; exit 1 if any output is stale")
    args = ap.parse_args(argv)

    with open(args.baseline, encoding="utf-8") as fh:
        baseline = json.load(fh)
    baseline["exports"] = set(baseline["exports"])
    abi = Abi(read_headers(args.headers), baseline)
    with open(os.path.join(HERE, "manifest.json"), encoding="utf-8") as fh:
        manifest = json.load(fh)

    admitted = {v["encoded"] for v in manifest["admitted_abi_versions"]}
    if baseline["abi_version"]["encoded"] not in admitted:
        raise Error("supplied headers declare ABI %s, which the manifest does not admit"
                    % baseline["abi_version"])

    resolved, families = build(abi, manifest)
    changed = []
    write("src/internal/ffi/constants.generated.lisp",
          emit_constants(resolved, families), args.check, changed)
    write("src/internal/ffi/structs.generated.lisp", emit_structs(resolved), args.check, changed)
    write("src/internal/ffi/functions.generated.lisp",
          emit_functions(resolved), args.check, changed)
    write("src/framework/predefined-colors.generated.lisp",
          emit_colors(baseline), args.check, changed)
    write("tools/native-abi/probe.generated.c", emit_probe(resolved), args.check, changed)
    write("tools/native-abi/valueprobe.generated.c",
          emit_valueprobe(resolved), args.check, changed)

    report = {
        "schema_version": 1,
        "abi_version": {k: v for k, v in baseline["abi_version"].items()},
        "admitted_abi_versions": manifest["admitted_abi_versions"],
        "by_value_aggregate_rule": manifest["by_value_aggregate_rule"],
        "counts": {
            "functions": len(resolved["functions"]),
            "structs": len(resolved["structs"]),
            "struct_fields": sum(len(s["fields"]) for s in resolved["structs"]),
            "constants": len(resolved["constants"]),
            "callbacks": len(resolved["callbacks"]),
            "by_value_aggregates": sum(
                1 for s in resolved["structs"] if "by_value_flattening" in s),
            "blocked_routes": len(resolved["blocked_routes"]),
        },
        "blocked_routes": resolved["blocked_routes"],
        "functions": resolved["functions"],
        "structs": resolved["structs"],
        "callbacks": resolved["callbacks"],
        "constants": {k: resolved["constants"][k] for k in sorted(resolved["constants"])},
    }
    write("docs/generated/native-abi-manifest.json",
          json.dumps(report, indent=2, sort_keys=False) + "\n", args.check, changed)

    if args.check:
        if changed:
            sys.stderr.write("stale generated files:\n  " + "\n  ".join(changed) + "\n")
            return 1
        print("generated files are current")
        return 0
    print("wrote %d file(s); %d functions, %d structs, %d constants, %d callbacks"
          % (len(changed), len(resolved["functions"]), len(resolved["structs"]),
             len(resolved["constants"]), len(resolved["callbacks"])))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Error as exc:
        sys.stderr.write("error: %s\n" % exc)
        sys.exit(2)
