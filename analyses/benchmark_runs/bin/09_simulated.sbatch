#!/bin/bash
#SBATCH --job-name=sim-last
#SBATCH --partition=compute
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=0-02:00:00
#SBATCH --output=sim-last-%j.out
#SBATCH --error=sim-last-%j.err

#===============================================================================
# LAST on the simulated sequence pairs of Gulhan et al. (2025, Fig. 1A), with
# the commands and container image of nf-core/pairgenomealign 3.0.4, as for
# Figure 5C (modules/nf-core/last/* and conf/modules.config at tag 3.0.4):
#
#   lastdb     -R01 -c -U400 -u<seed> -S2 -P <cpus> <db> apple.indels.fa
#   last-train -Qfastx --revsym --gapsym --matsym -C2 -D1e9 -P <cpus> <db> orange.indels.fa
#   lastal     -P <cpus> -p <train> -C2 -D1e9 <db> orange.indels.fa     (many-to-many)
#
# APPLE sequences are the target, as in their LAST run (Reference sequences=164).
# Then bin/sim_coverage.py tabulates coverage and alignment ends per pair for
# these runs and for the outputs published by Gulhan et al. (lastz, LAST,
# FastGA, minimap2), bin/sim_truth.py re-runs their simulation with a mutation
# log, and bin/sim_identity.py compares alignment identity with true identity.
# Two control runs with the RY4 seed test why LAST alignments stop short of the
# homology boundary at low identity (X-drop, training).
#
# Submit from the directory that contains bin/sim_*.py (Slurm writes its
# log files there, so it must be writable from compute nodes):
#   sbatch bin/09_simulated.sbatch
#
# Optional environment variables (sbatch passes the submitting environment):
#   DEST        results directory on Bucket (default below)
#   GULHAN_DIR  local copy of github.com/nekrut/lz-fg-mm at commit ded50e5, if
#               compute nodes cannot reach GitHub (git clone it on a login node)
#   SEEDS       default "RY128 RY4 YASS MAM8"
#===============================================================================

umask 002
ml purge                  # modules first: Lmod functions are not written for set -u
ml bioinfo-ugrp-modules
ml Nextflow3              # provides singularity
set -euo pipefail

SEEDS=${SEEDS:-"RY128 RY4 YASS MAM8"}
DEST=${DEST:-/bucket/LuscombeU/live/$(whoami)/pairalignbenchmark/pairgenomealign_simulated}
NCPU=${SLURM_CPUS_PER_TASK:-8}
SCRATCH_ROOT=${SCRATCH_ROOT:-/flash/LuscombeU/$(whoami)/cache}
SUBMIT_DIR=${SLURM_SUBMIT_DIR:-$PWD}

# Simulated sequences and published alignments (Gulhan et al.), pinned commit.
REPO_COMMIT=ded50e5888a2011c52321c0cebdee6b12f2e13b0
REPO_RAW=https://raw.githubusercontent.com/nekrut/lz-fg-mm/$REPO_COMMIT
REPO_FILES="sequences/apple.indels.fa sequences/orange.indels.fa
            alignments/last.tsv alignments/lastz.general
            alignments/fastga.paf alignments/minimap2.paf
            ipynb/generate_apples_and_oranges.ipynb"

# Container of the LAST modules in nf-core/pairgenomealign 3.0.4.  The cache file
# name is the one Nextflow derives from the URL; if it is absent, download it.
SIF_URL=https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/62/62292ffa3ecc9230d6ad20b2537a2f4434a08908864c4c2c66f2d8667f031924/data
SIF_CACHE=/hpcshare/appsunit/LuscombeU/singularity.cacheDir/community-cr-prod.seqera.io-docker-registry-v2-blobs-sha256-62-62292ffa3ecc9230d6ad20b2537a2f4434a08908864c4c2c66f2d8667f031924-data.img

#--- Scratch directory, copied to Bucket and deleted at exit ------------------

mkdir -p "$SCRATCH_ROOT"
WORK=$(mktemp -d "$SCRATCH_ROOT/deleteme_simlast.XXXXXX")
chmod 775 "$WORK"         # mktemp creates it 700; unit members must be able to delete it
mkdir -p "$WORK/results"

