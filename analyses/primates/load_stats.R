#===============================================================================
# Statistics of the primate all-versus-all alignment (release 3.0.4, November
# 2026) loaded as in dataLoadTemplate.Rmd of the Scrambling in the Tree of Life
# project (Charles Plessy), and saved in primates.benchmark.RData for
# primates.Rmd.  Run from this directory.
# Inputs: genomicbreaks_yaml.tar.gz (one YAML file per ordered pair, written by
# oist/plessy_nf_GenomicBreaks 0.24.0.2) and pairgenomealign_benchmark_304.tsv
# (metadata of the 35 genomes).  Differences from the template: the YAML files
# are read from the archive, the summary plots are left out, the random seed is
# set, for the bootstrap values of the trees, and the assembly traits are not
# added to the trees, as makeTraitTibble() is not in the master branch of
# ScrambledTreeBuilder (commit 2bb4ab3) and primates.Rmd does not use them.
# Outputs: primates.benchmark.RData, and genomes.tsv, distances.tsv (symmetrised
# percent_difference_global) and pair_statistics.tsv.gz (the results table).
#===============================================================================
library("ScrambledTreeBuilder") |> suppressPackageStartupMessages()
set.seed(1664)

yaml_dir <- file.path(tempdir(), "genomicbreaks")
dir.create(yaml_dir, showWarnings = FALSE)
untar("genomicbreaks_yaml.tar.gz", exdir = yaml_dir)

resultFiles <- resultFiles(yaml_dir)
results <- formatStats(resultFiles)
results$index_avg_strandDiscord_5 <- 1 - results$index_strandRand_target_5

taxons <- read.csv("pairgenomealign_benchmark_304.tsv", sep = "\t", header = TRUE)
rownames(taxons) <- taxons$id

matrices <- S4Vectors::SimpleList()
safeSum <- \(x) {if (!is.numeric(x)) return (NA) else return (sum(x, na.rm=TRUE))}
matrices$percent_identity_global        <- makeMatrix(results, "percent_identity_global", 100, NA)
matrices$percent_identity_local         <- makeMatrix(results, "percent_identity_local",  100, NA)
matrices$percent_difference_global      <- makeMatrix(results, "percent_difference_global", 0, impute = "missForest2")
matrices$percent_difference_local       <- makeMatrix(results, "percent_difference_local",  0, impute = "missForest2")
matrices$index_avg_strandRand           <- makeMatrix(results, "index_avg_strandRand",      1, NA)
matrices$index_avg_strandDiscord        <- makeMatrix(results, "index_avg_strandDiscord",   0, NA)
matrices$index_avg_synteny              <- makeMatrix(results, "index_avg_synteny",         1, NA)
matrices$avg_chr_num                    <- makeMatrix(results, "avg_chr_num",              NA, NA)
matrices$collinear_width_target_Total   <- makeMatrix(results, "collinear_width_target_Total", NA, NA)
matrices$P                              <- makeMatrix(results, "P",                         0, impute = "missForest2")
matrices$JC69                           <- makeMatrix(results, "JC69",                      0, impute = "missForest2")
matrices$K80                            <- makeMatrix(results, "K80",                       0, impute = "missForest2")
matrices$K80_gap_distance               <- makeMatrix(results, "K80_gap_distance",          0, impute = "missForest2")
matrices$F81                            <- makeMatrix(results, "F81",                       0, impute = "missForest2")
matrices$HKY85                          <- makeMatrix(results, "HKY85",                     0, )
matrices$T92                            <- makeMatrix(results, "T92",                       0, impute = "missForest2")
matrices$TN93                           <- makeMatrix(results, "TN93",                      0, )
matrices$LogDet                         <- makeMatrix(results, "LogDet",                    0, impute = "missForest2")
matrices$percent_aligned                <- makeMatrix(results, "percent_aligned",         100, NA)
matrices$index_strandRand_target        <- makeMatrix(results, "index_strandRand_target",   1, NA)
matrices$index_strandRand_target_2      <- makeMatrix(results, "index_strandRand_target_2", 1, NA)
matrices$index_strandRand_target_5      <- makeMatrix(results, "index_strandRand_target_5" ,1, NA)
matrices$index_strandRand_target_10     <- makeMatrix(results, "index_strandRand_target_10",1, NA)

matrices$GCequi                         <- makeMatrix(results, "GCequi",1 , NA)
matrices$GCpres                         <- makeMatrix(results, "GCpres",1 , NA)
matrices$GCprop                         <- makeMatrix(results, "GCprop",1 , NA)

matrices$gapProp                        <- makeMatrix(results, "gapProp",0 , NA)
matrices$P_error                        <- makeMatrix(results, "P_error",0 , NA)

