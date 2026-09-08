#!/usr/bin/env python3
"""Cross-check every number in the prose against the generated reports.

A number in a README is a claim. This tool makes each of them a derived value.
It works three ways, and each one closes a hole the previous one left open.

1. **Facts.** ``<!-- generated:selected types=77 -->`` names a fact the reports
   produce and asserts its value. A marker whose value has moved is an error.

2. **Blocks.** A table is a lot of numbers, and marking each one is not
   practical, so a whole region can be generated instead::

       <!-- generated-block:per-type-table -->
       ...rendered content, not to be edited by hand...
       <!-- /generated-block:per-type-table -->

   ``--write`` restates every fact marker and renders every such region from
   the reports; with no flag the file must already say what they render. This is what keeps the
   per-type table and the native-ABI summary honest: the summary had drifted to
   69 bound routes while the manifest said 100, and nothing caught it, because
   no single number in it carried a marker.

3. **Refusals.** Some numbers must not be written down at all, because they are
   measurements of a *run* rather than properties of the repository -- a check
   count is the standing example. The handoff carried "1503 checks" for long
   enough that the real figure had passed 2400. Patterns that produce that kind
   of claim are refused outright, with the reason.

  python3 tools/qualification/verify-numbers.py [--write]
"""
import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

DOCUMENTS = (
    "README.md",
    "plan.md",
    "NEXT.md",
    "docs/compatibility.md",
    "docs/native-abi.md",
    "docs/limitations.md",
    "docs/qualification.md",
)

# Claims that are measurements of one run on one machine. They go stale the next
# time a test is added, and no report can pin them, so they are refused instead.
FORBIDDEN = (
    (r"\b\d{2,}\s+checks?\b",
     "a check count is a measurement of one run, not a property of the "
     "repository; print it with asdf:test-system instead of writing it down"),
    (r"\bchecks?\s+(?:passed|run)\s*[:=]\s*\d+",
     "same: a check count belongs to the run that produced it"),
    (r"\b\d+\s+(?:tests?|assertions?|checks?)\s+(?:passed|failed|ran)\b",
     "same: a check count belongs to the run that produced it"),
    (r"\b\d+\s+not\s+run\b",
     "the number of gates a configuration skips moves with the suite; say "
     "which layer did not run, not how many checks it was"),
)

SHORT = {
    "Microsoft.Xna.Framework.": "M.X.F.",
}


def load(relative):
    with open(os.path.join(ROOT, relative), encoding="utf-8") as fh:
        return json.load(fh)


def text(relative):
    path = os.path.join(ROOT, relative)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def rasterizer_proofs():
    """The pixel proofs the rasterizer lane requires, from its one registry.

    Not a report: `tools/qualification/rasterizer-proofs.json` is a policy
    statement about what the lane demands, and `rasterizer.sh` enforces it in
    both directions -- a required proof the run did not produce fails, and a
    proof the run produced that the registry does not name fails too. Rendering
    the count and the list from it is what stops a fourth copy of the list
    appearing in the prose and going stale, which is exactly what had happened:
    the script's comment said seven kinds, its loop required eight, and the
    README said four.
    """
    return load("tools/qualification/rasterizer-proofs.json")["proofs"]


def texture3d_claims():
    """The Texture3D claims the EasyGL lane requires, from its one registry.

    The same shape as `rasterizer_proofs`, and for the same reason:
    `tools/qualification/texture3d-proofs.json` is a policy statement about what
    the lane demands, `texture3d.sh` enforces it in both directions, and
    rendering the count and the table from it is what stops a second copy of the
    list appearing in the prose. The rasterizer lane learnt that the hard way.
    """
    return load("tools/qualification/texture3d-proofs.json")["proofs"]


def loadable_asset_types():
    """The asset types `ContentManager.Load<T>` has a route for.

    Read from the dumped **live loader table**, not from a list kept beside it:
    `dump-surface.lisp` calls `LOADABLE-ASSET-TYPES`, which reads the same
    `*ASSET-LOADERS*` alist `Load<T>` dispatches on, so a loader that lands
    without a documentation change leaves the rendered block stale and this
    tool red. The README had said "Texture2D, TextureCube and SpriteFont"
    for a while after `Load<Effect>` landed, which is exactly the drift a
    generated block removes.

    The XNA name comes from the mapping rules, which is where the
    Lisp-name-to-XNA-name correspondence already lives; the dump carries only
    the Lisp symbol, because that is all the loader table knows.
    """
    surface = load("docs/generated/public-surface.json")
    rules = load("tools/api-compat/mapping-rules.json")
    xna_name = {}
    for name, spec in rules["types"].items():
        xna_name[(spec.get("lisp_package"), spec.get("lisp_name"))] = name
    types = []
    for entry in surface.get("loadable_asset_types", []):
        key = (entry["lisp_package"], entry["lisp_name"])
        types.append((xna_name.get(key, entry["lisp_name"]), entry["lisp_name"]))
    return types


