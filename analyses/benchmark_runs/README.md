# pairalignbenchmark

Benchmark for the nf-core/pairgenomealign 3.0 manuscript: fraction of hg38 coding
exons overlapped by alignments to mm39, as in Fig. 1B of Gulhan et al. (2025)
Genome Biology 26:389 (KegAlign). Run R0 reproduces their LAST run; the other runs
change one factor at a time (see "Runs").

## Storage

| What | Where |
|---|---|
| This directory: scripts, configs, Slurm logs, Nextflow launch directories | `/flash/LuscombeU/charles-plessy/persistent/pairalignbenchmark` |
| Inputs, pipeline results, coverage tables | `$BUCKET_DIR` (set in `settings.sh`) |
| Nextflow work directories | `/flash/LuscombeU/charles-plessy/cache/deleteme_pga_<run>`, removed by `bin/04_cleanup.sh` |
| Images for the coverage job | `containers/`, downloaded on first use |

`/flash` is scratch: not backed up, expected by SCDA to be emptied after each job, and
under the unit convention any unit member may delete files there at any time. Only small
files live in this directory; inputs and results go to Bucket. Keep a copy of the
archive on Bucket.

## Installation

```bash
cd /flash/LuscombeU/charles-plessy/persistent
umask 002
tar xzf pairalignbenchmark.tgz
chgrp -R <unit group> pairalignbenchmark      # only if your primary group is not the unit group
chmod -R g+rwX pairalignbenchmark
find pairalignbenchmark -type d -exec chmod g+s {} +
```

Then set `BUCKET_DIR` in `settings.sh`. The scripts stop while it still contains `<`.

## Layout

```
settings.sh               paths, pipeline version, genome names, image URLs
conf/deigo-executor.config  Slurm throttling, unit Singularity cache
conf/r0.config            R0 only: LAST 1608 image and Gulhan et al.'s LAST arguments
params/<run>.yaml         per-run pipeline parameters (r0, ry128, ry4, near)
bin/01_download.sh        datacp job: genomes and UCSC gene tables -> $BUCKET_DIR/inputs
bin/02_run.sh RUN         Nextflow driver on the login node (run inside tmux)
bin/03_check.sh RUN       LAST version, command lines and trace of a finished run
bin/04_cleanup.sh RUN     delete the run's work directory and Nextflow history
bin/05_kegalign.sh        Gulhan et al.'s per-chromosome table and Galaxy history listing
bin/06_coverage.sh [RUN]  submit bin/coverage_job.sh (compute partition)
runs/RUN/                 Nextflow launch directories (created by 02_run.sh)
logs/                     Slurm logs; logs/RUN/ holds .nextflow.log files moved by 04_cleanup.sh
```

## Runs

| Run | LAST | Settings | Contrast |
|---|---|---|---|
| `r0` | 1608 | Gulhan et al.'s commands: `lastdb -uRY128`, `last-train --revsym -C2`, `lastal -C2`; m2m only | must reproduce their LAST series |
| `ry128` | 1652 | pipeline defaults, seed RY128 | vs r0: masking (`-R01 -c -U400`), `-S2`, symmetric training, `-D1e9`, LAST version |
| `ry4` | 1652 | pipeline defaults, seed RY4 | vs ry128: seed only |
| `near` | 1652 | pipeline defaults, seed NEAR | seeds of the manuscript's Fig. 5 |

The P runs use `--m2m`. The pipeline then runs lastal once without `--split` and derives
m2o, o2m and o2o from that output with `last-split`. For r0, `conf/r0.config` disables the
split steps.

R0 still differs from Gulhan et al. in two ways, neither of which changes the alignments:
the output is MAF instead of BlastTab, and `-P` comes from `task.cpus` instead of 24, which
changes output order only.

## Steps

All commands run on a login node from this directory.