matrices$P_raw                          <- makeMatrix(results, "P",                         0, NA) # To visualise the extent of imputation


symmetrise <- function(m) {
  mt <- t(m)
  mt[is.na(mt)] <- m [is.na(mt)]
  m [is.na(m) ] <- mt[is.na(m) ]
  (m + mt) / 2
}
matrices_symmetric <- lapply( matrices, symmetrise) |> S4Vectors::SimpleList()

removeAssemblies_default <- \(x) if (file.exists("removedAssemblies.txt")) removeAssemblies(x, "removedAssemblies.txt") else x

toMakeManyTrees <- function(m)
  m |> removeAssemblies_default() |> thinByMin(0) |> makeTidyTree(n=1000) |>
    makeValueTibble(matrices$index_avg_strandRand,       colname = "Strand_Randomisation_Index") |>
    makeValueTibble(matrices$index_avg_strandDiscord,    colname = "Strand_Discordance_Index") |> # Alternatives suggested by ChatGPT: strand bias index, strand inversion scoreuncultured_Muribaculaceae_bacterium_GCA_965231035.1
    makeValueTibble(matrices$index_avg_strandDiscord,    colname = "Strand_Discordance_Index_median", fun=median) |>
    makeValueTibble(matrices$percent_identity_global,    colname = "Percent_Identity") |>
    makeValueTibble(matrices$percent_identity_local,     colname = "Percent_Identity_local") |>
    makeValueTibble(matrices$percent_difference_global,  colname = "Percent_Difference") |>
    makeValueTibble(matrices$percent_difference_local,   colname = "Percent_Difference_local") |>
    makeValueTibble(matrices$index_avg_synteny,          colname = "Synteny_Index") |>
    makeValueTibble(matrices$gapProp,                    colname = "gapProp") |>
    makeValueTibble(matrices$GCequi,                     colname = "GCequi") |>
    makeValueTibble(matrices$GCpres,                     colname = "GCpres") |>
    makeValueTibble(matrices$GCpres,                     colname = "GCpres") |>
    makeValueTibble(matrices$P,                          colname = "P") |>
    makeValueTibble(matrices$P,                          colname = "P_median", fun=median) |>
    makeValueTibble(matrices$P_error,                    colname = "P_error") |>
    makeValueTibble(matrices$JC69,                       colname = "JC69") |>
    makeValueTibble(matrices$K80,                        colname = "K80") |>
    makeValueTibble(matrices$K80_gap_distance,           colname = "K80_gap_distance") |>
    makeValueTibble(matrices$F81,                        colname = "F81") |>
    makeValueTibble(matrices$HKY85,                      colname = "HKY85") |>
    makeValueTibble(matrices$T92,                        colname = "T92") |>
    makeValueTibble(matrices$TN93,                       colname = "TN93") |>
    makeValueTibble(matrices$LogDet,                     colname = "LogDet") |>
    makeValueTibble(matrices$index_strandRand_target,    colname = "index_strandRand_target")   |>
    makeValueTibble(matrices$index_strandRand_target_2,  colname = "index_strandRand_target_2") |>
    makeValueTibble(matrices$index_strandRand_target_5,  colname = "index_strandRand_target_5") |>
    makeValueTibble(1 - matrices$index_strandRand_target_5,  colname = "index_avg_strandDiscord_5") |>
    makeValueTibble(matrices$index_strandRand_target_10, colname = "index_strandRand_target_10")

trees <- lapply( matrices[names(matrices) %in% c("P", "JC69", "K80", "K80_gap_distance", "F81", "HKY85", "T92", "TN93", "LogDet", "percent_difference_local")], toMakeManyTrees) |> S4Vectors::SimpleList()
Tibble <- trees$P

# Record node of origin in the results table
results$MRCA <- NULL
results <- recordAncestor(results, Tibble)

rm(yaml_dir)
save.image("primates.benchmark.RData")

# Tables for readers without R: genomes, distance matrix, statistics of each ordered pair
write.table(data.frame(genome_id = taxons$id, accession = taxons$AccNum, taxid = taxons$TaxID, url = taxons$file),
            "genomes.tsv", sep = "\t", quote = FALSE, row.names = FALSE)
d <- matrices_symmetric$percent_difference_global
write.table(data.frame(genome_id = rownames(d), d, check.names = FALSE),
            "distances.tsv", sep = "\t", quote = FALSE, row.names = FALSE)
pairs <- data.frame(pair = rownames(results), results[names(results) != "lab"], check.names = FALSE)   # lab: plot label with a line break
write.table(pairs, gzfile("pair_statistics.tsv.gz"), sep = "\t", quote = FALSE, row.names = FALSE)
