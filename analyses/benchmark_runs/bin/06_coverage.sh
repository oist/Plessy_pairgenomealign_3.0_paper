#!/bin/bash
# Submit the coverage job (bin/coverage_job.sh) to the compute partition.
# Run on a login node once the alignment runs are published on Bucket.
#
# Usage: bin/06_coverage.sh [RUN ...]      default: r0 ry128 ry4 near
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../settings.sh"
check_settings
mkdir -p "$BASE/logs"
[ $# -gt 0 ] || set -- r0 ry128 ry4 near

sbatch -p compute -c 8 --mem=64G -t 1-00:00:00 -J pga_coverage \
    -o "$BASE/logs/06_coverage-%j.out" \
    --export=ALL,PGA_BASE="$BASE" \
    "$BASE/bin/coverage_job.sh" "$@"
