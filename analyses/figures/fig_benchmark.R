#===============================================================================
# Figures 5 and 6: cost and coverage of nf-core/pairgenomealign against the
# aligners benchmarked by Myers et al. (2026) and Gulhan et al. (2025); 8 pt.
#   benchmark.pdf (Figure 5, 160 x 92 mm): A, B: CPU time, memory and genome
#         coverage of the alignment of five genomes to the human CHM13 genome
#         (pipeline 3.0.2, median of replicates) and the values of Myers et al.
#         Table S2.
#   exons.pdf (Figure 6, 160 x 62 mm): A, B: human coding bases and exons
#         covered by alignments of the mouse genome.
# Inputs: myers_dir (execution traces, MultiQC tables and coverage.tsv of the
# 3.0.2 runs) and exon_table (coverage table written by bin/06_coverage.sh).
# Code of the section of Figure 5 in Benchmark.Rmd (Charles Plessy), with the input
# paths as parameters, the exon values read from exon_table instead of typed in,
# 8 pt instead of 7 (lines 0.6 mm, points 1.8), legends limited to the sources
# shown, and its panel C drawn as a separate figure of two dot charts (bases,
# exons) instead of one chart with two axes.  Run from the repository root.
#===============================================================================
library("tidyverse")
library("patchwork")
library("ggrepel")

#===============================================================================
# Input files
#===============================================================================

if (!exists("myers_dir"))  myers_dir  <- "analyses/myers"
if (!exists("exon_table")) exon_table <- "analyses/exons/tables/coverage_genome.tsv"
benchResults    <- myers_dir
trace_files     <- list.files(benchResults, recursive = TRUE, full.names = TRUE) |>
                     grep(pat = "/3.0.2_.*/execution_trace", value=TRUE) |>
                     grep(pat = "_m2m/", value=TRUE, invert=TRUE)

alignment_files <- list.files(benchResults, recursive = TRUE, full.names = TRUE, pattern = "multiqc_last_o2o.tx") |>
                     grep(pat = "/3.0.2", value=TRUE) |>
                     grep(pat = "work/", value=TRUE, invert=TRUE) |>
                     grep(pat = "_m2m/", value=TRUE, invert=TRUE)

species_order <- c(
  "GRCh38",
  "chimpanzee",
  "siamang",
  "pig",
  "mouse"
)

species_distance <- c(
  GRCh38     = 0,
  chimpanzee = 6.4,
  siamang    = 19.5,
  pig        = 94,
  mouse      = 87
)

#===============================================================================
# Helpers
#===============================================================================

parse_elapsed <- function(x) {
  map_dbl(x, function(xx) {

    hour <- str_match(xx, "(\\d+)h")[,2] |> as.numeric()
    mins <- str_match(xx, "(\\d+)m")[,2] |> as.numeric()
    secs <- str_match(xx, "(\\d+)s")[,2] |> as.numeric()

    hour <- replace_na(hour, 0)
    mins <- replace_na(mins, 0)
    secs <- replace_na(secs, 0)

    hour * 3600 + mins * 60 + secs
  })
}

parse_gb <- function(x) {

  value <- as.numeric(str_extract(x, "[0-9.]+"))

  case_when(
    str_detect(x, "KB") ~ value / 1024^2,
    str_detect(x, "MB") ~ value / 1024,
    str_detect(x, "GB") ~ value,
    TRUE ~ NA_real_
  )
}

#===============================================================================
# Load pairgenomealign benchmark
#===============================================================================

bench <- map_dfr(trace_files, function(file) {

  run_name <- basename(dirname(dirname(file)))

  meta <- str_match(
    run_name,
    "^(.*?)_(.*?)_rep(\\d+)(_cascade)?$"
  )

  read_tsv(file, show_col_types = FALSE) %>%
    mutate(
      process = case_when(
        str_detect(name, "LASTDB") ~ "LASTDB",
        str_detect(name, "TRAIN")  ~ "TRAIN",
        str_detect(name, "LASTAL") ~ "LASTAL",
        str_detect(name, "SPLIT") ~ "SPLIT",
        TRUE                       ~ NA_character_
      )
    ) %>%
    filter(!is.na(process)) %>%
    extract(
      name,
      into = c("target", "query"),
      regex = "\\(([^_]+)___([^\\)]+)\\)",
      remove = FALSE
    ) %>%
    mutate(
      version     = meta[,2],
      seed        = meta[,3],
      replicate   = as.integer(meta[,4]),
      cascade     = !is.na(meta[,5]),
      realtime_s  = parse_elapsed(realtime),
      cpu_percent = as.numeric(str_remove(`%cpu`, "%")),
      peak_rss_gb = parse_gb(peak_rss),
      cpu_min     = realtime_s * cpu_percent / 100 / 60,
      cpu = if_else(cascade, "Intel", "AMD")
    )
})

