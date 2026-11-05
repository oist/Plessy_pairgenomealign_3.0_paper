#!/bin/bash
# Check a finished run before using its output: LAST version and parameters in the
# MAF header, software versions, the LAST command lines actually executed, and the
# resource metrics of the LAST tasks. Run on a login node, before bin/04_cleanup.sh
# (nextflow log needs the .nextflow/ history of the launch directory).
#
# Usage: bin/03_check.sh RUN
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../settings.sh"
check_settings
run=${1:?usage: $0 RUN}
R=$BUCKET_DIR/runs/$run
pair=${TARGET_NAME}___${QUERY_NAME}

echo "### MAF header ($pair.m2m.maf.gz)"
zcat "$R/alignment/$pair.m2m.maf.gz" | head -n 15 || true

echo "### Software versions (LAST)"
grep -h -B1 '^ *last:' "$R"/pipeline_info/*versions*.yml || true

echo "### LAST command lines"
command -v nextflow > /dev/null || { echo "nextflow not found: ml purge; ml bioinfo-ugrp-modules; ml Nextflow3" >&2; exit 1; }
cd "$BASE/runs/$run"
nextflow log last -f process,workdir -F 'process ==~ /.*ALIGNMENT_(LASTDB|TRAIN|LASTAL).*/' |
while read -r process workdir; do
    echo "== $process"
    awk '/^# capture process environment/ { exit } { print }' "$workdir/.command.sh"
done

echo "### Trace of the LAST tasks (missing %cpu/peak_rss: see README)"
awk -F'\t' -v OFS='\t' '
    FNR == 1 { for (i = 1; i <= NF; i++) col[$i] = i
               if (NR == 1) print "native_id", "name", "status", "realtime", "%cpu", "peak_rss"
               next }
    $col["name"] ~ /ALIGNMENT_(LASTDB|TRAIN|LASTAL)/ {
        print $col["native_id"], $col["name"], $col["status"], $col["realtime"], $col["%cpu"], $col["peak_rss"] }
' "$R"/pipeline_info/execution_trace_*.txt | column -ts$'\t'
