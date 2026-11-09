Vertebrate Genomes Project, phase 1
===================================

Query genomes of the alignment of the human genome to the vertebrate genomes
(combined CRAM file, Figure 3).

- `VGP.tsv`: the 581 primary assemblies of phase 1 of the Vertebrate Genomes
  Project, with their GenBank or RefSeq accession and NCBI download URL.  The list
  includes the human T2T-CHM13 assembly (GCA_009914755.4).
- `VGP_orig_bgzipped.csv`: the 581 assemblies with their paths on the OIST
  cluster.  The run used the same list without the target (580 queries).
- `run/`: parameters, execution trace, software versions and MultiQC report and
  tables of the run.

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

Lineages
--------

According to `VGPPhase1-freeze-1.0.tsv` (column "Lineage"), the 580 queries are 178
fishes, 165 mammals, 137 birds, 55 reptiles, 32 amphibians and 13 invertebrate
deuterostomes: three lancelets (*Branchiostoma*), eight tunicates, one sea star
(*Asterias rubens*) and one acorn worm (*Balanoglossus misakiensis*).  One bird
assembly (GCA_036971685.2, bPatFas1) is matched by its ToLID, because its accession
differs in the current version of that table.

Run
---

nf-core/pairgenomealign 3.0.4 on the OIST HPC cluster, target T2T-CHM13
(GCA_009914755.4), seed RY4, `--multi_cram`, `--softmask tantan`,
`--export_aln_to tab,blasttab+` (`run/params_2026-09-11_09-44-35.json`).

The run was started on 10 September 2026 and resumed on 11 September; the trace
of the second run lists the tasks of the first one as `CACHED`, with their
original times.  Indexing, training, alignment and one-to-one reduction ran from
13:02 to 18:16 on 10 September; the second run (2 h 46 min) made the remaining
CRAM files, exports and dot plots, and merged the CRAM files (2 h for the
merge).  Indexing, training, alignment and one-to-one reduction used 423 CPU-hours, and
all tasks 474 CPU-hours.

The dot plots of six pairs with an invertebrate query failed (`FAILED` in the
trace); the pipeline ignores this error.