1. `bin/01_download.sh` submits the datacp job, which writes `$BUCKET_DIR/inputs`: the
   genomes with their UCSC md5 checks, the `knownGene`, `ncbiRefSeq` and `refGene` tables,
   `md5sum.local.txt` and `download_date.txt`.

2. Start the pipeline runs one at a time, in tmux on a login node whose name you record.
   Run `r0` first, so that the images are pulled once before any other run.
   ```bash
   ml purge; ml bioinfo-ugrp-modules; ml Nextflow3
   nextflow -version          # pairgenomealign 3.0.4 requires Nextflow >= 26.04.0
   bin/02_run.sh r0           # add -resume after an interruption
   ```
   To run all four in sequence, one driver at a time:
   `for r in r0 ry128 ry4 near; do bin/02_run.sh "$r" || break; done`.
   Results are published to `$BUCKET_DIR/runs/RUN`.

3. `bin/03_check.sh RUN` prints the MAF header, the LAST versions, the LAST command lines
   as executed, and the trace of the LAST tasks.
   - For r0, the command lines must match the commands above except for `-P` and the
     file names.
   - If `%cpu` and `peak_rss` are missing for the r0 LAST tasks, the LAST 1608 image
     probably lacks `ps`. Take the figures from Slurm instead, using the `native_id`
     column: `sacct -j <native_id> -o JobID,Elapsed,TotalCPU,MaxRSS`. On Deigo, MaxRSS is
     PSS sampled every 30 s.

4. `bin/04_cleanup.sh RUN` asks for confirmation, then deletes the work directory and
   `runs/RUN/.nextflow`. It moves `.nextflow.log*` to `logs/RUN/`. Run it after step 3,
   because `nextflow log` needs the history. Afterwards `-resume` is no longer possible.

5. `bin/05_kegalign.sh` saves Gulhan et al.'s per-chromosome table
   (`fig1b_per_chromosome.tsv`, columns chr, count, fg, lz, mm, lt) and the listing of
   their Galaxy history to `$BUCKET_DIR/kegalign`. The script prints how to download
   further datasets by hand.
   - Any alignment BED in hg38 coordinates saved as `$BUCKET_DIR/other_alignments/NAME.bed`
     is included in step 6. Examples are their KegAlign BED, or UCSC lastz chains
     converted to BED.

6. `bin/06_coverage.sh [RUN ...]` submits the coverage job (default runs: r0 ry128 ry4
   near). The job runs in a temporary directory on `/flash`, which it deletes at the end,
   and copies its results with scp to `$BUCKET_DIR/analysis/<date>_<jobid>/`:
   - `exons/` holds the coding exons (CDS parts of exons, merged, chr1-22, X, Y, M) from
     each gene table, built like the Table Browser "coding exons" output.
   - `alignments/` holds the merged alignment intervals in hg38 coordinates, as
     `RUN.RELATION.bed` and `other.NAME.bed`.
   - `tables/coverage_per_chromosome.tsv` has the columns exons, alignment, chrom,
     exons_total, exons_hit (overlap of at least 1 bp), cds_bp, cds_bp_covered.
   - `tables/coverage_genome.tsv` has the same counts summed over chromosomes, with both
     fractions.
   - `tables/gulhan2025_fig1b_long.tsv` holds their table in the same long format.
   - `tables/provenance.txt` records the date, runs, images and input checksums.

## Identifying the exon set of Gulhan et al.