# Complete results only are copied to Bucket, so that they never mix with the
# files of an earlier run.
finish() {
    status=$?
    set +e
    if [ "$status" -ne 0 ]; then
        echo "Job failed (exit status $status): nothing copied to $DEST;" \
             "partial results kept in $WORK; delete it once inspected." >&2
    elif ssh deigo mkdir -p "$DEST" && scp -rq "$WORK"/results/* "deigo:$DEST/"; then
        rm -rf "$WORK"
        echo "Results copied to $DEST; scratch directory deleted."
    else
        echo "Copy to $DEST failed: results kept in $WORK; delete it once retrieved." >&2
    fi
    exit $status
}
trap finish EXIT

#--- Container image -----------------------------------------------------------

if [ -s "$SIF_CACHE" ]; then
    SIF=$SIF_CACHE
else
    SIF=$WORK/last.sif
    curl -fsSL -o "$SIF" "$SIF_URL"
fi
# Commands run in the container, with $WORK as working directory (run) or
# another directory under $WORK (run_in DIR): the container ignores the cd of
# the calling shell.
run_in() { local dir=$1; shift; singularity exec -B "$WORK" --pwd "$dir" "$SIF" "$@"; }
run()    { run_in "$WORK" "$@"; }

#--- Inputs --------------------------------------------------------------------

cd "$WORK"
for f in $REPO_FILES; do
    mkdir -p "gulhan/$(dirname "$f")"
    if [ -n "${GULHAN_DIR:-}" ]; then
        cp "$GULHAN_DIR/$f" "gulhan/$f"
    else
        curl -fsSL -o "gulhan/$f" "$REPO_RAW/$f"
    fi
done
(cd gulhan && sha256sum -c --quiet) <<'EOF'
79e0eda49a219bb174ae96fabc2c62499f0b1d0e1866f417f0d0d6e703244862  sequences/apple.indels.fa
33500b8eb9c29cb2bb467a0c14b63c2a8b4e4895ee04f8b6ae7302946820bd5c  sequences/orange.indels.fa
f76ebdb1778acef4db4f960c15574712b8dae2b48e40faa20486845f8680c39f  alignments/last.tsv
455331af9406fee8b5e70b49ef663c849132aa2f0bf96d54c2b309dcb1026d31  alignments/lastz.general
85f5b7fd5ce7472ebeaeb0e4f5f6b83c70d10e2335ca3b79a0329619e86e0cbf  alignments/fastga.paf
bcd8484a9ce9b2052a3c44ca23a832c645f2ce74160514b47026e1befad99a55  alignments/minimap2.paf
0ba1b45c32a55e501f8151c5011dcacec5b866125d62c027c65257c2e7fd6131  ipynb/generate_apples_and_oranges.ipynb
EOF
cp "$SUBMIT_DIR"/bin/sim_coverage.py "$SUBMIT_DIR"/bin/sim_truth.py "$SUBMIT_DIR"/bin/sim_identity.py .

{
    echo "date: $(date -Is)"
    echo "host: $(hostname)"
    echo "image: $SIF"
    echo "inputs: github.com/nekrut/lz-fg-mm@$REPO_COMMIT"
    run lastal --version
} > results/provenance.txt

#--- Alignments: pipeline 3.0.4 defaults, one seed at a time -------------------

for seed in $SEEDS; do
    mkdir -p "lastdb_$seed"
    run lastdb -R01 -c -U400 -u"$seed" -S2 -P "$NCPU" \
        "lastdb_$seed/apple" gulhan/sequences/apple.indels.fa
    run last-train -Qfastx --revsym --gapsym --matsym -C2 -D1e9 -P "$NCPU" \
        "lastdb_$seed/apple" gulhan/sequences/orange.indels.fa \
        > "results/$seed.train"
    run lastal -P "$NCPU" -p "results/$seed.train" -C2 -D1e9 \
        "lastdb_$seed/apple" gulhan/sequences/orange.indels.fa |
        gzip --no-name > "results/$seed.m2m.maf.gz"
    echo "lastdb -R01 -c -U400 -u$seed -S2; last-train -Qfastx --revsym --gapsym --matsym -C2 -D1e9; lastal -C2 -D1e9" \
        >> results/provenance.txt
done

#--- Controls with the RY4 seed (not pipeline settings) ------------------------
# last-train above fits one set of scores to all 164 pairs pooled (60-100%
# identity).  Two tests of why LAST alignments stop short of the homology
# boundary at low identity:
#   RY4-xdrop1000  the same scores, with X-drop thresholds raised to 1000
#                  (lastal -x1000 -z1000);
#   RY4-lowtrain   scores fitted to the 44 ORANGE sequences of 60-70% nominal
#                  identity only; lastal then aligns all pairs as above.

controls=()
if [ -d lastdb_RY4 ]; then
    run lastal -P "$NCPU" -p results/RY4.train -C2 -D1e9 -x1000 -z1000 \
        lastdb_RY4/apple gulhan/sequences/orange.indels.fa |
        gzip --no-name > results/RY4-xdrop1000.m2m.maf.gz
    awk '/^>/ { split($1, a, "_"); keep = (substr(a[2], 3) + 0 <= 70) } keep' \
        gulhan/sequences/orange.indels.fa > orange_low.fa
    [ "$(grep -c '^>' orange_low.fa)" -eq 44 ]
    run last-train -Qfastx --revsym --gapsym --matsym -C2 -D1e9 -P "$NCPU" \
        lastdb_RY4/apple orange_low.fa > results/RY4-lowtrain.train
    run lastal -P "$NCPU" -p results/RY4-lowtrain.train -C2 -D1e9 \
        lastdb_RY4/apple gulhan/sequences/orange.indels.fa |
        gzip --no-name > results/RY4-lowtrain.m2m.maf.gz
    {
        echo "RY4-xdrop1000: lastal as above, plus -x1000 -z1000"
        echo "RY4-lowtrain: last-train as above on the ORANGE sequences of 60-70% identity only; lastal as above"
    } >> results/provenance.txt
    controls=( "LAST-RY4-xdrop1000:maf:results/RY4-xdrop1000.m2m.maf.gz"
               "LAST-RY4-lowtrain:maf:results/RY4-lowtrain.m2m.maf.gz" )
fi

#--- Coverage per pair ---------------------------------------------------------

specs=( "lastz:lastz-general:gulhan/alignments/lastz.general"
        "LAST-Gulhan:blasttab:gulhan/alignments/last.tsv"
        "FastGA:paf:gulhan/alignments/fastga.paf"
        "minimap2:paf:gulhan/alignments/minimap2.paf" )
for seed in $SEEDS; do
    specs+=( "pairgenomealign-$seed:maf:results/$seed.m2m.maf.gz" )
done
specs+=( ${controls[@]+"${controls[@]}"} )   # empty-safe under set -u
run python3 -I sim_coverage.py results/coverage.tsv "${specs[@]}"

#--- True identity: re-run the simulation with a mutation log ------------------
# The regenerated sequences must be identical to the published ones.

mkdir truth               # sim_truth.py writes into its working directory
run_in "$WORK/truth" python3 -I "$WORK/sim_truth.py" "$WORK/gulhan/ipynb/generate_apples_and_oranges.ipynb"
cmp truth/apple.indels.fa  gulhan/sequences/apple.indels.fa
cmp truth/orange.indels.fa gulhan/sequences/orange.indels.fa

#--- Identity of the alignments versus true identity ---------------------------
# FastGA and minimap2 are left out: their published PAF files have no
# base-level alignment.

specs=( "lastz:lastz-general:gulhan/alignments/lastz.general" )
for seed in $SEEDS; do
    specs+=( "pairgenomealign-$seed:maf:results/$seed.m2m.maf.gz" )
done
specs+=( ${controls[@]+"${controls[@]}"} )   # empty-safe under set -u
run python3 -I sim_identity.py truth/truth.json results/identity.tsv "${specs[@]}"
cp sim_coverage.py sim_truth.py sim_identity.py results/
