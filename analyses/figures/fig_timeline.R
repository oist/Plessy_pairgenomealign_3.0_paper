#===============================================================================
# Figure: wall-clock time and peak memory of each stage of the pipeline, for the
# alignment of the five genomes of the benchmark of Myers et al. (2025) to the
# human CHM13 genome, on Intel Xeon nodes, with the RY128, RY4 and YASS seeds.
# 160 mm wide (full text width), 8 pt.
# Inputs, in myers_dir: the execution traces of the 3.0.2 runs (one directory per
# seed and replicate; "_cascade" marks the Intel nodes; the "_m2m" runs are left
# out).  Each stage is the median over replicates of its summed run time and of
# its peak memory.
# Code of the section of this figure in Benchmark.Rmd (Charles Plessy), with the
# trace directory as a parameter and the font size raised from 7 to 8 pt.
#===============================================================================
library(tidyverse)

# Set myers_dir before sourcing this file to read the traces from elsewhere.
if (!exists("myers_dir")) myers_dir <- "analyses/myers"   # run from the repository root

trace_files <- list.files(myers_dir, recursive = TRUE, full.names = TRUE) |>
                 grep(pat = "/3.0.2_.*/execution_trace", value = TRUE) |>
                 grep(pat = "_m2m/", value = TRUE, invert = TRUE)

species_order <- c("GRCh38", "chimpanzee", "siamang", "pig", "mouse")

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

index_summary <- bench %>%
    filter(process == "LASTDB") %>%
    mutate(
        cpu = if_else(cascade, "Intel", "AMD")
    ) %>%
    group_by(
        cpu,
        seed,
        replicate
    ) %>%
    summarise(
        wall_min = sum(realtime_s) / 60,
        rss_gb   = max(peak_rss_gb),
        .groups = "drop"
    ) %>%
    group_by(
        cpu,
        seed
    ) %>%
    summarise(
        wall_min = median(wall_min),
        rss_gb   = median(rss_gb),
        .groups = "drop"
    ) %>%
    tidyr::crossing(
        query = species_order
    ) %>%
    mutate(
        stage = "INDEX"
    )

# Pair-specific stages
pair_summary <- bench %>%
    filter(process %in% c("TRAIN", "LASTAL", "SPLIT")) %>%
    mutate(
        stage = recode(
            process,
            TRAIN  = "TRAIN",
            LASTAL = "ALIGN",
            SPLIT  = "SPLIT"
        ),
        cpu = if_else(cascade, "Intel", "AMD")
    ) %>%
    filter(!is.na(stage)) %>%
    group_by(
        cpu,
        seed,
        query,
        replicate,
        stage
    ) %>%
    summarise(
        wall_min = sum(realtime_s) / 60,
        rss_gb   = max(peak_rss_gb),
        .groups = "drop"
    ) %>%
    group_by(
        cpu,
        seed,
        query,
        stage
    ) %>%
    summarise(
        wall_min = median(wall_min),
        rss_gb   = median(rss_gb),
        .groups = "drop"
    )

# Combined workflow trajectory
workflow_plot <- bind_rows(
    index_summary,
    pair_summary
) %>%
    mutate(
        query = factor(query, levels = species_order),
        stage = factor(
            stage,
            levels = c(
                "INDEX",
                "TRAIN",
                "ALIGN",
                "SPLIT"
            )
        ),
        seed = factor(
            seed,
            levels = c(
                "RY128",
                "RY4",
                "NEAR",
                "YASS"
            )
        )
    ) %>%
    arrange(
        cpu,
        seed,
        query,
        stage
    ) %>%
    group_by(
        cpu,
        seed,
        query
    ) %>%
    mutate(
        cumulative_min = cumsum(wall_min),
        cumulative_rss = cummax(rss_gb)
    ) %>%
    ungroup()

stopifnot(
    !any(is.na(workflow_plot$query)),
    !any(is.na(workflow_plot$stage))
)



#===============================================================================
# Figure at print size.
# Width 160 mm = \textwidth; include with \includegraphics[width=\textwidth]{timeline.pdf}.
#===============================================================================

fs <- 8   # font size in pt

stage_colours <- c(INDEX = "#E69F00", TRAIN = "#CC79A7", ALIGN = "#0072B2", SPLIT = "#009E73")  # Okabe-Ito
query_labels4 <- c(GRCh38 = "human", chimpanzee = "chimp", siamang = "siamang", pig = "pig", mouse = "mouse")

theme_fig4 <- theme_bw(base_size = fs) +
  theme(text = element_text(size = fs), axis.text = element_text(size = fs),
        axis.title = element_text(size = fs), strip.text = element_text(size = fs),
        legend.text = element_text(size = fs),
        strip.background = element_blank(), panel.grid.minor = element_blank(),
        strip.text.y = element_text(angle = 0, hjust = 0),
        legend.position = "right", legend.key.size = unit(fs, "pt"),
        plot.margin = margin(2, 2, 2, 2))

# One row per run and stage; each stage spans [start_min, end_min].
stages4 <- workflow_plot %>%
  filter(cpu == "Intel", seed != "NEAR") %>%
  mutate(seed      = droplevels(seed),
         end_min   = cumulative_min,
         start_min = cumulative_min - wall_min)

run_end <- stages4 %>%
  group_by(seed, query) %>%
  summarise(end_min = max(end_min), .groups = "drop")

panel4 <- ggplot(stages4) +
  geom_vline(data = run_end, aes(xintercept = end_min),            # end of the run
             colour = "grey50", linetype = "22", linewidth = 0.3) +
  geom_rect(aes(xmin = start_min, xmax = end_min, ymin = 0, ymax = rss_gb, fill = stage)) +
  facet_grid(seed ~ query, labeller = labeller(query = query_labels4)) +
  scale_fill_manual(values = stage_colours, name = NULL) +
  scale_x_continuous(breaks = seq(0, 120, 30), expand = expansion(mult = c(0, 0.03))) +
  scale_y_continuous(breaks = c(0, 100, 200), labels = c("", "100", "200"),
                     expand = expansion(mult = c(0, 0.05))) +
  labs(x = "Wall-clock time since the start of indexing (min)", y = "Peak RSS (GiB)") +
  theme_fig4

ggsave("timeline.pdf", panel4, width = 160, height = 50, units = "mm")
