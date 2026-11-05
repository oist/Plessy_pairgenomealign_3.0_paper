# Settings shared by the scripts in bin/. Sourced, not executed.
# Edit BUCKET_DIR before the first run; the scripts refuse to start while it contains "<".

# This directory: scripts, configs, Slurm logs, Nextflow launch directories.
BASE=/flash/LuscombeU/charles-plessy/persistent/pairalignbenchmark

# Inputs and results. Bucket is read-only on compute nodes; it is written by the
# datacp download job, by the Nextflow driver on a login node, and by scp from the
# coverage job.
BUCKET_DIR='/bucket/LuscombeU/live/charles-plessy/pairalignbenchmark'

# Nextflow work directories, one per run: $WORK_ROOT/deleteme_pga_<run>.
WORK_ROOT=/flash/LuscombeU/charles-plessy/cache

PIPELINE=nf-core/pairgenomealign
PIPELINE_REV=3.0.4
TARGET_NAME=hg38
QUERY_NAME=mm39

# Images for the coverage job, downloaded once to $BASE/containers.
# bedtools 2.31.1, as pinned in nf-core/modules bedtools/merge.
BEDTOOLS_SIF_URL=https://depot.galaxyproject.org/singularity/bedtools:2.31.1--hf5e1c6e_0
# LAST 1652 + samtools, the image of the LAST modules in pairgenomealign 3.0.4 (for maf-convert).
LAST_SIF_URL=https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/62/62292ffa3ecc9230d6ad20b2537a2f4434a08908864c4c2c66f2d8667f031924/data

check_settings() {
    case $BUCKET_DIR in
        *'<'*) echo "Set BUCKET_DIR in $BASE/settings.sh first." >&2; exit 1 ;;
    esac
}
