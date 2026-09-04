#!/usr/bin/env python3
"""Structural compatibility verifier for CNA-Lisp.

Compares the live public surface -- dumped by tools/api-compat/dump-surface.lisp
straight out of the image -- against the hash-pinned XNA 4.0 Windows contract
subset, using the deterministic projection rules in mapping-rules.json.

Every selected type and member is classified as one of

    complete | partial | missing | not-applicable | externally-blocked

and every disagreement is recorded under one of the diagnostic categories below.
Strict verification is allowed to be red while real surface is missing. It is
never allowed to be green because something was hidden.

  python3 tools/api-compat/verify.py [--surface F] [--output F] [--strict]
"""
import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

CATEGORIES = [
    "missing_type",
    "missing_member",
    "wrong_package",
    "wrong_kind",
    "wrong_superclass",
    "wrong_generic_function_shape",
    "wrong_lambda_list",
    "wrong_accessor_mutability",
    "overload_mapping_mismatch",
    "event_mapping_mismatch",
    "enum_mismatch",
    "unexpected_public_symbol",
    "private_implementation_leak",
    "unmeasured_category",
    "stale_mapping_rule",
    "wrong_overload_shape",
]

# Categories that mean the binding disagrees with the contract or hides something,
# rather than simply not having reached a member yet. A qualified milestone
# requires every one of these to be zero.
DISAGREEMENT = [c for c in CATEGORIES if c not in ("missing_type", "missing_member")]


def kebab(name):
    """PascalCase -> kebab-case, the way the mapping document specifies."""
    name = re.sub(r"(\d)D(?=[A-Z]|$)", r"\1d", name)
    chunks = re.findall(r"[A-Z]+(?![a-z])|[A-Z][a-z]*|\d+[a-z]*|[a-z]+", name)
    return "-".join(c.lower() for c in chunks)


def simple(type_name):
    """The short spelling of a CLR type, keeping array-ness and by-reference-ness.

    An array parameter must stay distinguishable from a single value: XNA has
    both Transform(Vector3, Matrix) and Transform(Vector3[], ref Matrix,
    Vector3[]), and collapsing them would let one rule silently claim the other.
    """
    if not type_name:
        return type_name
    suffix = "[]" if type_name.endswith("[]") else ""
    base = type_name[:-2] if suffix else type_name
    base = base.split("[")[0]
    return base.split(".")[-1] + suffix


def signature(member):
    if member["kind"] in ("method", "constructor"):
        params = ",".join(simple(p["type"]) for p in member.get("parameters", []))
        name = "new" if member["kind"] == "constructor" else member["name"]
        return "%s(%s)" % (name, params)
    return member["name"]


class Report:
    def __init__(self):
        self.diagnostics = []
        self.types = []

    def add(self, category, subject, detail):
        assert category in CATEGORIES, category
        self.diagnostics.append(
            {"category": category, "subject": subject, "detail": detail})

    def counts(self):
        result = {c: 0 for c in CATEGORIES}
        for d in self.diagnostics:
            result[d["category"]] += 1
        return result


def load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def index_surface(surface):
    packages = {}
    for entry in surface["packages"]:
        packages[entry["package"]] = {s["name"]: s for s in entry["symbols"]}
    return packages


def expected_symbol(rules, type_rule, type_name, member):
    """The Lisp symbol name the projection rules require for one member."""
    sig = signature(member)
    override = type_rule.get("member_overrides", {}).get(sig)
    if override and "lisp" in override:
        return override["lisp"], override
    lisp_type = type_rule["lisp_name"]
    kind = type_rule["lisp_kind"]
    if member["kind"] == "constructor":
        declared = type_rule.get("constructors", {}).get(sig)
        if declared is None:
            return False, override or {}
        return declared, override or {}
    base = kebab(member["name"])
    if kind in ("structure", "static"):
        return "%s-%s" % (lisp_type, base), override or {}
    if kind == "interface":
        # An interface member has no instance to prefix with, and the rules name
        # it explicitly, so an interface with no override for a member is a
        # missing projection rather than a guess.
        return False, override or {}
    return base, override or {}


def enum_key(name):
    """The comparison key for an enum member name.

    The XNA identifier and the CNA constant disagree on where a hyphen goes
    around a digit -- Dxt1 against DXT1, Bgra4444 against BGRA4444 -- so both
    sides are compared with the separators removed. Two distinct members that
    collapsed to the same key would be a real ambiguity, and is reported.
    """
    return re.sub(r"[^a-z0-9]", "", name.lower())


