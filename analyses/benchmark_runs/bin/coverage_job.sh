#!/bin/bash
# Batch job submitted by bin/06_coverage.sh; not for direct use. Arguments: run names.
#
# 1. Coding-exon BEDs (CDS parts of exons, merged) from the UCSC genePred tables,
#    as the Table Browser "coding exons" output, restricted to chr1-22, X, Y, M.
# 2. Merged alignment BEDs in target coordinates for each run and relation
#    (m2m, m2o, o2o), plus any BED in $BUCKET_DIR/other_alignments/.
#    Exon BEDs in $BUCKET_DIR/other_exons/ are used as additional exon sets.
# 3. Per chromosome and genome-wide: exons overlapped by >= 1 bp, and covered bp.
# Follows the read-Bucket / write-scratch / copy-back / clean-up pattern.
set -euo pipefail
umask 002
source "$PGA_BASE/settings.sh"

ml purge
ml bioinfo-ugrp-modules
ml Nextflow3                      # provides singularity
command -v singularity > /dev/null || { echo "singularity not found" >&2; exit 1; }

# Images, downloaded once to $BASE/containers.
mkdir -p "$BASE/containers"
BT_SIF=$BASE/containers/bedtools_2.31.1.sif
LA_SIF=$BASE/containers/last_1652.sif
fetch() { [ -s "$2" ] || { curl -sSfL -o "$2.part" "$1" && mv "$2.part" "$2"; }; }
fetch "$BEDTOOLS_SIF_URL" "$BT_SIF"
fetch "$LAST_SIF_URL" "$LA_SIF"
bedtools()    { singularity exec "$BT_SIF" bedtools "$@"; }
maf_convert() { singularity exec "$LA_SIF" maf-convert "$@"; }

# Per-job scratch directory on /flash, removed on exit; no use of /tmp.
T=$(mktemp -d "$(dirname "$WORK_ROOT")/pga_coverage.XXXXXX")
trap 'rm -rf "$T"' EXIT
export TMPDIR=$T/tmp
mkdir -p "$TMPDIR"
cd "$T"
mkdir exons alignments tables
srt() { LC_ALL=C sort -k1,1 -k2,2n -S 1G -T "$TMPDIR"; }

# 1. Coding exons. $2 = 1 for tables with a leading 'bin' column (ncbiRefSeq, refGene).
cds_bed() {
    zcat "$1" | awk -F'\t' -v OFS='\t' -v o="$2" '
        $(2+o) ~ /^chr([0-9]+|X|Y|M)$/ && $(6+o)+0 < $(7+o)+0 {
            cs = $(6+o)+0; ce = $(7+o)+0
            n = split($(9+o), s, ","); split($(10+o), e, ",")
            for (i = 1; i < n; i++) {
                a = s[i]+0; b = e[i]+0
                if (a < cs) a = cs
                if (b > ce) b = ce
                if (a < b) print $(2+o), a, b
            }
        }' | srt | bedtools merge -i stdin
}
IN=$BUCKET_DIR/inputs
for spec in knownGene:0 ncbiRefSeq:1 refGene:1; do
    t=${spec%%:*}
    if [ -s "$IN/$t.txt.gz" ]; then cds_bed "$IN/$t.txt.gz" "${spec##*:}" > "exons/$t.bed"; fi