#===============================================================================
# Load nf-core/pairgenomealign alignment statistics
#===============================================================================

alignments <- map_dfr(alignment_files, function(file) {

  run_name <- basename(dirname(dirname(dirname(file))))

  meta <- str_match(
    run_name,
    "^(.*?)_(.*?)_rep(\\d+)(_cascade)?$"
  )

  read_tsv(file, show_col_types = FALSE) %>%
    extract(
      Sample,
      into = c("target", "query"),
      regex = "([^_]+)___(.+)"
    ) %>%
    mutate(
      version             = meta[,2],
      seed                = meta[,3],
      replicate           = as.integer(meta[,4]),
      cascade             = !is.na(meta[,5]),
      coverage_mb         = TotalAlignmentLength / 1e6,
      coverage_pct        = 100 * TotalAlignmentLength / QueryLength,
      identity_pct        = PercentIdentity,
      identity_nogaps_pct = PercentIdentityNoGaps
    )
})

coverage <- read_tsv(
  file.path(benchResults, "coverage.tsv"),
  col_types = cols(
    coverage_bp = col_double()
  )
) %>%
  extract(
    run,
    into = c("version", "seed", "replicate", "cascade"),
    regex = "^(.*?)_(.*?)_rep(\\d+)(_cascade)?_work$"
  ) %>%
  extract(
    alignment,
    into = c("target", "query", "type"),
    regex = "(.*?)___(.*?)\\.(o2o|m2o)$"
  ) %>%
  mutate(
    replicate = as.integer(replicate),
    cascade   = !is.na(cascade)
  )

coverage_summary <- coverage %>%
  filter(type == "m2o") %>%
  group_by(
    seed,
    cascade,
    query
  ) %>%
  summarise(
    coverage_mb = mean(coverage_bp) / 1e6,
    .groups = "drop"
  ) %>%
  mutate(
    query = factor(query, levels = species_order)
  )

#===============================================================================
# Average replicates
#===============================================================================

lastdb <- bench %>%
  filter(process == "LASTDB") %>%
  group_by(seed, cascade, replicate) %>%
  summarise(
    lastdb_cpu_min = sum(cpu_min),
    lastdb_rss_gb  = max(peak_rss_gb),
    .groups = "drop"
  )

pair_costs <- bench %>%
  filter(process %in% c("TRAIN", "LASTAL")) %>%
  group_by(
    seed,
    cascade,
    replicate,
    query
  ) %>%
  summarise(
    pair_cpu_min = sum(cpu_min),
    pair_rss_gb  = max(peak_rss_gb),
    .groups = "drop"
  )

bench_summary <- pair_costs %>%
  left_join(
    lastdb,
    by = c(
      "seed",
      "cascade",
      "replicate"
    )
  ) %>%
  mutate(
    cpu_min = pair_cpu_min + lastdb_cpu_min,
    rss_gb  = pmax(pair_rss_gb, lastdb_rss_gb)
  ) %>%
  group_by(
    seed,
    cascade,
    query
  ) %>%
  summarise(
    cpu_min = median(cpu_min),
    rss_gb  = median(rss_gb),
    .groups = "drop"
  ) %>%
  mutate(
    query = factor(query, levels = species_order)
  )

alignment_summary <- alignments %>%
  group_by(seed, cascade, query) %>%
  summarise(
    coverage_mb         = median(coverage_mb),
    coverage_pct        = median(coverage_pct),
    identity_pct        = median(identity_pct),
    identity_nogaps_pct = median(identity_nogaps_pct),
    .groups = "drop"
  ) %>%
  mutate(
    query = factor(query, levels = species_order)
  )

#===============================================================================
# Myers et al. Table S2
# Keep ALL metrics for future analyses
#===============================================================================

