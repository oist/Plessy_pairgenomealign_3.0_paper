#!/bin/bash
# Merge the results of several coverage jobs into one analysis directory,
# $BUCKET_DIR/analysis/NAME, readable by bin/07_compare_gulhan.sh:
#   tables/coverage_per_chromosome.tsv  union of the inputs; a row present in several
#                                       inputs (same exons, alignment, chrom) must be
#                                       identical in all of them, otherwise nothing is kept
#   tables/coverage_genome.tsv          recomputed from the merged table
#   tables/gulhan2025_fig1b_long.tsv    copied from the first input that has it
#   tables/provenance.txt               provenance of all inputs, concatenated
#   exons/, alignments/                 symbolic links to the inputs' BED files
# Small text files only: runs on a login node.
#
# Usage: bin/08_merge_analyses.sh NAME DIR...
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../settings.sh"
check_settings
name=${1:?usage: $0 NAME DIR...}
shift
[ $# -ge 1 ] || { echo "usage: $0 NAME DIR..." >&2; exit 1; }
O=$BUCKET_DIR/analysis/$name
[ ! -e "$O" ] || { echo "$O already exists" >&2; exit 1; }

umask 002
mkdir -p "$O/tables" "$O/exons" "$O/alignments"
trap 'echo "Failed: removing $O" >&2; rm -rf "$O"' ERR

tables=()
for d in "$@"; do tables+=("$d/tables/coverage_per_chromosome.tsv"); done
awk -F'\t' '
    FNR == 1 { if (NR == 1) print; next }
    { k = $1 FS $2 FS $3
      if (k in row) {
          if (row[k] != $0) { print "conflict in " FILENAME ": " $0 > "/dev/stderr"; bad = 1 }
          next }
      row[k] = $0; print }
    END { exit bad }' "${tables[@]}" > "$O/tables/coverage_per_chromosome.tsv"

awk -F'\t' -v OFS='\t' '
    NR == 1 { print "exons", "alignment", "exons_total", "exons_hit", "fraction_exons_hit",
                    "cds_bp", "cds_bp_covered", "fraction_bp_covered"; next }
    { k = $1 OFS $2; n[k] += $4; h[k] += $5; l[k] += $6; c[k] += $7 }
    END { for (k in n) printf "%s\t%d\t%d\t%.4f\t%d\t%d\t%.4f\n", k, n[k], h[k], h[k]/n[k], l[k], c[k], c[k]/l[k] }
' "$O/tables/coverage_per_chromosome.tsv" | LC_ALL=C sort > "$O/tables/coverage_genome.tsv"

for d in "$@"; do
    if [ -s "$d/tables/gulhan2025_fig1b_long.tsv" ]; then
        cp "$d/tables/gulhan2025_fig1b_long.tsv" "$O/tables/"
        break
    fi
done

for d in "$@"; do
    echo "== $d"
    cat "$d/tables/provenance.txt"
done > "$O/tables/provenance.txt"

for d in "$@"; do
    for sub in exons alignments; do
        for f in "$d/$sub"/*.bed; do
            [ -e "$f" ] || continue
            l=$O/$sub/${f##*/}
            [ -e "$l" ] || ln -s "$f" "$l"
        done
    done
done

echo "Merged $# analyses into $O"
tail -n +2 "$O/tables/coverage_genome.tsv" | cut -f2 | sort -u | tr '\n' ' '
echo
