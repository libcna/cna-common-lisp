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

   ``--write`` renders every such region from the reports; with no flag the
   rendered text must already be what the file says. This is what keeps the
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


def facts_of(abi, compat):
    return {
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
        "abi version encoded": abi["abi_version"]["encoded"],
    }


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
        "| Admitted ABI versions | %d.%d.%d only (encoded %d) |"
        % (version["major"], version["minor"], version["patch"],
           version["encoded"]),
    ))


def block_selection(abi, compat):
    selection = compat["selection"]
    return ("Selection **%s**: %d types, %d members."
            % (selection["name"], selection["type_count"],
               selection["member_count"]))


BLOCKS = {
    "selection": block_selection,
    "scoreboard": block_scoreboard,
    "per-type-table": block_per_type_table,
    "partial-frontier": block_partial_frontier,
    "native-abi-summary": block_native_abi_summary,
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

    print("generated facts")
    for key, value in facts.items():
        print("  %-28s %s" % (key, value))

    problems = []
    for document in DOCUMENTS:
        body = text(document)
        if body is None:
            continue

        for match in re.finditer(r"<!--\s*generated:([a-z0-9 .-]+)=(\d+)\s*-->", body):
            name, claimed = match.group(1), int(match.group(2))
            if name not in facts:
                problems.append("%s: no generated fact named %r" % (document, name))
            elif facts[name] != claimed:
                problems.append("%s: %r is written as %d but generated as %d"
                                % (document, name, claimed, facts[name]))

        rendered = render_blocks(body, abi, compat, document, problems)
        if rendered != body:
            if arguments.write:
                with open(os.path.join(ROOT, document), "w", encoding="utf-8") as fh:
                    fh.write(rendered)
                print("rewrote the generated blocks in %s" % document)
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