myers <- tribble(
~query,~method,~cpu_min,~rss_gb,~alignment_n,~alignment_mb,~coverage_mb,~coverage_pct,

"GRCh38","FastGA",70.53,11.26,579084,12445.52,3120.73,94.61,
"chimpanzee","FastGA",28.71,17.44,906660,5749.26,2937.73,92.47,
"siamang","FastGA",26.82,16.94,1134864,4325.27,2712.23,83.12,
"pig","FastGA",17.42,18.64,301464,457.69,438.70,16.80,
"mouse","FastGA",16.58,14.75,154873,124.58,107.35,3.93,

"GRCh38","FastGA-gapfill",310.20,11.26,1308426,15309.78,3138.09,95.14,
"chimpanzee","FastGA-gapfill",844.50,17.44,2868095,11709.89,2946.81,92.75,
"siamang","FastGA-gapfill",1962.50,16.94,6219092,13520.48,2747.24,84.19,
"pig","FastGA-gapfill",514.90,18.64,1341808,2130.13,1454.24,55.68,
"mouse","FastGA-gapfill",286.60,14.75,800965,1034.53,727.74,26.65,

"GRCh38","Minimap2",2082.02,177.27,3401,3212.41,3134.28,95.02,
"chimpanzee","Minimap2",2138.72,159.84,13271,3103.55,3026.02,95.25,
"siamang","Minimap2",2746.12,161.97,49486,3363.72,3210.92,98.40,
"pig","Minimap2",625.24,80.70,393480,805.14,795.91,30.47,
"mouse","Minimap2",590.14,89.81,213255,197.53,190.38,6.97,

"GRCh38","LastZ",42660.20,2.07,5628168,10583.49,3067.78,93.01,
"chimpanzee","LastZ",42139.60,2.10,10823773,14884.55,2881.83,90.71,
"siamang","LastZ",37854.90,1.76,9720554,11433.72,2743.54,84.08,
"pig","LastZ",31485.60,1.84,1571272,2190.04,1491.74,57.11,
"mouse","LastZ",34102.20,1.74,2610680,2308.87,764.49,27.99,

"GRCh38","Wfmash",1348.15,83.92,61711,3124.43,3114.05,94.41,
"chimpanzee","Wfmash",2507.33,88.99,58604,2993.53,2979.97,93.80,
"siamang","Wfmash",6023.16,105.26,58753,3036.73,3017.52,92.48,
"pig","Wfmash",10280.70,92.82,99549,1998.13,1988.53,76.13,
"mouse","Wfmash",7633.71,95.74,62094,1019.16,1011.08,37.02,

"GRCh38","NUCmer",21143.30,4.73,70340384,94640.13,3135.21,95.05,
"chimpanzee","NUCmer",19918.20,4.55,66222579,89458.83,2992.04,94.18,
"siamang","NUCmer",22614.40,4.25,77616820,95675.27,2840.65,87.06,
"pig","NUCmer",1624.85,3.85,1539871,322.46,137.00,5.24,
"mouse","NUCmer",1733.39,3.62,6200138,739.90,65.59,2.40
) %>%
  mutate(
    query = factor(query, levels = species_order)
  )
#===============================================================================
# Plotting dataset
#===============================================================================

ours <- bench_summary %>%
  left_join(
    alignment_summary,
    by = c("seed", "cascade", "query")
  ) %>%
  left_join(
    coverage_summary,
    by = c("seed", "cascade", "query"),
    suffix = c("_o2o", "")
  ) %>%
  filter(
    cascade,                  # Intel comparison
    seed != "NEAR"            # Results very similar to YASS, which is shown instead
  ) %>%  mutate(
    method = paste0("pairgenomealign-", seed),
    source = "pairgenomealign"
  ) %>%
  select(
    method,
    query,
    cpu_min,
    rss_gb,
    coverage_mb,              # now m2o
    coverage_pct,
    identity_pct,
    identity_nogaps_pct,
    source
  )

gene <- myers %>%
  mutate(
    identity_pct = NA_real_,
    identity_nogaps_pct = NA_real_,
    source = "Myers2026"
  ) %>%
  select(
    method,
    query,
    cpu_min,
    rss_gb,
    coverage_mb,
    coverage_pct,
    identity_pct,
    identity_nogaps_pct,
    source
  )