done
# Exon BEDs supplied by hand (e.g. Gulhan et al.'s Table Browser export), same chromosomes.
for f in "$BUCKET_DIR"/other_exons/*.bed; do
    [ -s "$f" ] || continue
    awk -F'\t' -v OFS='\t' '$1 ~ /^chr([0-9]+|X|Y|M)$/ && $2 ~ /^[0-9]+$/ { print $1, $2, $3 }' "$f" |
        srt | bedtools merge -i stdin > "exons/other.$(basename "$f")"
done

# 2. Alignments. LAST tabular columns 2-6: target name, start, aligned length,
#    strand, sequence length. With lastdb -S2 the target can be on the minus
#    strand, whose coordinates are converted to the forward strand.
maf_to_bed() {
    maf_convert tab - |
        awk -F'\t' -v OFS='\t' '!/^#/ { s = $3; if ($5 == "-") s = $6 - $3 - $4; print $2, s, s + $4 }' |
        srt | bedtools merge -i stdin
}
pair=${TARGET_NAME}___${QUERY_NAME}
pids=()
for run in "$@"; do
    for rel in m2m m2o o2o; do
        maf=$BUCKET_DIR/runs/$run/alignment/$pair.$rel.maf.gz
        if [ -s "$maf" ]; then
            ( zcat "$maf" | maf_to_bed > "alignments/$run.$rel.bed" ) &
            pids+=($!)
        fi
    done
done
for p in ${pids[@]+"${pids[@]}"}; do wait "$p"; done
for f in "$BUCKET_DIR"/other_alignments/*.bed; do
    [ -s "$f" ] || continue
    awk -F'\t' -v OFS='\t' 'NF >= 3 && $2 ~ /^[0-9]+$/ { print $1, $2, $3 }' "$f" |
        srt | bedtools merge -i stdin > "alignments/other.$(basename "$f")"
done

# 3. Coverage.
{
    printf 'exons\talignment\tchrom\texons_total\texons_hit\tcds_bp\tcds_bp_covered\n'
    for e in exons/*.bed; do
        for a in alignments/*.bed; do
            bedtools coverage -a "$e" -b "$a" |
                awk -F'\t' -v OFS='\t' -v E="$(basename "$e" .bed)" -v A="$(basename "$a" .bed)" '
                    { n[$1]++; if ($(NF-2) > 0) h[$1]++; c[$1] += $(NF-2); l[$1] += $(NF-1) }
                    END { for (k in n) print E, A, k, n[k], h[k]+0, l[k], c[k] }' |
                LC_ALL=C sort -t$'\t' -k3,3V
        done
    done
} > tables/coverage_per_chromosome.tsv

awk -F'\t' -v OFS='\t' '
    NR == 1 { print "exons", "alignment", "exons_total", "exons_hit", "fraction_exons_hit",
                    "cds_bp", "cds_bp_covered", "fraction_bp_covered"; next }
    { k = $1 OFS $2; n[k] += $4; h[k] += $5; l[k] += $6; c[k] += $7 }
    END { for (k in n) printf "%s\t%d\t%d\t%.4f\t%d\t%d\t%.4f\n", k, n[k], h[k], h[k]/n[k], l[k], c[k], c[k]/l[k] }
' tables/coverage_per_chromosome.tsv | LC_ALL=C sort > tables/coverage_genome.tsv

# Gulhan et al.'s Fig. 1B table (bin/05_kegalign.sh), in the same long format.
K=$BUCKET_DIR/kegalign/fig1b_per_chromosome.tsv
if [ -s "$K" ]; then
    awk -F'\t' -v OFS='\t' '
        BEGIN { print "exons", "alignment", "chrom", "exons_total", "exons_hit"
                split("fastga kegalign_lastz minimap2 last", label, " ") }   # columns 3-6: fg lz mm lt
        { for (i = 1; i <= 4; i++) print "gulhan2025", label[i], $1, $2, $(i+2) }
    ' "$K" > tables/gulhan2025_fig1b_long.tsv
fi

{
    echo "date: $(date -u +%FT%TZ)"
    echo "slurm_job: ${SLURM_JOB_ID:-none}"
    echo "runs: $*"
    echo "bedtools image: $BEDTOOLS_SIF_URL"
    echo "LAST image: $LAST_SIF_URL"
    echo "inputs:"
    if [ -s "$IN/md5sum.local.txt" ]; then cat "$IN/md5sum.local.txt"; fi
    if [ -s "$IN/download_date.txt" ]; then echo "downloaded: $(cat "$IN/download_date.txt")"; fi
} > tables/provenance.txt

# Copy back to Bucket (read-only here, hence ssh/scp through the login node).
dest=$BUCKET_DIR/analysis/$(date +%Y%m%d-%H%M%S)_${SLURM_JOB_ID:-nojob}
ssh deigo "mkdir -p '$dest'"
scp -r -q exons alignments tables "deigo:$dest/"
ssh deigo "chmod -R g+rwX '$dest'"
echo "Results: $dest"
