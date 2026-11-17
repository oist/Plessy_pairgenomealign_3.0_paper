Genomes of Figure 2
===================

The article describes the all-versus-all alignment of 33 primate
genomes.  The run used the 35 genomes of the pipeline's full-size test
(`run_2026-11/input.tsv`), which also includes two other mammals: the
Philippine colugo (*Cynocephalus volans*, GCA_027409185.1) and the house
mouse (*Mus musculus*, GCA_964188535.1).  The tables of this directory
cover all 35 genomes.  The CRAM-to-MAF size ratios given in the article
are those of the 33 primate targets; their CRAM and MAF files also
hold the alignments of the colugo and the mouse as queries.

Figure 2 leaves out the colugo, the mouse and the tarsier (*Carlito
syrichta*, GCA_059932695.1).  Average-linkage clustering (UPGMA) builds
ultrametric trees, which assume the same rate of change in all
lineages.  In these genomes the rate differs between lineages: the
mean difference to the Simiiformes is 29.2 % for the Lorisiformes and
24.8 % for the Lemuriformes.  With the tarsier, the tree places it
outside the other primates, so that the suborder Haplorrhini (tarsiers,
monkeys and apes) is not recovered; the other 22 NCBI taxa are
(`primates.Rmd`).