def facts_of(abi, compat):
    return {
        "rasterizer proof count": len(rasterizer_proofs()),
        "texture3d claim count": len(texture3d_claims()),
        "loadable asset types": len(loadable_asset_types()),
        "high-value frontier members": sum(
            1 for category in load(
                "tools/api-compat/mapping-rules.json")["frontier_categories"].values()
            if category == "IMPLEMENTABLE_AND_HIGH_VALUE"),
        "bound native functions": abi["counts"]["functions"],
        "bound native structs": abi["counts"]["structs"],
        "bound native struct fields": abi["counts"]["struct_fields"],
        "bound native constants": abi["counts"]["constants"],
        "bound native callbacks": abi["counts"]["callbacks"],
        "by-value aggregates": abi["counts"]["by_value_aggregates"],
        "shimmed routes": abi["counts"]["shimmed_routes"],
        "selected types": compat["totals"]["types"],
        "selected members": compat["totals"]["members"],
        "complete types": compat["totals"]["types_by_status"].get("complete", 0),
        "partial types": compat["totals"]["types_by_status"].get("partial", 0),
        "missing types": compat["totals"]["types_by_status"].get("missing", 0),
        "complete members": compat["totals"]["members_by_status"].get("complete", 0),
        "partial members": compat["totals"]["members_by_status"].get("partial", 0),
        "missing members": compat["totals"]["members_by_status"].get("missing", 0),
        "not-applicable members": compat["totals"]["members_by_status"].get(
            "not-applicable", 0),
        "disagreement total": compat["totals"]["disagreement_total"],
        # The prose said "fourteen categories ... the other twelve" while the
        # verifier measured sixteen. Same class of drift as the DrawString count,
        # and derivable the same way.
        "diagnostic categories": len(compat["totals"]["diagnostics_by_category"]),
        "absence categories": sum(
            1 for name in compat["totals"]["diagnostics_by_category"]
            if name in ("missing_type", "missing_member")),
        "disagreement categories": sum(
            1 for name in compat["totals"]["diagnostics_by_category"]
            if name not in ("missing_type", "missing_member")),
        "abi version encoded": abi["abi_version"]["encoded"],
    }


def family_facts(compat):
    """One fact per method family that still has missing members.

    `NEXT.md` said "Eight of SpriteBatch's members are its DrawString family"
    while the contract had six, and nothing caught it: the sentence was prose,
    and prose carried no marker. A count of *how much of one family is missing*
    is derivable from the report, so it is derived, and a sentence that wants to
    say it writes `<!-- generated:missing M.X.F.Graphics.SpriteBatch.DrawString=6 -->`
    and is checked like every other number.

    Only families with at least one missing member get a fact. A family that is
    finished has nothing left to write a frontier sentence about, and emitting
    zeroes for all 2061 members would bury the ones that matter.
    """
    facts = {}
    for entry in compat["types"]:
        counts = {}
        for signature, status in entry["members"].items():
            family = signature.split("(", 1)[0]
            counts.setdefault(family, [0, 0])
            counts[family][0] += 1
            if status == "missing":
                counts[family][1] += 1
        for family, (_, missing) in counts.items():
            if missing:
                facts["missing %s.%s" % (short(entry["name"]), family)] = missing
    return facts


def short(name):
    for long_form, abbreviation in SHORT.items():
        if name.startswith(long_form):
            return abbreviation + name[len(long_form):]
    return name


def tally(members):
    return tuple(sum(1 for status in members.values() if status == wanted)
                 for wanted in ("complete", "partial", "missing", "not-applicable"))


# --------------------------------------------------------------------- blocks