comparison <- bind_rows(ours, gene) %>%
  mutate(
    distance_mya = unname(species_distance[as.character(query)])
  ) %>%
  arrange(method, query)

#===============================================================================
# Figure 5 at print size: paste after `comparison` has been built.
# Width 160 mm = \textwidth of the manuscript (A4, 72 pt margins, 453 pt text);
# include with \includegraphics[width=\textwidth]{benchmark.pdf} (no rescaling).
#===============================================================================

fs <- 8              # the only font size, in pt (titles in bold)
ts <- fs / .pt       # the same size for geom_text(), which takes mm
lw <- 0.6            # data lines
ps <- 1.8            # data points

source_levels  <- c("pairgenomealign", "Myers2026", "Gulhan2025")
source_colours <- c(pairgenomealign = "#005A9C", Myers2026 = "#C77A00", Gulhan2025 = "#C77A00")
source_shapes  <- c(pairgenomealign = 16,        Myers2026 = 15,       Gulhan2025 = 17)
legend_labels  <- c(pairgenomealign = "pairgenomealign", Myers2026 = "Myers et al. 2025", Gulhan2025 = "Gulhan et al. 2025")
scale_source <- function(limits = source_levels) list(   # limits: the sources in the legend
  scale_colour_manual(name = NULL, values = source_colours, limits = limits, labels = legend_labels),
  scale_shape_manual(name = NULL, values = source_shapes,  limits = limits, labels = legend_labels)
)
highlight <- "grey90"
# labels: darker ochre, 4.8:1 contrast on white instead of 3.4:1 (WCAG asks 4.5:1 for small text)
text_colour <- function(col) ifelse(col == "#C77A00", "#A36300", col)
aspB <- 1.1; aspC <- 1.25   # panel height / width; panel A is square

theme_fig <- theme_bw(base_size = fs) +
  theme(text          = element_text(size = fs),
        axis.text     = element_text(size = fs),
        axis.title    = element_text(size = fs),
        plot.title    = element_text(size = fs, face = "bold"),
        plot.subtitle = element_text(size = fs),
        legend.text   = element_text(size = fs),
        plot.title.position = "plot")

comparison <- comparison %>%
  mutate(source = factor(as.character(source), levels = source_levels),
         label  = sub("^pairgenomealign-", "", method))

#--- Panel A: computational cost ----------------------------------------------

comparisonA <- comparison %>%
  arrange(method, desc(query))   # each path runs mouse -> pig -> siamang -> chimp -> human

# Method names: anchored to one point of each path, shifted by dx, dy (in decades).
labA <- tribble(
  ~method,                 ~query,       ~hjust, ~vjust,  ~dx,   ~dy,
  "pairgenomealign-YASS",  "GRCh38",      1,      0.5,   -0.09,  0,
  "pairgenomealign-RY4",   "GRCh38",      1,      0.5,   -0.09,  0,
  "pairgenomealign-RY128", "GRCh38",      1,      0.5,   -0.09,  0,
  "FastGA",                "pig",         0.5,    0,      0,     0.05,
  "FastGA-gapfill",        "siamang",     0.5,    0,      0,     0.1,
  "Minimap2",              "siamang",     0,      0.5,    0.07,  0,
  "Wfmash",                "pig",         0.5,    1,      0,    -0.05,
  "NUCmer",                "chimpanzee",  0.7,    0,      0,     0.09,
  "LastZ",                 "pig",         1,      0.5,   -0.13,  0
) %>%
  left_join(comparison, by = c("method", "query"))

kx <- 17 * 2.3^(0:4)   # key: positions of the five dots
ky <- 3.7              # key: height of the dots

