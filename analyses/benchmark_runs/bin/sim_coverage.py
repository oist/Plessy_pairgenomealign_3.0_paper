#!/usr/bin/env python3
"""Coverage of simulated homologous pairs (Gulhan et al. 2025, Fig. 1A).

Each target sequence APPLE_id<I>_len<L> is a core of L bases between two random
1000-base flanks; its homologue is ORANGE_id<I>_len<L>.  For every aligner and
every pair, report:

  core_bp        core bases of the APPLE covered by alignments to its own ORANGE
  core_fraction  core_bp / L
  flank_bp       flank bases of the APPLE covered by alignments to its own ORANGE
                 (flanks are random: aligned flank bases are false positives)
  offtarget_bp   APPLE bases covered by alignments to any other ORANGE
                 (unrelated random sequences: all false positives)
  span_fraction  bases of the APPLE covered by any alignment, divided by L;
                 close to the measure plotted by Gulhan et al., who merged all
                 alignment spans on the target without filtering

Coverage is counted on alignment spans (gaps included), on the APPLE side,
after merging overlapping intervals.

A second table, OUT with ".tsv" replaced by ".ends.tsv", gives for every pair
found the position of the two outer ends of its alignments to its own ORANGE,
relative to the boundaries between the homologous core and the random flanks
(APPLE coordinates): distance > 0 means the alignment runs that many bases into
the random flank, distance < 0 means it stops that many bases inside the core.

Usage: sim_coverage.py OUT.tsv NAME:FORMAT:FILE [NAME:FORMAT:FILE ...]
FORMAT is one of maf (MAF, optionally gzipped, APPLE as reference),
blasttab (lastal -f BlastTab), lastz-general, paf.
"""

import gzip
import re
import sys

FLANK = 1000
NAME_RE = re.compile(r"^(APPLE|ORANGE)_(id\d+_len\d+)$")


def opener(path):
    return gzip.open(path, "rt") if path.endswith(".gz") else open(path, "rt")


def pair_id(name):
    m = NAME_RE.match(name)
    if not m:
        raise ValueError(f"unexpected sequence name: {name}")
    return m.group(2)


def read_maf(path):
    """Yield (target, start0, end, query) from MAF; first 's' line is the reference."""
    rows = []
    with opener(path) as f:
        for line in f:
            if line.startswith("a"):
                rows = []
            elif line.startswith("s"):
                rows.append(line.split())
                if len(rows) == 2:
                    t, q = rows
                    start, size = int(t[2]), int(t[3])
                    yield t[1], start, start + size, q[1]


def read_blasttab(path):
    with opener(path) as f:
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            c = line.rstrip("\n").split("\t")
            s1, s2 = int(c[8]), int(c[9])
            yield c[1], min(s1, s2) - 1, max(s1, s2), c[0]


def read_lastz_general(path):
    with opener(path) as f:
        for line in f:
            if line.startswith("#") or not line.strip():
                continue
            c = line.rstrip("\n").split("\t")
            yield c[1], int(c[4]), int(c[5]), c[6]


def read_paf(path):
    with opener(path) as f:
        for line in f:
            if not line.strip():
                continue
            c = line.rstrip("\n").split("\t")
            yield c[5], int(c[7]), int(c[8]), c[0]


READERS = {"maf": read_maf, "blasttab": read_blasttab,
           "lastz-general": read_lastz_general, "paf": read_paf}


def merge(intervals):
    out = []
    for s, e in sorted(intervals):
        if out and s <= out[-1][1]:
            out[-1][1] = max(out[-1][1], e)
        else:
            out.append([s, e])
    return out


def overlap(merged, lo, hi):
    return sum(max(0, min(e, hi) - max(s, lo)) for s, e in merged)


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    out_path = sys.argv[1]
    ends_path = re.sub(r"\.tsv$", "", out_path) + ".ends.tsv"
    with open(out_path, "w") as out, open(ends_path, "w") as ends:
        ends.write("aligner\tpair\tidentity\tlength\tend\tdistance\tpieces\n")
        out.write("aligner\tpair\tidentity\tlength\tcore_bp\tcore_fraction\t"
                  "flank_bp\tofftarget_bp\tspan_fraction\n")
        for spec in sys.argv[2:]:
            name, fmt, path = spec.split(":", 2)
            own, other, every = {}, {}, {}
            for target, start, end, query in READERS[fmt](path):
                t = pair_id(target)
                every.setdefault(t, []).append((start, end))
                if pair_id(query) == t:
                    own.setdefault(t, []).append((start, end))
                else:
                    other.setdefault(t, []).append((start, end))
            pairs = [f"id{i}_len{n}" for i in range(100, 59, -1)
                     for n in (1000, 2000, 5000, 10000)]
            for p in pairs:
                identity, length = map(int, re.findall(r"\d+", p))
                m_own = merge(own.get(p, []))
                core = overlap(m_own, FLANK, FLANK + length)
                flank = (overlap(m_own, 0, FLANK)
                         + overlap(m_own, FLANK + length, 2 * FLANK + length))
                off = sum(e - s for s, e in merge(other.get(p, [])))
                span = sum(e - s for s, e in merge(every.get(p, [])))
                out.write(f"{name}\t{p}\t{identity}\t{length}\t{core}\t"
                          f"{core / length:.4f}\t{flank}\t{off}\t"
                          f"{span / length:.4f}\n")
                if m_own:
                    left = FLANK - m_own[0][0]                 # > 0: into the left flank
                    right = m_own[-1][1] - (FLANK + length)    # > 0: into the right flank
                    for side, dist in (("left", left), ("right", right)):
                        ends.write(f"{name}\t{p}\t{identity}\t{length}\t{side}\t"
                                   f"{dist}\t{len(m_own)}\n")


if __name__ == "__main__":
    main()