def verify_enum(report, rules, type_rule, contract_type, surface):
    """An enum's members are keywords; check every one against the runtime table."""
    table_name = type_rule["lisp_name"]
    table = surface["enum_tables"].get(table_name)
    statuses = {}
    if table is None:
        report.add("enum_mismatch", contract_type["name"],
                   "no runtime table named %r" % table_name)
        return {signature(m): "missing" for m in contract_type["members"]
                if m["name"] != "value__"}

    runtime = {}
    for keyword, value in table.items():
        key = enum_key(keyword)
        if key in runtime:
            report.add("enum_mismatch", "%s.%s" % (contract_type["name"], keyword),
                       "two runtime members share the comparison key %r" % key)
        runtime[key] = (keyword, value)

    matched = set()
    for member in contract_type["members"]:
        sig = signature(member)
        if member["name"] == "value__":
            statuses[sig] = "not-applicable"
            continue
        override = type_rule.get("member_overrides", {}).get(sig, {})
        key = enum_key(override.get("lisp", member["name"]))
        if key in runtime:
            statuses[sig] = "complete"
            matched.add(key)
        else:
            statuses[sig] = "missing"
            report.add("missing_member", "%s.%s" % (contract_type["name"], member["name"]),
                       "no matching member in the %s table" % table_name)
    allowed = {enum_key(name) for name in type_rule.get("extra_enum_members", [])}
    for key in sorted(set(runtime) - matched):
        if key in allowed:
            continue
        report.add("enum_mismatch",
                   "%s.%s" % (contract_type["name"], runtime[key][0]),
                   "the runtime table has a member the contract does not, and no rule "
                   "declares it")
    return statuses


RULE_SECTIONS = ("member_overrides", "not_applicable", "unimplemented", "constructors",
                 "blocked")

# How an overload family may collapse onto one Lisp function. A family that
# collapses has to name one of these, and a member that claims "keywords" has to
# list them, so that "one function expresses them all" is checkable rather than
# assertable.
DISTINGUISHING_MECHANISMS = frozenset((
    "dispatch",              # CLOS dispatch on an argument's type
    "arity",                 # a trailing optional argument
    "dispatch-and-arity",    # both
    "keywords",              # a declared keyword set, listed per overload
    # The one overload of a keyword-distinguished family that supplies *no*
    # keyword. SpriteBatch.Begin() is the case: it is a real overload, it is told
    # from its siblings by the absence of every keyword they use, and there is no
    # keyword set to list for it. A family may declare this for at most one
    # overload, because two overloads that both supply nothing would be the same
    # call.
    "no-keywords",
))


def verify_rule_freshness(report, type_rule, contract_type):
    """Every key in a type's rules must name a member the contract actually has.

    A rule keyed on a signature that no member produces is worse than no rule: it
    is silently ignored, the default naming rule applies instead, and the member
    is reported under a mapping nobody wrote. That is exactly how five
    SpriteBatch.Draw overloads came to be reported missing while a rule for each
    of them sat in this file being skipped.
    """
    name = contract_type["name"]
    present = {signature(m) for m in contract_type["members"]}
    constructors = {signature(m) for m in contract_type["members"]
                    if m["kind"] == "constructor"}
    for key in sorted(type_rule.get("events", {})):
        if key not in {m["name"] for m in contract_type["members"]
                       if m["kind"] == "event"}:
            report.add("stale_mapping_rule", "%s events[%s]" % (name, key),
                       "no event of this type has that name")
    for section in RULE_SECTIONS:
        expected = constructors if section == "constructors" else present
        for key in sorted(type_rule.get(section, {})):
            if key not in expected:
                report.add("stale_mapping_rule", "%s %s[%s]" % (name, section, key),
                           "no member of this type has that signature")
    families = {m["name"] for m in contract_type["members"]}
    families.add(".ctor")
    for key in sorted(type_rule.get("overload_families", {})):
        if key not in families:
            report.add("stale_mapping_rule", "%s overload_families[%s]" % (name, key),
                       "no member of this type has that name")