def block_scoreboard(abi, compat):
    total = compat["totals"]
    by_type = total["types_by_status"]
    by_member = total["members_by_status"]
    return "\n".join((
        "| | |",
        "| --- | --- |",
        "| Types complete | **%d** |" % by_type.get("complete", 0),
        "| Types partial | **%d** |" % by_type.get("partial", 0),
        "| Types missing | **%d** |" % by_type.get("missing", 0),
        "| Members complete | **%d** |" % by_member.get("complete", 0),
        "| Members partial | **%d** |" % by_member.get("partial", 0),
        "| Members missing | **%d** |" % by_member.get("missing", 0),
        "| Members not applicable | **%d** |" % by_member.get("not-applicable", 0),
        "| **Disagreement diagnostics** | **%d** |" % total["disagreement_total"],
    ))


def block_per_type_table(abi, compat):
    lines = ["| Type | Status | complete | partial | missing | n/a |",
             "| --- | --- | ---: | ---: | ---: | ---: |"]
    for entry in compat["types"]:
        complete, partial, missing, na = tally(entry["members"])
        lines.append("| `%s` | **%s** | %d | %d | %d | %d |"
                     % (short(entry["name"]), entry["status"],
                        complete, partial, missing, na))
    return "\n".join(lines)


def block_partial_frontier(abi, compat):
    partial = [entry for entry in compat["types"] if entry["status"] != "complete"]
    if not partial:
        return "Every selected type is complete."
    lines = ["| Type | missing members | partial members |",
             "| --- | ---: | ---: |"]
    for entry in sorted(partial,
                        key=lambda e: -tally(e["members"])[2]):
        _, partial_count, missing, _ = tally(entry["members"])
        lines.append("| `%s` | %d | %d |"
                     % (short(entry["name"]), missing, partial_count))
    return "\n".join(lines)


def block_native_abi_summary(abi, compat):
    counts = abi["counts"]
    version = abi["abi_version"]
    return "\n".join((
        "| | |",
        "| --- | --- |",
        "| Bound functions | %d |" % counts["functions"],
        "| Bound structs | %d |" % counts["structs"],
        "| Bound struct fields | %d |" % counts["struct_fields"],
        "| Bound constants | %d |" % counts["constants"],
        "| Bound callback typedefs | %d |" % counts["callbacks"],
        "| By-value aggregates admitted | %d |" % counts["by_value_aggregates"],
        "| Routes proved unbindable, and shimmed | %d |" % counts["shimmed_routes"],
        # **The admitted set is a set, and this line used to render one member of
        # it as "only".** It printed the version constant baked into the
        # checked-in generated layer -- which is one of the admitted versions and
        # says nothing about the others -- so from the day 0.22.0 was admitted
        # this table said "0.21.0 only" about a binding that admits two. A number
        # in prose is a claim; so is the word beside it.
        "| Admitted ABI versions | %s |"
        % ", ".join("%s (encoded %d)" % (entry["version"], entry["encoded"])
                    for entry in abi["admitted_abi_versions"]),
        "| Version constant in the generated layer | %d.%d.%d (encoded %d) |"
        % (version["major"], version["minor"], version["patch"],
           version["encoded"]),
    ))


def block_selection(abi, compat):
    selection = compat["selection"]
    return ("Selection **%s**: %d types, %d members."
            % (selection["name"], selection["type_count"],
               selection["member_count"]))


def block_native_abi_headline(abi, compat):
    counts = abi["counts"]
    return ("The private foreign layer binds **%d native routes** and **%d native "
            "structs**,\nall of them generated from the canonical CNA headers and "
            "checked by a C compiler." % (counts["functions"], counts["structs"]))


def block_scoreboard_headline(abi, compat):
    selection = compat["selection"]
    total = compat["totals"]
    by_type = total["types_by_status"]
    by_member = total["members_by_status"]
    return ("The generated scoreboard, over a selection of **%d XNA types and %d "
            "members**:\n\n| | |\n| --- | --- |\n"
            "| Types complete / partial / missing | **%d / %d / %d** |\n"
            "| Members complete / missing | **%d / %d** |\n"
            "| Members not applicable | **%d** |\n"
            "| **Disagreement diagnostics** | **%d** |"
            % (selection["type_count"], selection["member_count"],
               by_type.get("complete", 0), by_type.get("partial", 0),
               by_type.get("missing", 0),
               by_member.get("complete", 0), by_member.get("missing", 0),
               by_member.get("not-applicable", 0), total["disagreement_total"]))


def block_rasterizer_proofs(abi, compat):
    lines = ["| Proof | What it claims |", "| --- | --- |"]
    for proof in rasterizer_proofs():
        lines.append("| `%s` | %s |" % (proof["kind"], proof["claim"]))
    return "\n".join(lines)


