#!/bin/bash
# Compare a coverage-job result with Gulhan et al.'s Fig. 1B table.
# Usage: bin/07_compare_gulhan.sh ANALYSIS_DIR
#   (ANALYSIS_DIR: $BUCKET_DIR/analysis/<date>_<jobid>)
# Small text files only: runs on a login node.
set -euo pipefail
A=${1:?usage: $0 ANALYSIS_DIR}
G=$A/tables/gulhan2025_fig1b_long.tsv
C=$A/tables/coverage_per_chromosome.tsv
X=other.gulhan2025_knownGene

echo "### 1. Their merged BEDs vs BEDs converted here from their raw outputs"
for t in lastz last fastga minimap2; do
    g=$A/alignments/other.gulhan2025_galaxy_$t.bed
    r=$A/alignments/other.gulhan2025_raw_$t.bed
    if cmp -s "$g" "$r"; then echo "$t: identical"
    else echo "$t: $(diff "$g" "$r" | grep -c '^[<>]') differing lines"; fi
done

echo
echo "### 2. Per chromosome, on their exon set ($X): their numbers vs ours"
echo "    count: their merged exons; ours: exons_total; then per aligner: theirs, ours from their BED, ours from raw"
summary=$(mktemp)
trap 'rm -f "$summary"' EXIT
awk -F'\t' -v OFS='\t' -v X="$X" -v S="$summary" '
    FNR == 1 { next }
    FILENAME == ARGV[1] {
        t = ($2 == "kegalign_lastz") ? "lastz" : $2
        if (!($3 in count)) order[++n] = $3
        their[$3, t] = $5; count[$3] = $4; next }
    $1 == X && $2 ~ /^other\.gulhan2025_(galaxy|raw)_/ {
        split($2, p, "_"); ours[$3, p[3], p[2]] = $5; total[$3] = $4 }
    END {
        split("lastz last fastga minimap2", tool, " ")
        printf "chrom\tcount\tours"
        for (j = 1; j <= 4; j++) printf "\t%s\t%s_gal\t%s_raw", tool[j], tool[j], tool[j]
        printf "\n"
        for (i = 1; i <= n; i++) {
            c = order[i]
            printf "%s\t%s\t%s", c, count[c], ((c in total) ? total[c] : "NA")
            sc += count[c]; st += total[c]; same_total += (count[c] == total[c])
            for (j = 1; j <= 4; j++) {
                t = tool[j]
                a = their[c, t]; b = ((c, t, "galaxy") in ours) ? ours[c, t, "galaxy"] : "NA"
                r = ((c, t, "raw") in ours) ? ours[c, t, "raw"] : "NA"
                printf "\t%s\t%s\t%s", a, b, r
                sa[t] += a; sb[t] += b; sr[t] += r; eq[t] += (a == b)
            }
            printf "\n"
        }
        printf "total\t%d\t%d", sc, st
        for (j = 1; j <= 4; j++) printf "\t%d\t%d\t%d", sa[tool[j]], sb[tool[j]], sr[tool[j]]
        printf "\n"
        printf "chromosomes: %d; exon count equal to theirs on %d\n", n, same_total > S
        for (j = 1; j <= 4; j++) printf "%s: exons_hit equal to theirs on %d chromosomes\n", tool[j], eq[tool[j]] > S
    }' "$G" "$C" | column -ts$'\t'
echo
cat "$summary"

echo
echo "### 3. Exon sets restricted to their chromosomes: merged coding exons, sum"
awk -F'\t' -v OFS='\t' '
    FNR == 1 { next }
    FILENAME == ARGV[1] { if ($2 == "last") { chr[$3]; c += $4 }; next }
    $2 == "other.gulhan2025_galaxy_last" && ($3 in chr) { s[$1] += $4 }
    END { print "theirs (count column)", c; for (e in s) print e, s[e] }' "$G" "$C" | column -ts$'\t'

echo
echo "### 4. Genome-wide, their exon set"
awk -F'\t' -v X="$X" 'NR == 1 || $1 == X' "$A/tables/coverage_genome.tsv" | column -ts$'\t'

echo
echo "### 5. Per chromosome, on their exon set: exons hit by the pipeline runs"
echo "    lz, lt: their published numbers (KegAlign/lastz, LAST); then one column per run.relation"
awk -F'\t' -v OFS='\t' -v X="$X" '
    FNR == 1 { next }
    FILENAME == ARGV[1] {
        if (!($3 in seen)) { seen[$3]; order[++n] = $3 }
        if ($2 == "kegalign_lastz") lz[$3] = $5
        if ($2 == "last") lt[$3] = $5
        next }
    $1 == X && $2 !~ /^other\./ {
        if (!($2 in isrun)) { isrun[$2]; runs[++m] = $2 }
        hit[$3, $2] = $5; tot[$3] = $4 }
    END {
        if (m == 0) { print "No pipeline run in this analysis: run bin/06_coverage.sh with run names."; exit }
        for (i = 1; i <= m; i++) for (j = i + 1; j <= m; j++)
            if (runs[j] < runs[i]) { t = runs[i]; runs[i] = runs[j]; runs[j] = t }
        printf "chrom\texons\tlz\tlt"
        for (j = 1; j <= m; j++) printf "\t%s", runs[j]
        printf "\n"
        for (i = 1; i <= n; i++) {
            c = order[i]
            printf "%s\t%s\t%s\t%s", c, tot[c], lz[c], lt[c]
            st += tot[c]; slz += lz[c]; slt += lt[c]
            for (j = 1; j <= m; j++) {
                v = ((c, runs[j]) in hit) ? hit[c, runs[j]] : "NA"
                printf "\t%s", v; s[j] += v
            }
            printf "\n"
        }
        printf "total\t%d\t%d\t%d", st, slz, slt
        for (j = 1; j <= m; j++) printf "\t%d", s[j]
        printf "\nfraction\t1\t%.4f\t%.4f", slz / st, slt / st
        for (j = 1; j <= m; j++) printf "\t%.4f", s[j] / st
        printf "\n"
    }' "$G" "$C" | column -ts$'\t'