def verify_type(report, rules, contract_type, surface, packages, claimed):
    name = contract_type["name"]
    type_rule = rules["types"].get(name)
    if type_rule is None:
        report.add("unmeasured_category", name, "no projection rule for this type")
        return {"name": name, "status": "unmeasured", "members": {}}

    verify_rule_freshness(report, type_rule, contract_type)

    if type_rule.get("status") == "missing":
        for member in contract_type["members"]:
            report.add("missing_member", "%s.%s" % (name, member["name"]),
                       "the type itself is not projected")
        report.add("missing_type", name, type_rule.get("reason", "not projected"))
        return {"name": name, "status": "missing",
                "reason": type_rule.get("reason"),
                "members": {signature(m): "missing" for m in contract_type["members"]}}

    package = type_rule["lisp_package"]
    symbols = packages.get(package)
    if symbols is None:
        report.add("wrong_package", name, "no such package %r" % package)
        return {"name": name, "status": "missing", "members": {}}

    lisp_name = type_rule["lisp_name"]
    kind = type_rule["lisp_kind"]

    if kind == "enum":
        claimed.setdefault(package, set()).update(
            {lisp_name, "%s-value" % lisp_name, "%s-from-value" % lisp_name,
             "all-%s" % lisp_name})
        statuses = verify_enum(report, rules, type_rule, contract_type, surface)
    else:
        entry = symbols.get(lisp_name)
        if kind in ("static", "interface"):
            # Neither has a symbol of its own. A static class projects as package
            # functions named <class>-<member>; a CLR interface projects as the
            # generic functions its members become, because Common Lisp needs no
            # type to hang a contract on -- a generic function *is* the contract,
            # and CLOS dispatches it the same way the interface did.
            entry = entry or {"name": lisp_name}
        elif entry is None:
            report.add("missing_type", name, "no exported symbol %r in %s"
                       % (lisp_name, package))
            return {"name": name, "status": "missing", "members": {}}
        else:
            claimed.setdefault(package, set()).add(lisp_name)
            if kind == "class" and not entry["class"]:
                report.add("wrong_kind", name, "%r is not a class" % lisp_name)
            if kind == "structure":
                if not entry["structure"]:
                    report.add("wrong_kind", name, "%r is not a structure" % lisp_name)
                claimed[package].update(
                    {"make-%s" % lisp_name, "%s-p" % lisp_name, "copy-%s" % lisp_name})
            expected_super = type_rule.get("expected_superclass")
            if expected_super and entry["class"]:
                if expected_super not in entry["precedence"]:
                    report.add("wrong_superclass", name,
                               "%r is not in the class precedence list %s"
                               % (expected_super, entry["precedence"]))
        statuses = verify_members(report, rules, type_rule, contract_type, symbols,
                                  package, claimed, surface["predefined_colors"],
                                  all_packages=packages)

    values = list(statuses.values())
    if all(v in ("complete", "not-applicable") for v in values):
        status = "complete"
    elif any(v == "complete" for v in values):
        status = "partial"
    else:
        status = "missing"
    result = {"name": name, "status": status, "members": statuses}
    if kind == "static":
        # A static class has no type symbol of its own: its members are package
        # functions named <class>-<member>.
        result["projection"] = "static class: %s:%s-<member>" % (package, lisp_name)
    elif kind == "interface":
        result["projection"] = ("interface: its members are generic functions in %s"
                                % package)
    else:
        result["lisp"] = "%s:%s" % (package, lisp_name)
    return result


def verify_event(report, type_rule, member, subject, symbols, package, claimed):
    """Verify one CLR event against its declared projection.

    A CLR event is two operations, `add_E` and `remove_E`, and the projection is
    two generic functions on the object that raises it. The rule must name both;
    an event with no rule is missing, and an event whose rule names a symbol that
    is not a generic function is an `event_mapping_mismatch` -- because a plain
    function could not be specialised on a second type that raises the same
    event, and `Disposed` is raised by two of them.
    """
    rule = type_rule.get("events", {}).get(member["name"])
    if rule is None:
        report.add("missing_member", subject, "no event projection is declared")
        return "missing"
    for role in ("add", "remove"):
        name = rule.get(role)
        if not name:
            report.add("event_mapping_mismatch", subject,
                       "the event projection declares no %r function" % role)
            return "missing"
        entry = symbols.get(name)
        if entry is None:
            report.add("missing_member", subject,
                       "no exported %r in %s" % (name, package))
            return "missing"
        claimed.setdefault(package, set()).add(name)
        if not entry["generic"]:
            report.add("event_mapping_mismatch", subject,
                       "%r is not a generic function, so it cannot be specialised "
                       "on a second type that raises the same event" % name)
            return "missing"
    return "complete"