panelA <- ggplot(comparisonA, aes(cpu_min, rss_gb, group = method, colour = source, shape = source)) +
  geom_point(data = filter(comparisonA, query == "mouse"),   # grey disc behind the mouse points
             colour = highlight, shape = 16, size = 3 * ps, show.legend = FALSE) +
  geom_path(linewidth = lw) +
  geom_point(size = ps) +
  geom_text(data = labA, aes(x = cpu_min * 10^dx, y = rss_gb * 10^dy, label = label,
                             hjust = hjust, vjust = vjust, colour = stage(source, after_scale = text_colour(colour))),
            size = ts, show.legend = FALSE) +
  scale_source() +
  scale_x_log10() +
  scale_y_log10(limits = c(1.1, NA)) +   # room for the key below the FastGA points
  annotate("rect", xmin = 7, xmax = 900, ymin = 1.18, ymax = 9.8,
           fill = "white", colour = "grey20", linewidth = 0.3) +
  annotate("text", x = 8.5, y = 9.2, label = "Genome aligned\nto human",
           hjust = 0, vjust = 1, fontface = "bold", size = ts, lineheight = 0.9) +
  annotate("point", x = kx[1], y = ky, size = 3 * ps, colour = highlight) +
  annotate("segment", x = kx[1], xend = kx[5], y = ky, yend = ky, colour = "black", linewidth = lw) +
  annotate("point", x = kx, y = rep(ky, 5), size = ps, colour = "black") +
  annotate("text", x = kx * 1.15, y = rep(ky * 0.87, 5),
           label = c("mouse", "pig", "siamang", "chimp", "human"),
           angle = 45, hjust = 1, vjust = 1, size = ts) +
  coord_cartesian(clip = "off") +   # same border width as in panels B and C
  labs(x = "CPU time (min)", y = "Peak RSS (GiB)", colour = NULL, shape = NULL,
       title = "A: Computational cost",
       subtitle = "Benchmark of Myers et al.") +
  theme_fig +
  theme(aspect.ratio = 1)

#--- Panel B: genome coverage -------------------------------------------------

species_pos <- c(GRCh38 = 0, chimpanzee = 0.5, siamang = 1, pig = 1.5, mouse = 2)
species_lab <- c("human", "chimp", "siamang", "pig", "mouse")
ymin_B <- 20   # lower limit of the log scale: leaves room for the genome names in the panel

comparison2 <- comparison %>%
  mutate(xpos = species_pos[as.character(query)])

panelB <- ggplot(comparison2, aes(xpos, coverage_mb, group = method, colour = source, shape = source)) +
  annotate("rect", xmin = 1.8, xmax = 2.2, ymin = 0, ymax = Inf, fill = highlight) +
  annotate("text", x = species_pos, y = ymin_B, label = species_lab,
           angle = 90, hjust = 0, size = ts, colour = "grey30") +
  geom_line(linewidth = lw) +
  geom_point(size = ps) +
  geom_text_repel(data = filter(comparison2, query == "mouse"),
                  aes(label = label, colour = stage(source, after_scale = text_colour(colour))),
                  direction = "y", nudge_x = 0.35, xlim = c(2.2, NA), hjust = 0, min.segment.length = 0,
                  box.padding = 0.15, point.padding = 0.1, force = 2, seed = 1,
                  size = ts, segment.size = 0.3, show.legend = FALSE) +
  scale_source(c("pairgenomealign", "Myers2026")) +
  scale_x_continuous(breaks = species_pos, labels = species_lab,   # 3.9: room for "FastGA-gapfill",
                     limits = c(-0.15, 3.9), expand = c(0, 0)) +       # whose hyphen R's pdf() draws as a wider minus
  scale_y_log10(limits = c(ymin_B, NA), breaks = c(100, 300, 1000, 3000)) +
  coord_cartesian(clip = "off") +
  labs(x = "Genome aligned to human", y = "Query genome covered (Mb)", colour = NULL, shape = NULL,
       title = "B: Coverage of the query genome",
       subtitle = "Benchmark of Myers et al.") +
  theme_fig +
  theme(aspect.ratio = aspB,
        panel.grid.major.x = element_blank(),
        panel.grid.minor   = element_blank(),    # would cross the genome names
        axis.text.x = element_text(colour = NA)) # invisible, but keeps the height of the
                                                 # tick labels of A and C, so the x titles align

#--- Panel C: human coding sequence covered by mouse alignments ---------------
# Exon coverage benchmark (Gulhan et al. 2025, Fig. 1B), human (hg38) coding
# sequence covered by alignments of the mouse genome (mm39).
# Exon set: 213,124 merged coding exons (36,043,292 bp) from the Galaxy history
# of Gulhan et al.; coverage from alignment spans, computed by bin/06_coverage.sh
# (analysis/merged_with_yass/tables/coverage_genome.tsv, rows with exons =
# other.gulhan2025_knownGene).
# pairgenomealign: many-to-many alignments, nf-core/pairgenomealign 3.0.4.
# minimap2 is not shown: Gulhan et al. ran it with -x asm20.
# NEAR (exons_hit 187671, cds_bp_covered 32532611) is not shown: YASS is shown
# instead, as in panels A and B.

