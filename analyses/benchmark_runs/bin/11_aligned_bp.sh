#!/bin/bash
# Target bases covered by each alignment set of an analysis directory made by
# bin/06_coverage.sh or bin/08_merge_analyses.sh: the total length of the merged
# intervals in DIR/alignments/*.bed, over all target sequences.
# Writes DIR/tables/aligned_bp.tsv (columns alignment, aligned_bp) and prints it.
# Small text files only: runs on a login node.
#
# Usage: bin/11_aligned_bp.sh DIR
set -euo pipefail
D=${1:?usage: $0 DIR}
[ -d "$D/alignments" ] || { echo "No such directory: $D/alignments" >&2; exit 1; }

umask 002
{
    printf 'alignment\taligned_bp\n'
    for a in "$D"/alignments/*.bed; do
        [ -e "$a" ] || continue
        awk -F'\t' -v A="$(basename "$a" .bed)" \
            '{ s += $3 - $2 } END { printf "%s\t%.0f\n", A, s }' "$a"
    done
} > "$D/tables/aligned_bp.tsv"
column -t "$D/tables/aligned_bp.tsv"