def verify_members(report, rules, type_rule, contract_type, symbols, package, claimed,
                   surface_predefined=(), all_packages=None):
    statuses = {}
    all_packages = all_packages if all_packages is not None else {package: symbols}
    universal = {n["name"]: n["reason"] for n in rules["universal_not_applicable"]}
    for member in contract_type["members"]:
        sig = signature(member)
        subject = "%s.%s" % (contract_type["name"], sig)
        if (type_rule.get("predefined_value_properties")
                and member["kind"] == "property" and member.get("static")
                and member.get("type") == contract_type["name"]):
            # A static property of the type's own type is a predefined value. They
            # are reached by keyword rather than by 141 exported functions; the
            # thirteen that do have a function are declared extensions.
            key = enum_key(member["name"])
            if key in {enum_key(name) for name in surface_predefined}:
                statuses[sig] = "complete"
                lisp = kebab(member["name"])
                if lisp in symbols:
                    claimed.setdefault(package, set()).add(lisp)
            else:
                statuses[sig] = "missing"
                report.add("missing_member", subject,
                           "no predefined value named %r" % kebab(member["name"]))
            continue
        na = type_rule.get("not_applicable", {}).get(sig)
        if na is None and member["name"] in universal:
            na = universal[member["name"]]
        if na:
            statuses[sig] = "not-applicable"
            continue
        blocked = type_rule.get("blocked", {}).get(sig)
        if blocked:
            statuses[sig] = "externally-blocked"
            continue
        unimplemented = type_rule.get("unimplemented", {}).get(sig)
        if unimplemented:
            statuses[sig] = "missing"
            report.add("missing_member", subject, unimplemented)
            continue
        if member["kind"] == "event":
            statuses[sig] = verify_event(report, type_rule, member, subject, symbols,
                                         package, claimed)
            continue
        expected, override = expected_symbol(rules, type_rule, contract_type["name"], member)
        if expected is None:
            statuses[sig] = "not-applicable"
            continue
        if expected is False:
            statuses[sig] = "missing"
            report.add("missing_member", subject,
                       "this constructor signature is not projected")
            continue
        if expected == "make-instance":
            # A reference type is constructed with MAKE-INSTANCE, so the projection
            # is the class itself plus its initargs.
            statuses[sig] = "complete"
            continue
        # A member may project onto a symbol in another package -- GraphicsResource's
        # Dispose() is MICROSOFT.XNA.FRAMEWORK:DISPOSE, because disposal is one
        # operation for every native object rather than one per graphics type. The
        # rule has to say so, so that the symbol is claimed where it really lives
        # and does not look unexpected there.
        home = override.get("package", package)
        home_symbols = all_packages.get(home)
        if home_symbols is None:
            report.add("wrong_package", subject, "no such package %r" % home)
            statuses[sig] = "missing"
            continue
        entry = home_symbols.get(expected)
        if entry is None:
            statuses[sig] = "missing"
            report.add("missing_member", subject, "no exported %r in %s"
                       % (expected, home))
            continue
        claimed.setdefault(home, set()).add(expected)
        statuses[sig] = "complete"

        if override.get("kind") == "constant":
            if not entry["constant"]:
                report.add("wrong_kind", subject, "%r is not a constant" % expected)
                statuses[sig] = "missing"
            continue
        if not entry["fbound"] and not entry["class"]:
            report.add("wrong_kind", subject, "%r is not a function" % expected)
            statuses[sig] = "missing"
            continue
        wants_setf = override.get("setf")
        if wants_setf is None and member["kind"] == "property":
            wants_setf = bool(member.get("set"))
        if wants_setf is None and member["kind"] == "field" and not member.get("static"):
            wants_setf = True
        if wants_setf and not entry["setf_fbound"]:
            report.add("wrong_accessor_mutability", subject,
                       "%r has no (setf %s)" % (expected, expected))
        if override.get("generic") and not entry["generic"]:
            report.add("wrong_generic_function_shape", subject,
                       "%r is not a generic function" % expected)
        arity = override.get("lambda_list")
        if arity is not None and entry["lambda_list"] != arity:
            report.add("wrong_lambda_list", subject,
                       "%r has lambda list %s, expected %s"
                       % (expected, entry["lambda_list"], arity))
        # A member that collapses into a keyword-taking function must say which
        # keywords express it, and every one of them must really be accepted.
        # Without this, "one function with keyword arguments expresses all seven
        # overloads" is a sentence rather than a claim.
        keywords = override.get("keywords")
        if keywords is not None:
            accepted = set(entry.get("keywords") or ())
            accepted.update(item.lstrip("&") for item in entry["lambda_list"])
            missing_keywords = [k for k in keywords if k not in accepted]
            if missing_keywords:
                report.add("wrong_overload_shape", subject,
                           "%r does not accept %s" % (expected, missing_keywords))
        positional = override.get("positional")
        if positional is not None:
            required = [item for item in entry["lambda_list"]
                        if not item.startswith("&")]
            stop = next((i for i, item in enumerate(entry["lambda_list"])
                         if item.startswith("&")), len(entry["lambda_list"]))
            required = entry["lambda_list"][:stop]
            if len(required) != positional:
                report.add("wrong_overload_shape", subject,
                           "%r takes %d required argument(s), expected %d"
                           % (expected, len(required), positional))
        if override.get("status") == "partial":
            statuses[sig] = "partial"
    # An overload family that collapsed to one symbol must say so.
    families = {}
    for member in contract_type["members"]:
        if member["kind"] in ("method", "constructor"):
            families.setdefault(member["name"], []).append(member)
    for family, members in families.items():
        if len(members) < 2:
            continue
        family = ".ctor" if members[0]["kind"] == "constructor" else family
        mapped = set()
        for member in members:
            sig = signature(member)
            if statuses.get(sig) != "complete":
                continue
            expected, _ = expected_symbol(rules, type_rule, contract_type["name"], member)
            mapped.add(expected)
        declared = type_rule.get("overload_families", {}).get(family)
        if len(mapped) > 1 and declared is None:
            report.add("overload_mapping_mismatch",
                       "%s.%s" % (contract_type["name"], family),
                       "maps to %d symbols with no declared overload family" % len(mapped))
        # A family that collapses several *complete* overloads onto ONE symbol has
        # to distinguish them somehow. Requiring a declared keyword set per
        # overload is what turns "one function expresses them all" into something
        # a machine can check.
        complete = [m for m in members if statuses.get(signature(m)) == "complete"]
        if len(mapped) == 1 and len(complete) > 1 and family != ".ctor":
            overrides = type_rule.get("member_overrides", {})
            undeclared = [signature(m) for m in complete
                          if not overrides.get(signature(m), {}).get("distinguished_by")]
            if undeclared:
                report.add("wrong_overload_shape",
                           "%s.%s" % (contract_type["name"], family),
                           "%d overloads collapse onto %r without declaring how each is "
                           "expressed: %s"
                           % (len(complete), list(mapped)[0], undeclared[:4]))
            for member in complete:
                sig = signature(member)
                mechanism = overrides.get(sig, {}).get("distinguished_by")
                if mechanism and mechanism not in DISTINGUISHING_MECHANISMS:
                    report.add("wrong_overload_shape",
                               "%s.%s" % (contract_type["name"], sig),
                               "%r is not a distinguishing mechanism" % mechanism)
                if mechanism == "keywords" and not overrides.get(sig, {}).get("keywords"):
                    report.add("wrong_overload_shape",
                               "%s.%s" % (contract_type["name"], sig),
                               "claims to be distinguished by keywords and lists none")
                if mechanism == "no-keywords" and overrides.get(sig, {}).get("keywords"):
                    report.add("wrong_overload_shape",
                               "%s.%s" % (contract_type["name"], sig),
                               "claims to supply no keyword and then lists some")
            empty = [signature(m) for m in complete
                     if overrides.get(signature(m), {}).get("distinguished_by")
                     == "no-keywords"]
            if len(empty) > 1:
                report.add("wrong_overload_shape",
                           "%s.%s" % (contract_type["name"], family),
                           "%d overloads claim to supply no keyword; at most one can: %s"
                           % (len(empty), empty))
    return statuses