def block_rasterizer_proof_kinds(abi, compat):
    kinds = ["`%s`" % proof["kind"] for proof in rasterizer_proofs()]
    return "%d kinds -- %s and %s." % (len(kinds), ", ".join(kinds[:-1]), kinds[-1])


def block_texture3d_claims(abi, compat):
    lines = ["| Claim | Process group | What it claims |", "| --- | --- | --- |"]
    for claim in texture3d_claims():
        lines.append("| `%s` | `%s` | %s |"
                     % (claim["kind"], claim["group"], claim["claim"]))
    return "\n".join(lines)


def block_texture3d_claim_kinds(abi, compat):
    kinds = ["`%s`" % claim["kind"] for claim in texture3d_claims()]
    return "%d claims -- %s and %s." % (len(kinds), ", ".join(kinds[:-1]), kinds[-1])


def block_loadable_asset_types(abi, compat):
    lines = ["| Asset type | `load-asset` argument |", "| --- | --- |"]
    for xna, lisp in loadable_asset_types():
        lines.append("| `%s` | `'%s` |" % (short(xna), lisp))
    return "\n".join(lines)


def block_loadable_asset_type_names(abi, compat):
    # The leaf name, not the qualified one: this block goes in a sentence.
    names = ["`%s`" % xna.rsplit(".", 1)[-1] for xna, _ in loadable_asset_types()]
    if len(names) == 1:
        return names[0]
    return "%s and %s" % (", ".join(names[:-1]), names[-1])


def block_diagnostic_categories(abi, compat):
    """The two lists of diagnostic categories, from the report's own tally.

    Hand-maintained until `stale_declared_absence` was added and the table did
    not grow with the count above it -- which is the drift this file exists to
    stop, appearing in the very table that enumerates how drift is caught.
    """
    categories = compat["totals"]["diagnostics_by_category"]
    absence = [name for name in categories
               if name in ("missing_type", "missing_member")]
    disagreement = [name for name in categories
                    if name not in ("missing_type", "missing_member")]
    lines = ["| Absence | Disagreement |", "| --- | --- |"]
    for index in range(max(len(absence), len(disagreement))):
        left = "`%s`" % absence[index] if index < len(absence) else ""
        right = "`%s`" % disagreement[index] if index < len(disagreement) else ""
        lines.append("| %s | %s |" % (left, right))
    return "\n".join(lines)


def block_frontier_categories(abi, compat):
    """How many non-complete members are held up by each kind of limit.

    Rendered so that the two empty rows stay visible. A release statement rests
    on IMPLEMENTABLE_AND_HIGH_VALUE being zero, and a table that dropped its
    empty rows would show that by showing nothing.
    """
    rules = load("tools/api-compat/mapping-rules.json")
    kinds = rules["frontier_category_kinds"]
    counts = {name: 0 for name in kinds}
    for category in rules["frontier_categories"].values():
        counts[category] = counts.get(category, 0) + 1
    lines = ["| Category | Members | What it means |", "| --- | ---: | --- |"]
    for name in kinds:
        # One sentence of the definition; the rules file carries the whole one.
        summary = kinds[name].split(". ")[0].rstrip(".") + "."
        lines.append("| `%s` | **%d** | %s |" % (name, counts[name], summary))
    return "\n".join(lines)


BLOCKS = {
    "selection": block_selection,
    "rasterizer-proofs": block_rasterizer_proofs,
    "rasterizer-proof-kinds": block_rasterizer_proof_kinds,
    "texture3d-claims": block_texture3d_claims,
    "texture3d-claim-kinds": block_texture3d_claim_kinds,
    "loadable-asset-types": block_loadable_asset_types,
    "loadable-asset-type-names": block_loadable_asset_type_names,
    "native-abi-headline": block_native_abi_headline,
    "scoreboard-headline": block_scoreboard_headline,
    "scoreboard": block_scoreboard,
    "per-type-table": block_per_type_table,
    "partial-frontier": block_partial_frontier,
    "native-abi-summary": block_native_abi_summary,
    "diagnostic-categories": block_diagnostic_categories,
    "frontier-categories": block_frontier_categories,
}

BLOCK_RE = re.compile(
    r"<!-- generated-block:([a-z0-9-]+) -->.*?<!-- /generated-block:\1 -->",
    re.S)


