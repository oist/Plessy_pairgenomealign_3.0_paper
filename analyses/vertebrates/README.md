Vertebrate Genomes Project, phase 1
===================================

Query genomes of the alignment of the human genome to the vertebrate genomes
(combined CRAM file, Figure 3).

- `VGP.tsv`: the 581 primary assemblies of phase 1 of the Vertebrate Genomes
  Project, with their GenBank or RefSeq accession and NCBI download URL.  The list
  includes the human T2T-CHM13 assembly (GCA_009914755.4).
- `VGP_orig_bgzipped.csv`: the samplesheet given to the pipeline (paths on the
  OIST cluster).

Provenance
----------

Phase 1 assemblies are those listed in column 16 of `VGPPhase1-freeze-1.0.tsv`
(<https://github.com/VGP/vgp-phase1>).  The URLs of their NCBI genome files were
retrieved with the NCBI E-utilities:

```
awk -F'\t' '$16 != "" {print $16}' VGPPhase1-freeze-1.0.tsv | sed 1d > AccIDs.tsv
rm -f URLs.tsv
for GENID in $(cat AccIDs.tsv)
do
  esearch -db assembly -query $GENID |
    efetch -format docsum |
    xtract -pattern DocumentSummary -element FtpPath_GenBank |
    sed -e 's,ftp://,https://,' -e 's,$,/,' |
    tee -a URLs.tsv
done
printf "id\tfile\n" > VGP.tsv
for ID in $(cat AccIDs.tsv)
do
  printf "$ID\t"    >> VGP.tsv
  grep $ID URLs.tsv >> VGP.tsv
done
```

The genomes were downloaded from NCBI, rather than from the copies hosted at
UCSC, with the `oist/LuscombeU_stlpreprocess` pipeline version 4.3 (version 4.4
for the dog genome, which needed a fix).  They were aligned as distributed,
including their unplaced scaffolds.  14 of the 581 assemblies are not
chromosome-level; they were kept.