def verify_unexpected(report, rules, surface, packages, claimed):
    extensions = {}
    for entry in surface["declared_extensions"]:
        extensions.setdefault(entry["package"], set()).update(entry["symbols"])
    for package, symbols in packages.items():
        allowed = set(claimed.get(package, set()))
        allowed.update(extensions.get(package, set()))
        allowed.update(rules["allowed_symbols"].get(package, []))
        for name, entry in sorted(symbols.items()):
            if name in allowed:
                continue
            if entry["condition"]:
                report.add("unexpected_public_symbol", "%s:%s" % (package, name),
                           "a condition class that no rule accounts for")
                continue
            report.add("unexpected_public_symbol", "%s:%s" % (package, name),
                       "exported but neither a mapped XNA member nor a declared extension")


def verify_leaks(report, packages):
    """No exported name may mention an ABI concept.

    The match is on whole hyphen-separated words, not on substrings: HANDLER is
    not HANDLE, and a substring test reports every ADD-<EVENT>-HANDLER as a leak.
    A false positive here is worse than it looks, because the obvious repair is
    to delete the forbidden word and stop checking for it at all.
    """
    forbidden_words = ("handle", "cffi", "pointer", "foreign", "registry", "token",
                       "generation", "defcfun")
    forbidden_pairs = (("struct", "size"),)
    for package, symbols in packages.items():
        for name in symbols:
            words = name.split("-")
            for bad in forbidden_words:
                if bad in words:
                    report.add("private_implementation_leak", "%s:%s" % (package, name),
                               "the exported name has %r as a word" % bad)
            for a, b in forbidden_pairs:
                for first, second in zip(words, words[1:]):
                    if first == a and second == b:
                        report.add("private_implementation_leak",
                                   "%s:%s" % (package, name),
                                   "the exported name has %r in it" % (a + "-" + b))
            if "%" in name:
                report.add("private_implementation_leak", "%s:%s" % (package, name),
                           "the exported name mentions '%'")


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--surface",
                    default=os.path.join(ROOT, "docs/generated/public-surface.json"))
    ap.add_argument("--contract",
                    default=os.path.join(HERE, "reference/xna40-selected-contract.json"))
    ap.add_argument("--rules", default=os.path.join(HERE, "mapping-rules.json"))
    ap.add_argument("--output",
                    default=os.path.join(ROOT, "docs/generated/api-compat-report.json"))
    ap.add_argument("--strict", action="store_true",
                    help="exit non-zero unless every disagreement category is zero")
    args = ap.parse_args(argv)

    surface = load(args.surface)
    contract = load(args.contract)
    rules = load(args.rules)
    packages = index_surface(surface)

    report = Report()
    claimed = {}
    for contract_type in contract["types"]:
        report.types.append(
            verify_type(report, rules, contract_type, surface, packages, claimed))
    verify_unexpected(report, rules, surface, packages, claimed)
    verify_leaks(report, packages)

    by_status = {}
    member_status = {}
    for entry in report.types:
        by_status[entry["status"]] = by_status.get(entry["status"], 0) + 1
        for status in entry["members"].values():
            member_status[status] = member_status.get(status, 0) + 1

    counts = report.counts()
    out = {
        "schema_version": 1,
        "implementation": surface["implementation"],
        "profile": contract["profile"],
        "selection": contract["selection"],
        "provenance": contract["provenance"],
        "totals": {
            "types": len(report.types),
            "members": sum(member_status.values()),
            "types_by_status": by_status,
            "members_by_status": member_status,
            "diagnostics": len(report.diagnostics),
            "diagnostics_by_category": counts,
            "disagreement_total": sum(counts[c] for c in DISAGREEMENT),
        },
        "types": report.types,
        "diagnostics": report.diagnostics,
    }
    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as fh:
        json.dump(out, fh, indent=1)
        fh.write("\n")

    print("CNA-Lisp structural compatibility")
    print("  profile          : %s" % contract["profile"])
    print("  selection        : %s" % contract["selection"]["name"])
    print("  types            : %d  %s" % (len(report.types), dict(sorted(by_status.items()))))
    print("  members          : %d  %s" % (sum(member_status.values()),
                                           dict(sorted(member_status.items()))))
    print("  diagnostics      : %d" % len(report.diagnostics))
    for category in CATEGORIES:
        if counts[category]:
            print("      %-32s %d" % (category, counts[category]))
    print("  disagreement     : %d  (must be zero for a qualified milestone)"
          % out["totals"]["disagreement_total"])
    print("  report           : %s" % os.path.relpath(args.output, ROOT))
    if args.strict:
        return 1 if out["totals"]["disagreement_total"] else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