def render_blocks(body, abi, compat, document, problems):
    def replace(match):
        name = match.group(1)
        if name not in BLOCKS:
            problems.append("%s: no generated block named %r" % (document, name))
            return match.group(0)
        return "<!-- generated-block:%s -->\n%s\n<!-- /generated-block:%s -->" % (
            name, BLOCKS[name](abi, compat), name)
    return BLOCK_RE.sub(replace, body)


# ----------------------------------------------------------------------- main

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true",
                        help="rewrite every generated block instead of checking it")
    arguments = parser.parse_args()

    abi = load("docs/generated/native-abi-manifest.json")
    compat = load("docs/generated/api-compat-report.json")
    facts = facts_of(abi, compat)
    facts.update(family_facts(compat))

    print("generated facts")
    for key, value in facts.items():
        print("  %-28s %s" % (key, value))

    problems = []
    for document in DOCUMENTS:
        body = text(document)
        if body is None:
            continue

        for match in re.finditer(r"<!--\s*generated:([A-Za-z0-9 .-]+)=(\d+)\s*-->", body):
            name, claimed = match.group(1), int(match.group(2))
            if name not in facts:
                problems.append("%s: no generated fact named %r" % (document, name))
            elif facts[name] != claimed and not arguments.write:
                problems.append("%s: %r is written as %d but generated as %d"
                                % (document, name, claimed, facts[name]))

        rendered = body
        if arguments.write:
            def restate(match):
                name = match.group(1)
                if name not in facts:
                    return match.group(0)
                return "<!-- generated:%s=%d -->" % (name, facts[name])
            rendered = re.sub(r"<!--\s*generated:([A-Za-z0-9 .-]+)=\d+\s*-->",
                              restate, rendered)
        rendered = render_blocks(rendered, abi, compat, document, problems)
        if rendered != body:
            if arguments.write:
                with open(os.path.join(ROOT, document), "w", encoding="utf-8") as fh:
                    fh.write(rendered)
                print("rewrote the generated facts and blocks in %s" % document)
            else:
                problems.append(
                    "%s: a generated block is not what the reports render; "
                    "run tools/qualification/verify-numbers.py --write" % document)

        # Refusals run against the rendered text so a generated block can never
        # be blamed for a claim it did not make.
        stripped = re.sub(r"```.*?```", "", rendered, flags=re.S)
        for pattern, reason in FORBIDDEN:
            for match in re.finditer(pattern, stripped, re.I):
                problems.append("%s: %r must not appear in prose -- %s"
                                % (document, match.group(0).strip(), reason))

    # Every proof the registry requires must also be *described* somewhere, and
    # the count alone does not say that: `loaded-text` was added to the registry
    # and to the suite, the count marker moved from 7 to 8, and the table in
    # docs/qualification.md that says what each proof actually does never grew
    # the row. A generated block cannot carry that table -- what a proof does is
    # prose, and prose is the thing worth writing by hand -- so what is checked
    # is that each kind is named by a row of it.
    # Searched with the generated blocks removed. That document also renders
    # `rasterizer-proofs`, whose rows begin with the same `| `kind` |`, so a
    # check over the whole file is satisfied by the generated table and can
    # never see the hand-written one go missing -- which is how this check
    # passed the first time it was tried against a deliberately deleted row.
    described = BLOCK_RE.sub("", text("docs/qualification.md") or "")
    for proof in rasterizer_proofs():
        if ("| `%s` |" % proof["kind"]) not in described:
            problems.append(
                "docs/qualification.md: the rasterizer proof %r is required by "
                "tools/qualification/rasterizer-proofs.json and no row of the proof "
                "table describes it" % proof["kind"])

    # The same rule for the Texture3D lane, and it is the same failure it
    # prevents: a claim added to the registry and to the suite, with the count
    # marker moving, and the table that says what the claim actually does never
    # growing the row.
    for claim in texture3d_claims():
        if ("| `%s` |" % claim["kind"]) not in described:
            problems.append(
                "docs/qualification.md: the Texture3D claim %r is required by "
                "tools/qualification/texture3d-proofs.json and no row of the claim "
                "table describes it" % claim["kind"])

    if compat["totals"]["disagreement_total"]:
        problems.append("the compatibility report has %d disagreement diagnostics"
                        % compat["totals"]["disagreement_total"])

    if problems:
        print("\nproblems:")
        for problem in problems:
            print("  " + problem)
        return 1
    print("\nevery cross-checked number in the prose matches the generated reports")
    return 0


if __name__ == "__main__":
    sys.exit(main())
