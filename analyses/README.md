Analyses
========

Scripts and data behind the article: first in the order in which the Results
section uses them, then the folders used elsewhere in the article, then what the
article does not use.

Results
-------

- `primates/`: Figure 2 (see its `README.md`), the all-versus-all alignment of
  the 35 genomes of the full-size test (33 primates and two outgroups) with
  release 3.0.4, November 2026.  `run_2026-11/`: execution trace, parameters,
  versions and MultiQC tables of each target, configuration files and
  GenomicBreaks run records; `genomicbreaks_yaml.tar.gz`: statistics of each
  ordered pair; `load_stats.R` loads them into `primates.benchmark.RData` and
  writes `genomes.tsv`, `distances.tsv` and `pair_statistics.tsv.gz`;
  `primates.Rmd` draws the figure; `primates_ncbi_lineages.tsv`: NCBI lineage of
  each genome; `maf_vs_cram.tsv`: sizes of the CRAM and one-to-one MAF files.
- `multiqc/`: the MultiQC report of the full-size test of release 3.0.4, which is
  the human-versus-others iteration of Figure 2.
- `vertebrates/`: Figure 3, the human genome against the phase 1 assemblies of the
  Vertebrate Genomes Project (see its `README.md`).
- `simulated/`: Figure 4, the simulated sequence pairs of Gulhan et al. (2025):
  coverage, alignment ends and identity per aligner, the scores trained with each
  seed, and the commands in `provenance.txt`.
- `myers/`: Figures 5 and 7, the five genomes of Myers et al. (2025) aligned to
  CHM13 with release 3.0.2: one directory per seed and replicate (`_cascade`:
  Intel nodes, otherwise AMD) with its execution trace and MultiQC tables, and
  `coverage.tsv`.
- `exons/`: Figure 6 and the negative control, human coding exons covered by
  alignments of the mouse genome: `tables/` (coverage per exon set and
  alignment), `gulhan2025/` (the Galaxy history and Figure 1B data of Gulhan et
  al.) and `reversed_control/` (the mouse genome reversed).

Elsewhere in the article
------------------------

- `benchmark_runs/`: scripts, parameters and configurations that ran the exon and
  simulated-pair benchmarks (see its `README.md`).
- `figures/`: the scripts that draw Figures 4 (`fig_simulated.R`), 5 and 6
  (`fig_benchmark.R`) and 7 (`fig_timeline.R`); run them from the repository root.

Not used in the article
-----------------------

- `myers/`: the runs with the NEAR seed, the many-to-many runs (`_m2m`), and
  `AWS/results-b64a8e6…/`, the full-size test of release 3.0.3 (GRCh38 against
  primates).
- `simulated/`: the rows `LAST-Gulhan` and `LAST-RY4-xdrop1000` of the tables, and
  `NEAR.train`.
- `exons/tables/`: the NEAR seed, the LAST commands of Gulhan et al. run in the
  pipeline (`r0`), the many-to-one and one-to-one alignments, and the exon sets
  `knownGene`, `ncbiRefSeq` and `refGene`.
- `benchmark_runs/params/yass_rev.yaml`: a reversed control with the YASS seed,
  not run.
- `vertebrates/run_2026-09/`: the first run; the article uses the rerun.
