#===============================================================================
# Numbers for the Results paragraph on the simulated pairs, from the outputs of
# bin/09_simulated.sbatch in sim_dir: coverage.tsv, coverage.ends.tsv,
# identity.tsv and provenance.txt.
# d: distance from the homology boundary to the alignment end (bases; < 0: stops
# inside the homologous region).  Bias: identity of the alignments minus true
# identity (percentage points).  Identity bins are on the true identity.
# Runs inside local(): prints only, and leaves the objects of the R session
# untouched.
#===============================================================================
library(dplyr)

sim_dir <- "/bucket/LuscombeU/live/charles-plessy/pairalignbenchmark/pairgenomealign_simulated"

local({
  truth <- read.delim(file.path(sim_dir, "identity.tsv")) %>% distinct(pair, true_identity)
  stopifnot(nrow(truth) == 164, !anyDuplicated(truth$pair))
  cov  <- read.delim(file.path(sim_dir, "coverage.tsv"))      %>% left_join(truth, by = "pair")
  ends <- read.delim(file.path(sim_dir, "coverage.ends.tsv")) %>% left_join(truth, by = "pair")
  idt  <- read.delim(file.path(sim_dir, "identity.tsv"))      %>% mutate(bias = measured_identity - true_identity)

  ry4      <- "pairgenomealign-RY4"
  compared <- c("lastz", ry4, "LAST-RY4-xdrop1000", "LAST-RY4-lowtrain")
  bin      <- function(x) cut(x, c(0, 65, 70, 101), right = FALSE,
                              labels = c("below 65%", "65-70%", "70% and above"))

  cat("\nLAST version (container of pipeline 3.0.4):\n")
  cat(grep("^lastal", readLines(file.path(sim_dir, "provenance.txt")), value = TRUE), sep = "\n")

  cat("\nPairs found, and highest true identity of a pair not found:\n")
  cov %>%
    group_by(aligner) %>%
    summarise(found = sum(core_bp > 0),
              highest_missed = if (any(core_bp == 0)) max(true_identity[core_bp == 0]) else NA,
              .groups = "drop") %>%
    arrange(desc(found)) %>% as.data.frame() %>% print()

  cat("\nPairs not found by RY4:\n")
  cov %>% filter(aligner == ry4, core_bp == 0) %>% select(pair, length, true_identity) %>% print()

  # Same ends and same identity as RY4, on the pairs that both found.  Compares
  # the outer ends and the identity of the alignments, not every aligned base.
  cat("\nSame alignment ends and identity as RY4, on the pairs found by both:\n")
  for (tool in c("pairgenomealign-YASS", "pairgenomealign-MAM8", "LAST-RY4-xdrop1000")) {
    e <- inner_join(filter(ends, aligner == ry4), filter(ends, aligner == tool), by = c("pair", "end"))
    i <- inner_join(filter(idt,  aligner == ry4), filter(idt,  aligner == tool), by = "pair")
    cat(sprintf("  %-22s pairs %3d, same ends %3d/%d, same identity %3d/%d\n", tool, nrow(i),
                sum(e$distance.x == e$distance.y), nrow(e),
                sum(i$measured_identity.x == i$measured_identity.y), nrow(i)))
  }

  cat("\nd, median [quartiles] per bin of true identity:\n")
  ends %>%
    filter(aligner %in% compared) %>%
    group_by(aligner = factor(aligner, compared), bin = bin(true_identity)) %>%
    summarise(ends = n(),
              d = sprintf("%g [%g, %g]", median(distance), quantile(distance, 0.25), quantile(distance, 0.75)),
              .groups = "drop") %>% as.data.frame() %>% print()

  cat("\nIdentity bias, median per bin of true identity (percentage points):\n")
  idt %>%
    filter(aligner %in% compared) %>%
    group_by(aligner = factor(aligner, compared), bin = bin(true_identity)) %>%
    summarise(pairs = n(), bias = round(median(bias), 2), .groups = "drop") %>%
    as.data.frame() %>% print()

  # lastz versus LAST: extension and gaps, in finer bins of true identity
  extended <- c("lastz", ry4, "LAST-RY4-lowtrain")
  bin5     <- function(x) cut(x, c(0, 65, 70, 80, 90, 101), right = FALSE,
                              labels = c("below 65%", "65-70%", "70-80%", "80-90%", "90% and above"))

  cat("\nPairs found: homologous region covered (median %), random flank aligned",
      "(mean bases per pair), ends beyond the boundary (% of ends, and their mean d):\n")
  inner_join(
    cov %>%
      filter(aligner %in% extended, core_bp > 0) %>%
      group_by(aligner = factor(aligner, extended), bin = bin5(true_identity)) %>%
      summarise(pairs = n(), covered = round(100 * median(core_fraction), 1),
                flank_bp = round(mean(flank_bp), 1), .groups = "drop"),
    ends %>%
      filter(aligner %in% extended) %>%
      group_by(aligner = factor(aligner, extended), bin = bin5(true_identity)) %>%
      summarise(ends_beyond = round(100 * mean(distance > 0)),
                mean_d_beyond = round(mean(distance[distance > 0]), 1), .groups = "drop"),
    by = c("aligner", "bin")) %>%
    as.data.frame() %>% print()

  # The simulation inserts bases in the ORANGE only: a gap in the APPLE row
  # faces an insertion, a gap in the ORANGE row has no counterpart in the truth.
  # Truth columns: per 1000 bases of homologous region (APPLE).
  cat("\nPer 1000 aligned pairs: gap columns in the APPLE row (truth: inserted bases),",
      "in the ORANGE row (truth: 0), and mismatches (truth: substitutions):\n")
  idt %>%
    filter(aligner %in% extended) %>%
    group_by(aligner = factor(aligner, extended), bin = bin5(true_identity)) %>%
    summarise(inserted_truth  = round(1000 * sum(true_inserted) / sum(length), 1),
              gaps_apple_row  = round(1000 * sum(gap_cols_apple) / sum(aligned_pairs), 1),
              gaps_orange_row = round(1000 * sum(gap_cols_orange) / sum(aligned_pairs), 1),
              mismatch_truth  = round(1000 * sum(true_substitutions) / sum(length), 1),
              mismatches      = round(1000 * sum(aligned_pairs - matches) / sum(aligned_pairs), 1),
              .groups = "drop") %>%
    as.data.frame() %>% print()
})
