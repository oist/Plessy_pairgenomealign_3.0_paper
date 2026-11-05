#===============================================================================
# Figure: alignments of the simulated sequence pairs of Gulhan et al. (2025),
# 160 mm wide (full text width), 8 pt.
#   A (first row): what is measured
#   B (second row, 1 x 4): position of alignment ends; lastz, RY4, FastGA, RY128;
#     ticks on the lower edge mark the pairs not found
#   C (third row, under the lastz and RY4 panels of B): identity of the
#     alignments minus true identity; legends on its right
# All data panels have the same size, because they share the x axis (true
# identity of the pair).
# Inputs, in sim_dir: coverage.tsv, coverage.ends.tsv and identity.tsv, written
# by analyses/benchmark_runs/bin/09_simulated.sbatch.
# Left out: YASS and MAM8 (their alignments are nearly those of RY4); minimap2
# (the published PAF file has no base-level alignment, so its coordinates are
# the ends of seed chains, not of alignments).
# Everything is computed inside local(), so that the objects of other figures in
# the same R session are left untouched; only fig_simulated is created.
#===============================================================================
library(dplyr); library(ggplot2); library(patchwork)

# Set sim_dir before sourcing this file to read the tables from elsewhere.
if (!exists("sim_dir")) sim_dir <- "analyses/simulated"   # run from the repository root