exon_rows <- c("KegAlign\n(LastZ)"     = "other.gulhan2025_galaxy_lastz",
               "FastGA"                 = "other.gulhan2025_galaxy_fastga",
               "pairgenomealign-RY128"  = "ry128.m2m",
               "pairgenomealign-RY4"    = "ry4.m2m",
               "pairgenomealign-YASS"   = "yass.m2m",
               "pairgenomealign-MAM8"   = "mam8.m2m")
exon <- read_tsv(exon_table, show_col_types = FALSE) %>%
  filter(exons == "other.gulhan2025_knownGene", alignment %in% exon_rows) %>%
  transmute(method          = names(exon_rows)[match(alignment, exon_rows)],
            source          = if_else(startsWith(method, "pairgenomealign"), "pairgenomealign", "Gulhan2025"),
            exons_hit, cds_bp_covered) %>%
  arrange(match(method, names(exon_rows))) %>%
  mutate(source = factor(source, levels = source_levels),
         label  = sub("^pairgenomealign-", "", method),
         bases  = cds_bp_covered / 36043292,
         exons  = exons_hit / 213124)

# Two dot charts with the same rows, most covered on top: (A) coding bases
# covered, (B) coding exons overlapped by at least one aligned base.  Dotted
# lines: complete coverage.  Row labels coloured by source, as the data labels
# of Figure 5.
exon <- exon %>%
  mutate(label = sub("\n", " ", label),
         row   = factor(label, levels = label[order(cds_bp_covered)]),
         mb    = cds_bp_covered / 1e6,
         k     = exons_hit / 1e3)
row_colours <- text_colour(source_colours[as.character(exon$source[match(levels(exon$row), exon$label)])])

exon_panel <- function(var, total, breaks, total_label, title, xlab)
  ggplot(exon, aes(.data[[var]], row, colour = source, shape = source)) +
    annotate("segment", x = total, xend = total, y = -Inf, yend = Inf,
             linetype = "dotted", colour = "grey30", linewidth = 0.4) +
    geom_point(size = ps) +
    scale_source(c("pairgenomealign", "Gulhan2025")) +
    scale_x_continuous(limits = c(0, total), breaks = c(breaks, total), labels = c(breaks, total_label),
                       expand = expansion(mult = c(0.03, 0.03))) +
    labs(x = xlab, y = NULL, colour = NULL, shape = NULL, title = title,
         subtitle = "Benchmark of Gulhan et al.") +
    theme_fig +
    theme(panel.grid.minor = element_blank(),
          axis.text.y = element_text(colour = row_colours))

panelExonA <- exon_panel("mb", 36.043292, c(0, 10, 20, 30), "36.0",
                         "A: Coding bases covered", "Human coding bases covered (Mb)")
panelExonB <- exon_panel("k", 213.124, c(0, 50, 100, 150), "213",
                         "B: Coding exons overlapped", "Human coding exons overlapped (thousands)") +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank())

#--- Assembly -----------------------------------------------------------------

key_colour <- guide_legend(nrow = 1, override.aes = list(linetype = 0, size = 2))
key_shape  <- guide_legend(nrow = 1)

legend_theme <- theme(legend.position = "bottom",
                      legend.text = element_text(size = fs, margin = margin(r = 12)),
                      legend.margin = margin(0, 0, 0, 0),
                      legend.box.spacing = unit(fs, "pt"),
                      plot.margin = margin(2, 2, 2, 2))

fig <- (panelA + guides(colour = "none", shape = "none")) |
       (panelB + guides(colour = key_colour, shape = key_shape))
fig <- fig + plot_layout(guides = "collect") & legend_theme
ggsave("benchmark.pdf", fig, width = 160, height = 92, units = "mm")

fig_exons <- (panelExonA | panelExonB) + plot_layout(guides = "collect") &
  guides(colour = key_colour, shape = key_shape) & legend_theme
ggsave("exons.pdf", fig_exons, width = 160, height = 62, units = "mm")
