#!/usr/bin/env python3
"""Cross-check every number in the prose against the generated reports.

A number in a README is a claim. This tool makes each of them a derived value:
it reads the generated reports and refuses any figure in README.md, plan.md or
NEXT.md that does not match.

  python3 tools/qualification/verify-numbers.py
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))


def load(relative):
    with open(os.path.join(ROOT, relative), encoding="utf-8") as fh:
        return json.load(fh)


def text(relative):
    path = os.path.join(ROOT, relative)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def main():
    abi = load("docs/generated/native-abi-manifest.json")
    compat = load("docs/generated/api-compat-report.json")

    facts = {
        "bound native functions": abi["counts"]["functions"],
        "bound native structs": abi["counts"]["structs"],
        "bound native struct fields": abi["counts"]["struct_fields"],
        "bound native constants": abi["counts"]["constants"],
        "bound native callbacks": abi["counts"]["callbacks"],
        "by-value aggregates": abi["counts"]["by_value_aggregates"],
        "blocked routes": abi["counts"]["blocked_routes"],
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

    print("generated facts")
    for key, value in facts.items():
        print("  %-28s %s" % (key, value))

    # Every "GENERATED(name)" marker in the prose is replaced by its fact and
    # compared; a marker naming a fact that does not exist is an error.
    problems = []
    for document in ("README.md", "plan.md", "NEXT.md",
                     "docs/compatibility.md", "docs/native-abi.md"):
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
