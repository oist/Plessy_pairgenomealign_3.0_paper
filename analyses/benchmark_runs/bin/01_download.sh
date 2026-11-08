#!/bin/bash
# Submit a datacp job that downloads the two genomes and the UCSC gene tables
# to $BUCKET_DIR/inputs. Run on a login node; the transfer itself runs on datacp.
set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../settings.sh"
check_settings
mkdir -p "$BASE/logs"

sbatch -p datacp -c 1 --mem=2G -t 0-02:00:00 -J pga_download \
    -o "$BASE/logs/01_download-%j.out" <<EOF
#!/bin/bash
set -euo pipefail
umask 002
D=$BUCKET_DIR/inputs
mkdir -p "\$D"
cd "\$D"
U=https://hgdownload.soe.ucsc.edu/goldenPath
for g in $TARGET_NAME $QUERY_NAME; do
    curl -sSfLO "\$U/\$g/bigZips/\$g.fa.gz"
    curl -sSfL "\$U/\$g/bigZips/md5sum.txt" | grep " \$g.fa.gz\\\$" | md5sum -c -
done
# genePred tables for the coding-exon reference; knownGene has no 'bin' column.
for t in knownGene ncbiRefSeq refGene; do
    curl -sSfLO "\$U/$TARGET_NAME/database/\$t.txt.gz"
done
md5sum ./*.gz > md5sum.local.txt
date -u +%FT%TZ > download_date.txt
EOF
