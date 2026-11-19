#!/bin/bash
#SBATCH --job-name=cds-ext
#SBATCH --partition=short
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=0-00:30:00
#SBATCH --output=cds-ext-%j.out
#SBATCH --error=cds-ext-%j.err

#===============================================================================
# Where the coverage of human coding exons differs between KegAlign (lastz
# scoring) and LAST, in the exon benchmark (Gulhan et al. 2025, Fig. 1B).
#
# For each LAST run, the coding bases covered by KegAlign and not by LAST, and
# the reverse, are cut into segments and classified:
#   exon_not_hit    in an exon that the other aligner does not touch at all
#                   (a question of detection: seeds, sensitivity)
#   next_to_1_end   next to one alignment of the other aligner, which stops there
#                   (one aligner extends further than the other)
#   between_2       between two alignments of the other aligner (an internal gap)
#   apart           in an exon hit by the other aligner, touching none of its
#                   alignments
# with their lengths in bins.  Over-extension by a few bases can only produce
# short next_to_1_end segments.
# Also: alignment ends inside coding exons (the base beyond the end is coding),
# which bounds how much a few bases of extension per end can add.
#
# Inputs: the merged analysis of bin/08_merge_analyses.sh (exons/ and
# alignments/, merged BED files in hg38 coordinates).  Output: tables in the
# Slurm .out file.  Small job: short partition.
#
# Submit from the pairalignbenchmark directory (it holds settings.sh):
#   sbatch bin/10_cds_extension.sbatch [ANALYSIS_NAME [LAST_BED ...]]
# defaults: merged_with_yass, and ry4.m2m yass.m2m mam8.m2m
#===============================================================================

umask 002
ml purge                  # modules first: Lmod functions are not written for set -u
ml bioinfo-ugrp-modules
ml Nextflow3              # provides singularity
set -euo pipefail

source "${SLURM_SUBMIT_DIR:-$PWD}/settings.sh"
check_settings

A=$BUCKET_DIR/analysis/${1:-merged_with_yass}
shift || true
LAST_BEDS=${*:-"ry4.m2m yass.m2m mam8.m2m"}
EXONS=other.gulhan2025_knownGene          # their exon set, as in bin/07_compare_gulhan.sh
REF=other.gulhan2025_galaxy_lastz         # KegAlign, their merged BED
SIF=$BASE/containers/bedtools_2.31.1.sif  # downloaded by bin/coverage_job.sh
[ -s "$SIF" ] || { echo "$SIF missing: run bin/06_coverage.sh once" >&2; exit 1; }

# Scratch directory on /flash, deleted at exit.  Inputs are copied there
# (symbolic links resolved), so that the container sees them.
T=$(mktemp -d "$WORK_ROOT/deleteme_cdsext.XXXXXX")
chmod 775 "$T"
trap 'rm -rf "$T"' EXIT
cp -L "$A/exons/$EXONS.bed" "$T/E.bed"
cp -L "$A/alignments/$REF.bed" "$T/K.bed"
for r in $LAST_BEDS; do cp -L "$A/alignments/$r.bed" "$T/$r.bed"; done
bt() { singularity exec -B "$T" --pwd "$T" "$SIF" bedtools "$@"; }
cd "$T"

sum_bp() { awk '{ s += $3 - $2 } END { print s + 0 }'; }

# Segments of the coding bases covered by $1 and not by $2, classified with
# respect to $2.  Prints: class, length bin, segments, bases.
classify() {
    bt intersect -a E.bed -b "$1" | bt subtract -a stdin -b "$2" > only.bed
    bt intersect -a E.bed -b "$2" -v > missed_exons.bed
    {
        bt intersect -a only.bed -b missed_exons.bed -u |
            awk -v OFS='\t' '{ print "exon_not_hit", $3 - $2 }'
        # the other segments, widened by 1 base on each side: alignments of $2 they touch
        bt intersect -a only.bed -b missed_exons.bed -v |
            awk -v OFS='\t' '{ s = $2 - 1; if (s < 0) s = 0; print $1, s, $3 + 1, $3 - $2 }' |
            bt intersect -a stdin -b "$2" -c |
            awk -v OFS='\t' '{ c = ($5 == 0) ? "apart" : ($5 == 1) ? "next_to_1_end" : "between_2"
                               print c, $4 }'
    } | awk -v OFS='\t' '
        { b = ($2 <= 10) ? "1-10" : ($2 <= 20) ? "11-20" : ($2 <= 50) ? "21-50" : ($2 <= 100) ? "51-100" : ">100"
          n[$1 OFS b]++; bp[$1 OFS b] += $2; tn[$1]++; tbp[$1] += $2; all += $2 }
        END { for (k in n) print k, n[k], bp[k]
              for (c in tn) print c, "all", tn[c], tbp[c]
              print "total", "all", "", all + 0 }' |
        LC_ALL=C sort -t$'\t' -k1,1 -k2,2V
}

# Alignment ends inside coding exons: the base just beyond the end is coding.
ends_in_cds() {
    awk -v OFS='\t' '{ if ($2 > 0) print $1, $2 - 1, $2; print $1, $3, $3 + 1 }' "$1" |
        bt intersect -a stdin -b E.bed -u | wc -l
}

echo "analysis: $A"
echo "exons: $EXONS; KegAlign: $REF; LAST: $LAST_BEDS"
echo "bedtools image: $SIF"
echo
printf 'alignment\tcds_bp_covered\tends_inside_cds\n'
printf '%s\t%s\t%s\n' "$REF" "$(bt intersect -a E.bed -b K.bed | sum_bp)" "$(ends_in_cds K.bed)"
for r in $LAST_BEDS; do
    printf '%s\t%s\t%s\n' "$r" "$(bt intersect -a E.bed -b "$r.bed" | sum_bp)" "$(ends_in_cds "$r.bed")"
done
printf 'coding exons\t%s\t(%s exons)\n' "$(sum_bp < E.bed)" "$(wc -l < E.bed)"

for r in $LAST_BEDS; do
    echo
    echo "### Coding bases covered by KegAlign and not by $r"
    printf 'class\tlength\tsegments\tbases\n'
    classify K.bed "$r.bed"
    echo
    echo "### Coding bases covered by $r and not by KegAlign"
    printf 'class\tlength\tsegments\tbases\n'
    classify "$r.bed" K.bed
done