Compare `exons_total` per chromosome with their `count` column. The rows shown in their
notebook (`ipynb/cds_exon_coverage.ipynb` in https://github.com/nekrut/lz-fg-mm) are:
chr1 21699, chr10 8739, chr11 11967, chr12 12155, chr13 3721. If no gene table matches,
use knownGene and state its version and the download date.

The overlap rule of their Galaxy workflow `cdsoverlaps` is not confirmed. Before comparing
`exons_hit` with their numbers, check that the rule is "at least 1 bp".

## Tested and not tested

Tested outside Deigo, with stand-ins for `sbatch`, `singularity`, `ssh`, `scp` and `ml`:
- shellcheck on all scripts;
- the merged configuration with `-profile oist`, which shows the r0 overrides of `ext.args`,
  `container` and `ext.when` taking effect;
- a stub run of pipeline 3.0.4 with `conf/r0.config`;
  - the nf-schema plugin was replaced by stand-in functions, because the plugin registry
    was unreachable;
  - lastdb, train, lastal m2m, the QC steps and MultiQC ran;
  - all split steps were skipped, and the run completed;
- `bin/02_run.sh`, `bin/03_check.sh` and `bin/04_cleanup.sh` against that stub run;
- `bin/coverage_job.sh` end to end on toy genomes aligned with LAST 1542 using `-S2`; the
  conversion of minus-strand target coordinates agrees with `maf-convert psl`.

Not tested:
- the LAST 1608 image with the 3.0.4 module scripts. Between the 1608 and 1652 versions
  of the nf-core modules, only statistics and version collection changed; the LAST
  command lines are identical.
- whether the LAST 1608 image contains `ps` (step 3);
- whether datacp nodes can write the Slurm log to `/flash`. If the download job fails at
  once, change `-o` in `bin/01_download.sh` to a path under your home directory.
- `ml` inside batch scripts, as used in the oist-hpc-nextflow skill's examples;
- Singularity binding the job's working directory, which is Singularity's default;
- anonymous access to the Galaxy API (step 5).

## Provenance

- Gulhan et al.'s LAST commands: README of https://github.com/nekrut/lz-fg-mm.
- LAST 1608 image: nf-core/modules commit b651d7202 (2025-01-22).
- bedtools image: nf-core/modules `bedtools/merge`.
- Deigo settings (profile, cache path, throttling, work-directory naming, cleanup rules):
  the oist-hpc-nextflow and oist-hpc-policy skills.

## Run mam8 (added after the first four)

`params/mam8.yaml` sets seed MAM8 and keeps the other pipeline defaults, as for ry128, ry4
and near. `conf/mam8.config` gives lastdb, last-train, lastal and last-split 500 GB, the most
that fits one standard node, and 96 h, the compute-partition limit (above the 90 h cap of the
oist profile). It also gives 128 cores to the steps that use threads. These values are
conservative; revise them from the execution trace.

    bin/02_run.sh mam8
    bin/03_check.sh mam8
    bin/06_coverage.sh mam8
    bin/08_merge_analyses.sh NAME DIR...    # all coverage directories, including the mam8 one
## Run yass (shown instead of near in Figure 5C)

`params/yass.yaml` sets seed YASS and keeps the other pipeline defaults, as for near.
`conf/yass.config` gives the splitting steps the memory that `conf/near.config` gives them;
in the benchmark of Figure 4, YASS used about as much time and memory as NEAR.

    ml purge; ml bioinfo-ugrp-modules; ml Nextflow3
    bin/02_run.sh yass                 # login node, inside tmux
    bin/03_check.sh yass
    bin/06_coverage.sh yass            # prints nothing; results in $BUCKET_DIR/analysis/<date>_<jobid>/
    bin/08_merge_analyses.sh merged_with_yass \
        "$BUCKET_DIR/analysis/merged_with_mam8" "$BUCKET_DIR/analysis/<date>_<jobid>"
    bin/04_cleanup.sh yass             # once the check is done

Numbers for Figure 5C (Benchmark.Rmd, `exon` table, YASS row):

    awk -F'\t' '$1 == "other.gulhan2025_knownGene" && $2 == "yass.m2m"' \
        "$BUCKET_DIR/analysis/merged_with_yass/tables/coverage_genome.tsv"

columns: exons, alignment, exons_total, exons_hit, fraction_exons_hit, cds_bp,
cds_bp_covered, fraction_bp_covered.
