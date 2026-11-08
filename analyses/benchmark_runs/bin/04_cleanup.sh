#!/bin/bash
# Delete what a run left on /flash outside the published results: the work
# directory, and the Nextflow history in the launch directory. The .nextflow.log
# files are moved to logs/RUN/ first. After this, -resume is no longer possible.
#
# Usage: bin/04_cleanup.sh RUN
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../settings.sh"
run=${1:?usage: $0 RUN}
W=$WORK_ROOT/deleteme_pga_$run
L=$BASE/runs/$run

echo "Will delete: $W"
echo "Will delete: $L/.nextflow"
echo "Will move:   $L/.nextflow.log* -> $BASE/logs/$run/ (date-prefixed)"
read -r -p "Proceed? [y/N] " answer
[ "$answer" = y ] || exit 1

umask 002
mkdir -p "$BASE/logs/$run"
stamp=$(date +%Y%m%d-%H%M%S)
for f in "$L"/.nextflow.log*; do
    if [ -e "$f" ]; then mv "$f" "$BASE/logs/$run/$stamp${f##*/}"; fi
done
rm -rf "$W" "$L/.nextflow"