fig_simulated <- local({

  fs <- 8              # the only font size, in pt (titles in bold)
  ts <- fs / .pt       # the same size for geom_text(), which takes mm

  source_levels  <- c("pairgenomealign", "Gulhan2025")
  source_colours <- c(pairgenomealign = "#005A9C", Gulhan2025 = "#C77A00")   # as in Figure 5
  source_labels  <- c(pairgenomealign = "pairgenomealign", Gulhan2025 = "Gulhan et al. 2025")
  length_colours <- c(`1 kb` = "#A6A6A6", `2 kb` = "#737373", `5 kb` = "#404040", `10 kb` = "#000000")
  dark_blue      <- "#005A9C"
  x_title        <- "True identity of the simulated pair (%)"
  b_tools        <- c("lastz", "FastGA", "pairgenomealign-RY128", "pairgenomealign-RY4")

  theme_fig <- theme_bw(base_size = fs) +
    theme(text = element_text(size = fs), axis.text = element_text(size = fs),
          axis.title = element_text(size = fs), strip.text = element_text(size = fs),
          legend.text = element_text(size = fs), legend.title = element_text(size = fs),
          plot.title = element_text(size = fs, face = "bold"),
          plot.subtitle = element_text(size = fs),
          plot.title.position = "plot",
          strip.background = element_blank(), panel.grid.minor = element_blank(),
          legend.key.size = unit(fs, "pt"),
          plot.margin = margin(2, 4, 2, 4))

  # True identity of each pair (substitutions logged when the simulation was
  # re-run; bin/sim_truth.py).  It is the same in every row of a pair, and lastz
  # found all pairs, so identity.tsv has it for all 164.
  truth <- read.delim(file.path(sim_dir, "identity.tsv")) %>% distinct(pair, true_identity)
  stopifnot(nrow(truth) == 164, !anyDuplicated(truth$pair))

  # Tool names, colour group, panel labels without the "pairgenomealign-" prefix,
  # and the true identity of the pair as x coordinate
  prepare <- function(d, shown) d %>%
    filter(aligner %in% shown) %>%
    select(-any_of("true_identity")) %>%
    left_join(truth, by = "pair") %>%
    mutate(identity = true_identity,
           source = factor(if_else(grepl("^pairgenomealign", aligner), "pairgenomealign", "Gulhan2025"),
                           levels = source_levels),
           panel  = sub("^pairgenomealign-", "", aligner),
           length = factor(paste(length / 1000, "kb"), levels = names(length_colours)))

  # Trend line: robust loess (family = "symmetric": iterations that down-weight
  # points far from the fit, so that a few outliers do not pull the line) on the
  # plotted (transformed) scale, not drawn at the ends of the identity range
  # where fewer than min_n points lie within +/- half_window identity points, so
  # that the line does not extrapolate where a tool found few pairs.
  trend <- function(d, y, trans = scales::identity_trans(), span = 0.5, min_n = 12, half_window = 3) {
    fit  <- loess(trans$transform(d[[y]]) ~ d$identity, span = span, family = "symmetric")
    grid <- tibble(identity = seq(min(d$identity), max(d$identity), by = 0.25))
    grid %>%
      mutate(n      = sapply(identity, function(x) sum(abs(d$identity - x) <= half_window)),
             ok     = n >= min_n,
             # trim only the ends of the range, so that the line stays in one piece
             keep   = row_number() >= min(which(ok)) & row_number() <= max(which(ok)),
             value  = if_else(keep, trans$inverse(predict(fit, newdata = identity)), NA_real_),
             source = d$source[1])
  }

  # One small plot per tool and measure; the strip carries the tool name.
  # show_x, show_y: tick labels, as in a faceted plot (only on outer panels).
  # show.legend as named vectors of length 2: a layer gives keys to its own legend
  # for every level, also those absent from its data (ggplot2 >= 3.5 drops them
  # otherwise, and patchwork would then not merge the legends of the small plots),
  # and none to the other legend.
  small_plot <- function(d, y, y_scale, trans = scales::identity_trans(), title = NULL,
                         show_x = TRUE, show_y = TRUE, y_title = NULL, bottom = TRUE) {
    ggplot(d, aes(identity, .data[[y]])) +
      geom_hline(yintercept = 0, colour = "grey50", linewidth = 0.3) +
      geom_point(aes(fill = length), shape = 21, stroke = 0, size = 1,
                 show.legend = c(fill = TRUE, colour = FALSE)) +
      geom_line(data = trend(d, y, trans), aes(identity, value, colour = source),
                linewidth = 0.7, na.rm = TRUE, show.legend = c(colour = TRUE, fill = FALSE)) +
      facet_wrap(~ panel) +
      scale_fill_manual(values = length_colours, name = "Homologous region", drop = FALSE) +
      scale_colour_manual(values = source_colours, labels = source_labels,
                          name = "Trend line (loess)", drop = FALSE) +
      scale_x_continuous(limits = c(58.5, 101), breaks = seq(60, 100, 10), expand = c(0, 0)) +
      y_scale +
      labs(x = if (bottom) x_title, y = y_title, title = title) +   # x title on the bottom row only
      theme_fig +
      theme(axis.text.x = if (show_x) element_text(size = fs) else element_blank(),
            axis.text.y = if (show_y) element_text(size = fs) else element_blank())
  }

  # Legends, set once for the assembled figure, one per line with the title on
  # the left of the keys (a theme setting since ggplot2 3.5, a guide argument before).
  new_legend_api <- packageVersion("ggplot2") >= "3.5.0"
  legend_guides <- function() {
    g <- function(...) if (new_legend_api) guide_legend(...) else guide_legend(..., title.position = "left")
    list(guides(colour   = g(order = 1, ncol = 1),
                fill     = g(order = 2, nrow = 2, byrow = TRUE, override.aes = list(size = 2)),
                linetype = g(order = 3, override.aes = list(alpha = 1, colour = "grey30"))),
         if (new_legend_api) theme(legend.title.position = "left"))
  }

  #--- Panel A: what is measured -------------------------------------------------
  # Two simulated sequences: random flank | homologous region | random flank, and
  # one alignment that stops inside the homologous region on the left (d < 0) and
  # runs into the random flank on the right (d > 0).

  flank_l <- c(0, 2.5); core <- c(2.5, 7.5); flank_r <- c(7.5, 10)
  aln     <- c(3.0, 7.95)                      # alignment ends: one inside, one in the flank
  y_seq   <- c(top = 2, bottom = 0)            # sequence tracks
  h       <- 0.6                               # track height
  y_arrow <- y_seq[["top"]] + h / 2 + 0.45     # distance arrows, above sequence 1

  tracks <- tibble(
    y    = rep(y_seq, each = 3),
    xmin = rep(c(flank_l[1], core[1], flank_r[1]), 2),
    xmax = rep(c(flank_l[2], core[2], flank_r[2]), 2),
    part = rep(c("random", "homologous region", "random"), 2)) %>%
    mutate(ymin = y - h / 2, ymax = y + h / 2,
           fill = if_else(part == "random", "grey92", "grey72"))   # black text on both

  panelSchema <- ggplot() +
    annotate("rect", xmin = aln[1], xmax = aln[2], ymin = y_seq[["bottom"]] + h / 2,
             ymax = y_seq[["top"]] - h / 2, fill = dark_blue, alpha = 0.25) +
    annotate("text", x = mean(aln), y = mean(y_seq), label = "alignment", size = ts, colour = dark_blue) +
    geom_rect(data = tracks, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = I(fill))) +
    geom_text(data = tracks, aes(x = (xmin + xmax) / 2, y = y, label = part), size = ts) +
    annotate("segment", x = aln, xend = aln, y = y_seq[["bottom"]] - h / 2, yend = y_seq[["top"]] + h / 2,
             colour = dark_blue, linewidth = 0.5) +
    annotate("segment", x = core, xend = core, y = y_seq[["bottom"]] - h / 2, yend = y_arrow,
             colour = "black", linetype = "22", linewidth = 0.3) +
    annotate("segment", x = core, xend = aln, y = y_arrow, yend = y_arrow, linewidth = 0.4,
             arrow = arrow(length = unit(1.2, "mm"), type = "closed")) +
    # labels beside the arrows, clear of the dashed boundaries
    annotate("text", x = core[1] - 0.12, y = y_arrow, hjust = 1, size = ts, label = "d < 0") +
    annotate("text", x = aln[2] + 0.12, y = y_arrow, hjust = 0, size = ts, label = "d > 0") +
    annotate("text", x = -0.15, y = y_seq, label = c("sequence 1", "sequence 2"), hjust = 1, size = ts) +
    scale_x_continuous(limits = c(-2.3, 10.2), expand = c(0, 0)) +
    scale_y_continuous(limits = c(-0.5, y_arrow + 0.5), expand = c(0, 0)) +
    labs(title = "A: Distance d from homology boundary to alignment end") +
    theme_void(base_size = fs) +
    theme(plot.title = element_text(size = fs, face = "bold"),
          plot.title.position = "plot",
          # as theme_fig, plus the right margin of the y-axis title (half_line / 2 =
          # fs / 4), which patchwork keeps in B after collecting the title: A and B align
          plot.margin = margin(2, 4, 2, 4 + fs / 4))

  #--- Panel B: position of alignment ends, four tools ---------------------------

  ends   <- prepare(read.delim(file.path(sim_dir, "coverage.ends.tsv")), b_tools)
  missed <- prepare(read.delim(file.path(sim_dir, "coverage.tsv")), b_tools) %>% filter(core_bp == 0)
  stopifnot(!anyNA(ends$identity), !anyNA(missed$identity))
  found  <- ends %>%
    group_by(panel) %>%
    summarise(n = n_distinct(pair), .groups = "drop") %>%
    arrange(desc(n))                                       # panels ordered by pairs found

  # Signed logarithmic axis: pseudo_log_trans(sigma, base) is asinh(x / (2 sigma)) /
  # log(base); with sigma = 1, asinh(d / 2) up to a constant factor: linear within
  # about 2 bases of 0, logarithmic beyond, and 0, 10, 100 and 1000 about equally
  # spaced, so that their labels fit in short panels.  The same limits in every
  # panel of B.  The bottom expansion leaves a strip below the data for the ticks
  # of the pairs not found (oob_keep: drawn although they lie outside the limits).
  tr_ends  <- scales::pseudo_log_trans(sigma = 1, base = 10)
  lim_ends <- c(min(ends$distance), 150)
  tick_top <- tr_ends$inverse(tr_ends$transform(lim_ends[1]) -
                              0.02 * diff(tr_ends$transform(lim_ends)))
  y_ends <- scale_y_continuous(trans = tr_ends, limits = lim_ends, oob = scales::oob_keep,
                               expand = expansion(mult = c(0.09, 0.03)),
                               breaks = c(-1000, -100, -10, 0, 10, 100),
                               labels = c("-1000", "-100", "-10", "0", "+10", "+100"))

  # One row of four panels, ordered by pairs found
  b_plot <- function(i) {
    tool  <- found$panel[i]
    strip <- paste0(tool, " (", found$n[i], "/164 found)")
    p <- small_plot(filter(ends, panel == tool) %>% mutate(panel = strip), "distance", y_ends, trans = tr_ends,
                    title   = if (i == 1) "B: Position of alignment ends",
                    show_x  = TRUE,
                    bottom  = TRUE,
                    show_y  = i == 1,
                    y_title = if (i == 1) "d (bases)")
    m <- filter(missed, panel == tool) %>% mutate(panel = strip)   # same facet as the points
    if (nrow(m) > 0)
      p <- p +
        geom_rect(data = m, inherit.aes = FALSE,
                  aes(xmin = identity - 0.1, xmax = identity + 0.1,
                      ymin = -Inf, ymax = tick_top, fill = length),
                  show.legend = FALSE) +
        # invisible copy of the ticks, only to give them a legend entry
        geom_segment(data = m, inherit.aes = FALSE, alpha = 0, key_glyph = "vline",
                     aes(x = identity, xend = identity, y = -Inf, yend = tick_top,
                         linetype = "Tick: pair not found")) +
        scale_linetype_manual(values = c(`Tick: pair not found` = "solid"), name = NULL)
    p
  }

  #--- Panel C: identity of the alignments, lastz and RY4 ------------------------

  idt <- prepare(read.delim(file.path(sim_dir, "identity.tsv")), c("lastz", "pairgenomealign-RY4")) %>%
    mutate(bias = measured_identity - true_identity)
  y_idt   <- scale_y_continuous(limits = range(idt$bias))   # the same limits in both panels of C
  y_idt_t <- "Identity minus true\nidentity (% points)"

  c_plot <- function(tool, title = FALSE, show_x = TRUE, show_y = TRUE) {
    small_plot(filter(idt, panel == tool), "bias", y_idt,
               title   = if (title) "C: Identity of the alignments",
               show_x  = show_x, bottom = show_x, show_y = show_y,
               y_title = if (show_y) y_idt_t)
  }

  #--- Assembly ------------------------------------------------------------------
  # Areas are filled in alphabetical order by the plots in the order they are
  # added.  wrap_elements(full =): the schematic uses its whole area instead of
  # being aligned on the panels below.
  # C sits under the lastz and RY4 panels of B, which show the same tools; the
  # legends fill the rest of the third row.
  # B is a nested patchwork, so that its four x-axis titles merge into one
  # without interference from the panels of C below.
  b_row <- wrap_plots(lapply(1:4, b_plot), nrow = 1) + plot_layout(axis_titles = "collect")
  design <- "
  AAAA
  BBBB
  CDEE
  "
  wrap_elements(full = panelSchema) + b_row +
    c_plot("lastz", title = TRUE) + c_plot("RY4", show_y = FALSE) + guide_area() +
    plot_layout(design = design, heights = c(0.42, 1, 1), guides = "collect",
                axis_titles = "collect") &
    legend_guides() &
    theme(legend.position = "right", legend.box = "vertical", legend.direction = "vertical",
          legend.margin = margin(0, 0, 0, 0), legend.box.just = "left",
          legend.justification = c(0, 0.5),               # legends left-aligned in their area
          legend.spacing.x = unit(fs, "pt"), legend.spacing.y = unit(fs, "pt"))
})
fig_simulated

ggsave("simulated.pdf", fig_simulated, width = 160, height = 120, units = "mm")
