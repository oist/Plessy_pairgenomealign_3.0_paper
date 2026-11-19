#!/usr/bin/env python3
"""Identity reported by alignments of the simulated pairs versus the true identity.

The true identity of each pair is known because the simulation of Gulhan et al.
(notebook generate_apples_and_oranges.ipynb, seed "20240327") was re-run with a
log of every mutation, and reproduced their sequence files byte for byte
(truth.json: for each pair, the list of apple-core positions aligned in the
simulation, with a flag for substitutions).  The simulation makes no deletions,
so every core base of the APPLE sequence has a homologous base in the ORANGE.

True identity:     1 - substitutions / core length (gaps not counted).
Measured identity: matches / aligned base pairs, summed over the alignments
                   between a pair (gaps not counted).
Also, to see how the alignments reach their identity: the true numbers of
substitutions and of inserted bases (the simulation inserts bases in the ORANGE
only), the matches, and the gap columns in each row: a gap in the APPLE row
faces an ORANGE base (counterpart: an insertion), a gap in the ORANGE row faces
an APPLE base (no counterpart in the simulation).

Usage: sim_identity.py truth.json OUT.tsv NAME:FORMAT:FILE [...]
FORMAT: maf (bases compared column by column, APPLE first), lastz-general
(nmatch/nalign; gap columns from the spans: APPLE span - nalign, ORANGE span - nalign).
PAF files without CIGAR (the published FastGA and minimap2 outputs) are not
supported: they carry no base-level alignment.  FastGA's tenth PAF column is not
a count of matches but the mean span minus half the differences (df:i:).
"""

import gzip
import json
import re
import sys

NAME_RE = re.compile(r"^(?:APPLE|ORANGE)_(id(\d+)_len(\d+))$")


def opener(path):
    return gzip.open(path, "rt") if path.endswith(".gz") else open(path, "rt")


def pair_of(name):
    return NAME_RE.match(name).group(1)


def maf_counts(path):
    """matches, aligned pairs, gap columns in the APPLE row, gap columns in the
    ORANGE row, per pair, from alignments between a pair's own sequences."""
    out = {}
    rows = []
    with opener(path) as f:
        for line in f:
            if line.startswith("a"):
                rows = []
            elif line.startswith("s"):
                rows.append(line.split())
                if len(rows) == 2:
                    t, q = rows
                    if pair_of(t[1]) != pair_of(q[1]):
                        continue
                    m = n = gt = gq = 0
                    for a, b in zip(t[6].upper(), q[6].upper()):
                        if a == "-":
                            gt += 1
                        elif b == "-":
                            gq += 1
                        else:
                            n += 1
                            m += a == b
                    acc = out.setdefault(pair_of(t[1]), [0, 0, 0, 0])
                    for i, v in enumerate((m, n, gt, gq)):
                        acc[i] += v
    return out


def lastz_counts(path):
    out = {}
    with opener(path) as f:
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            c = line.rstrip("\n").split("\t")
            if pair_of(c[1]) != pair_of(c[6]):
                continue
            m, n = map(int, c[11].split("/"))
            span_apple = int(c[5]) - int(c[4])
            span_orange = int(c[10]) - int(c[9])
            acc = out.setdefault(pair_of(c[1]), [0, 0, 0, 0])
            for i, v in enumerate((m, n, span_orange - n, span_apple - n)):
                acc[i] += v
    return out


READERS = {"maf": maf_counts, "lastz-general": lastz_counts}


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    truth = json.load(open(sys.argv[1]))
    with open(sys.argv[2], "w") as out:
        out.write("aligner\tpair\tidentity\tlength\ttrue_identity\tmeasured_identity\t"
                  "aligned_pairs\tmatches\ttrue_substitutions\ttrue_inserted\t"
                  "gap_cols_apple\tgap_cols_orange\n")
        for spec in sys.argv[3:]:
            name, fmt, path = spec.split(":", 2)
            counts = READERS[fmt](path)
            for item, (length, orange_length, _, log) in truth.items():
                if item not in counts:
                    continue
                subs = sum(flag for _, _, flag in log)
                true_id = 100 * (1 - subs / len(log))
                m, n, gt, gq = counts[item]
                identity = int(re.search(r"id(\d+)", item).group(1))
                out.write(f"{name}\t{item}\t{identity}\t{length}\t{true_id:.3f}\t"
                          f"{100 * m / n:.3f}\t{n}\t{m}\t{subs}\t"
                          f"{orange_length - length}\t{gt}\t{gq}\n")


if __name__ == "__main__":
    main()
