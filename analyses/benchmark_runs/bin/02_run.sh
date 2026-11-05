#!/bin/bash
# Launch one pipeline run with the Nextflow driver on this login node (mode 1 of
# the oist-hpc-nextflow skill). Run it inside tmux, one run at a time.
#
# Usage: bin/02_run.sh RUN [extra nextflow run options, e.g. -resume]
#   RUN is the name of a file params/RUN.yaml (r0, ry128, ry4, near).
#   conf/RUN.config is added when it exists (only r0 has one).
#
# Load the modules in the calling shell first:
#   ml purge; ml bioinfo-ugrp-modules; ml Nextflow3
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../settings.sh"
check_settings

run=${1:?usage: $0 RUN [nextflow options]}
shift
[ -f "$BASE/params/$run.yaml" ] || { echo "No such file: $BASE/params/$run.yaml" >&2; exit 1; }
command -v nextflow > /dev/null || { echo "nextflow not found: ml purge; ml bioinfo-ugrp-modules; ml Nextflow3" >&2; exit 1; }
[ -s "$BUCKET_DIR/inputs/$TARGET_NAME.fa.gz" ] || { echo "Missing $BUCKET_DIR/inputs/$TARGET_NAME.fa.gz: run bin/01_download.sh" >&2; exit 1; }

run_conf=()
[ -f "$BASE/conf/$run.config" ] && run_conf=(-c "$BASE/conf/$run.config")

umask 002
mkdir -p "$BASE/runs/$run"
cd "$BASE/runs/$run"          # launch directory: .nextflow/ and .nextflow.log go here

nextflow run "$PIPELINE" -r "$PIPELINE_REV" \
    -profile oist \
    -w "$WORK_ROOT/deleteme_pga_$run" \
    -c "$BASE/conf/deigo-executor.config" \
    ${run_conf[@]+"${run_conf[@]}"} \
    -params-file "$BASE/params/$run.yaml" \
    --target "$BUCKET_DIR/inputs/$TARGET_NAME.fa.gz" --targetName "$TARGET_NAME" \
    --query  "$BUCKET_DIR/inputs/$QUERY_NAME.fa.gz"  --queryName  "$QUERY_NAME" \
    --outdir "$BUCKET_DIR/runs/$run" \
    "$@"
