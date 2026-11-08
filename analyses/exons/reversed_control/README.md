Reversed-query control
======================

Negative control for false-positive alignments: the mouse genome (mm39) reversed but
not complemented by `lastal --reverse`, aligned to the human genome (hg38) with the RY4
seed and the scores trained in the real run (run `ry4_rev`; scripts and commands in
`analyses/benchmark_runs/`, section "Reversed-query controls").

- `ry4_rev_report.txt`: output of `bin/03_check.sh ry4_rev` (MAF header, LAST versions,
  command lines, trace of the LAST tasks), followed by the files of the `alignment/`
  directories and the MultiQC one-to-one statistics of runs `ry4` and `ry4_rev`, and the
  execution trace of `ry4_rev`.
- `aligned_bp.tsv`: target bases covered by each alignment set (`bin/11_aligned_bp.sh`).
- `coverage_genome.tsv`, `coverage_per_chromosome.tsv`, `provenance.txt`: output of
  `bin/06_coverage.sh ry4 ry4_rev`, in the same format as `../tables/`.

Result: the many-to-many output of `ry4_rev` contains a single alignment, covering 178
target bases and no coding exon; the many-to-one and one-to-one outputs are empty.  The
real run (`ry4`) covers 447 Mb of the target in its one-to-one alignments.
