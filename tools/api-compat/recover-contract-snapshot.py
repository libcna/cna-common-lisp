#!/usr/bin/env python3
"""Recover the pinned 257-type XNA contract snapshot from a schemaVersion-2 copy.

`import-contract.py` refuses any snapshot whose SHA-256 is not exactly
`7207908e...`, which is the right rule and became a problem the day the file with
that hash stopped existing on any machine here.  What survived is a **newer
serialization of the same metadata**: schemaVersion 2 adds one field, `readonly`,
to every field member and changes nothing else.

This tool removes exactly that field and re-serializes, and **refuses to write
anything unless the result hashes to the pinned value**.  So it cannot quietly
produce a different authority: either it reconstructs the pinned bytes or it
fails and says what it got instead.

    recover-contract-snapshot.py <schemaVersion-2-snapshot> <output-path>

**This is recovery, not a re-pin.**  The pinned hash in `import-contract.py` is
unchanged and must stay unchanged: the bytes this writes are the bytes that were
always pinned, and that is verified rather than asserted.

The surviving copy at the time of writing is

    _bindings/cna-swift/tools/api_compat/reference/xna40-windows-runtime-contract.json

which is the same metadata CNA-Swift pins for the same profile.  Any other
schemaVersion-2 snapshot of the same profile works if it reconstructs the hash,
and none works if it does not -- which is the whole point of checking.
"""
import collections
import hashlib
import json
import sys

PINNED_SHA256 = "7207908eb7926cc90a156d0370c907add4dda465421cea1cbec51afba2f97fdc"
EXPECTED_TYPES = 257

# schemaVersion 2 adds this to field members and nothing else. Removing it is the
# whole of the transformation; anything more would be editing the authority.
ADDITIVE_KEYS = ("readonly",)


def strip_additive(value):
    if isinstance(value, dict):
        return collections.OrderedDict(
            (k, strip_additive(v)) for k, v in value.items() if k not in ADDITIVE_KEYS)
    if isinstance(value, list):
        return [strip_additive(v) for v in value]
    return value


def main(argv):
    if len(argv) != 2:
        sys.stderr.write(__doc__)
        return 2
    source, destination = argv

    with open(source, "rb") as handle:
        raw = handle.read()
    digest = hashlib.sha256(raw).hexdigest()
    if digest == PINNED_SHA256:
        sys.stderr.write(
            "%s is already the pinned snapshot; nothing to recover.\n" % source)
        return 0

    document = json.loads(raw.decode("utf-8"), object_pairs_hook=collections.OrderedDict)
    if len(document.get("types", [])) != EXPECTED_TYPES:
        sys.stderr.write("the source holds %d types, not the pinned %d\n"
                         % (len(document.get("types", [])), EXPECTED_TYPES))
        return 1

    # Compact separators and no trailing newline: that is how the pinned file was
    # written, and the hash below is what proves it rather than a claim here.
    recovered = json.dumps(strip_additive(document), separators=(",", ":")).encode("utf-8")
    recovered_digest = hashlib.sha256(recovered).hexdigest()
    if recovered_digest != PINNED_SHA256:
        sys.stderr.write(
            "refusing to write %s\n"
            "  recovering from %s produced SHA-256\n    %s\n"
            "  and the pinned authority is\n    %s\n"
            "The difference is therefore NOT the additive %s field alone, so this\n"
            "source is not a newer serialization of the pinned snapshot. Do not\n"
            "change the pin to make this pass: produce a full 257-type equivalence\n"
            "diff first and decide deliberately.\n"
            % (destination, source, recovered_digest, PINNED_SHA256,
               "/".join(ADDITIVE_KEYS)))
        return 1

    with open(destination, "wb") as handle:
        handle.write(recovered)
    print("recovered the pinned snapshot")
    print("  from   : %s  (sha256 %s)" % (source, digest))
    print("  to     : %s" % destination)
    print("  sha256 : %s" % recovered_digest)
    print("  types  : %d" % EXPECTED_TYPES)
    print("  removed: the additive %s field, and nothing else"
          % "/".join(ADDITIVE_KEYS))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
