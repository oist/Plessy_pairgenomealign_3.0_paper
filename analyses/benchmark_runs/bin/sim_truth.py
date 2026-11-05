#!/usr/bin/env python3
"""Re-run the simulation of Gulhan et al. (2025) with a log of every mutation.

Reads their notebook generate_apples_and_oranges.ipynb (github.com/nekrut/lz-fg-mm),
adds logging statements to EchyDna.mutate that do not call the random number
generator, runs it in the current directory, and writes:

  apple.indels.fa, orange.indels.fa   regenerated sequences, which must be identical
                                      to the published ones (checked by the caller)
  truth.json                          for each pair "id<I>_len<L>": [core length,
                                      orange core length, reverse-complemented?,
                                      [[apple index, orange index, substituted?], ...]]

The simulation makes no deletions: every apple core base is listed once.

Usage: sim_truth.py generate_apples_and_oranges.ipynb
"""

import json
import sys

nb = json.load(open(sys.argv[1]))
src = "\n\n".join("".join(c["source"]) for c in nb["cells"] if c["cell_type"] == "code")

patches = [
    ("""			if (spin >= eventRate):      # no event
				seq += [nt]""",
     """			if (spin >= eventRate):      # no event
				LOG.append((ix, len(seq), 0))
				seq += [nt]"""),
    ("""				if (nt in ntToSubs): seq += [chooser(ntToSubs[nt])]""",
     """				LOG.append((ix, len(seq), 1))
				if (nt in ntToSubs): seq += [chooser(ntToSubs[nt])]"""),
    ("""			if (indelLen == 0):          # no event
				seq += [nt]""",
     """			if (indelLen == 0):          # no event
				LOG.append((ix, len(seq), 0))
				seq += [nt]"""),
    ("""        orange = apple.mutate(subRate=divergence,
                              indelRate=indelRate,
                              indels=indelLengths)
        if randint(0, 1) == 1:
            orange = -orange
""",
     """        LOG.clear()
        orange = apple.mutate(subRate=divergence,
                              indelRate=indelRate,
                              indels=indelLengths)
        rc = randint(0, 1) == 1
        if rc:
            orange = -orange
        TRUTH[itemName] = (itemLen, len(orange), rc, list(LOG))
"""),
    ('"../sequences/apple.indels.fa"', '"apple.indels.fa"'),
    ('"../sequences/orange.indels.fa"', '"orange.indels.fa"'),
]
for old, new in patches:
    if src.count(old) != 1:
        sys.exit(f"notebook does not contain the expected code:\n{old}")
    src = src.replace(old, new)

namespace = {"LOG": [], "TRUTH": {}, "__name__": "__simulation__"}
exec(compile(src, "generate_apples_and_oranges", "exec"), namespace)
json.dump(namespace["TRUTH"], open("truth.json", "w"))
