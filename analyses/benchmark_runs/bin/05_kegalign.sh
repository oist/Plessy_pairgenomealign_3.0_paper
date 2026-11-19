#!/bin/bash
# Fetch, from usegalaxy.org, the per-chromosome table plotted in Fig. 1B of
# Gulhan et al. (2025) and the listing of the Galaxy history that holds it, into
# $BUCKET_DIR/kegalign. Small transfers (kilobytes), run on a login node.
#
# The dataset id comes from ipynb/cds_exon_coverage.ipynb in
# https://github.com/nekrut/lz-fg-mm. Table columns, as named in that notebook:
# chr, count (merged coding exons), fg (FastGA), lz (KegAlign/lastz),
# mm (minimap2), lt (LAST): numbers of exons overlapped by each aligner.
#
# Usage: bin/05_kegalign.sh
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../settings.sh"
check_settings
umask 002
D=$BUCKET_DIR/kegalign
mkdir -p "$D"
cd "$D"

G=https://usegalaxy.org/api
DS=f9cad7b01a472135f3a63ea273c03caa
curl -sSfL "$G/datasets/$DS/display?to_ext=bed" -o fig1b_per_chromosome.tsv
curl -sSfL "$G/datasets/$DS" -o fig1b_dataset.json
H=$(grep -o '"history_id": *"[0-9a-f]*"' fig1b_dataset.json | grep -o '[0-9a-f]\{16,\}')
curl -sSfL "$G/histories/$H/contents?v=dev&keys=hid,id,name,extension,file_size,deleted" \
    -o history_contents.json
date -u +%FT%TZ > download_date.txt

echo "Saved in $D:"
ls -l "$D"
cat <<EOF

Next, by hand: find in history_contents.json the coding-exon BED and the alignment
BEDs, then download each with
  curl -sSfL "$G/datasets/<id>/display?to_ext=<extension>" -o <file>
and read its metadata (misc_info names the UCSC table for Table Browser imports) with
  curl -sSfL "$G/datasets/<id>"
An alignment BED in $TARGET_NAME coordinates saved as $BUCKET_DIR/other_alignments/<name>.bed
is included by bin/06_coverage.sh.
EOF
