#!/usr/bin/env Rscript
# =============================================================================
# workbench-timeline.R
# =============================================================================
# Reads tasks.ttl files from ALPHA workbench directories via SPARQL and
# renders a Gantt chart (ggplot2) and an interactive timeline (timevis).
#
# Usage (Rscript):
#   Rscript workbench-timeline.R
#   Rscript workbench-timeline.R wb-2026-06-bayes wb-2026-03-rl
#   Rscript workbench-timeline.R --output static
#   Rscript workbench-timeline.R --output interactive
#   Rscript workbench-timeline.R --status Active,Blocked
#
# Usage (interactive / source):
#   source("workbench-timeline.R")
#   main(workbenches = "wb-2026-06-bayes", output = "static")
#
# Outputs (written next to this script in active/):
#   workbench-timeline.png   — ggplot2 Gantt chart
#   workbench-timeline.html  — timevis interactive timeline
#
# System dependencies:
#   macOS:  brew install redland
#   Ubuntu: sudo apt-get install librdf0-dev
#
# R packages:
#   install.packages(c("rdflib","dplyr","ggplot2","lubridate",
#                      "timevis","htmlwidgets","stringr","scales"))
# =============================================================================

# ── Package check ─────────────────────────────────────────────────────────────

required <- c("rdflib", "dplyr", "ggplot2", "lubridate",
              "timevis", "htmlwidgets", "stringr", "scales")

missing_pkgs <- required[!required %in% installed.packages()[, "Package"]]
if (length(missing_pkgs) > 0) {
  stop(
    "Missing R packages: ", paste(missing_pkgs, collapse = ", "), "\n\n",
    'Install with:\n  install.packages(c("',
    paste(missing_pkgs, collapse = '", "'), '"))\n\n',
    "rdflib also requires the redland system library:\n",
    "  macOS:  brew install redland\n",
    "  Ubuntu: sudo apt-get install librdf0-dev\n"
  )
}

suppressPackageStartupMessages({
  library(rdflib)
  library(dplyr)
  library(ggplot2)
  library(lubridate)
  library(timevis)
  library(htmlwidgets)
  library(stringr)
  library(scales)
})

# ── Constants ─────────────────────────────────────────────────────────────────

STATUS_LEVELS <- c("Active", "Blocked", "OnHold", "Planned", "Completed")

# Status display order for Gantt y-axis (Active at top, Completed at bottom)
STATUS_PRIORITY <- c(Active = 1L, Blocked = 2L, OnHold = 3L, Planned = 4L, Completed = 5L)

STATUS_COLORS <- c(
  Active    = "#27AE60",
  Blocked   = "#E74C3C",
  OnHold    = "#E67E22",
  Planned   = "#2980B9",
  Completed = "#95A5A6"
)

PRIORITY_RANK <- c(high = 1L, medium = 2L, low = 3L)

# ── SPARQL ────────────────────────────────────────────────────────────────────
#
# Prefixes must exactly match those used in tasks.ttl.
# schema:   https://schema.org/
# rdfs:     http://www.w3.org/2000/01/rdf-schema#
# wbs:      http://example.org/workbench/status#

SPARQL_TASKS <- "
PREFIX schema: <https://schema.org/>
PREFIX rdfs:   <http://www.w3.org/2000/01/rdf-schema#>
PREFIX wbs:    <http://example.org/workbench/status#>

SELECT DISTINCT ?task ?name ?statusLabel ?startDate ?targetDate ?priority ?note
WHERE {
  ?task a schema:Action ;
        schema:name         ?name ;
        schema:actionStatus ?status .
  ?status rdfs:label ?statusLabel .
  OPTIONAL { ?task schema:startDate     ?startDate  }
  OPTIONAL { ?task schema:scheduledTime ?targetDate }
  OPTIONAL { ?task schema:priority      ?priority   }
  OPTIONAL { ?task rdfs:comment         ?note       }
}
ORDER BY ?statusLabel ?name
"

# ── Helpers ───────────────────────────────────────────────────────────────────

get_script_dir <- function() {
  if (interactive()) return(getwd())
  args  <- commandArgs(trailingOnly = FALSE)
  match <- grep("--file=", args, value = TRUE)
  if (length(match) > 0) {
    dirname(normalizePath(sub("--file=", "", match)))
  } else {
    getwd()
  }
}

parse_args <- function() {
  if (interactive()) {
    return(list(output = "both", statuses = NULL, workbenches = character(0)))
  }

  args        <- commandArgs(trailingOnly = TRUE)
  output      <- "both"
  statuses    <- NULL
  workbenches <- character(0)

  i <- 1L
  while (i <= length(args)) {
    if (args[i] == "--output" && i < length(args)) {
      output <- match.arg(args[i + 1L], c("both", "static", "interactive"))
      i <- i + 2L
    } else if (args[i] == "--status" && i < length(args)) {
      statuses <- str_split(args[i + 1L], ",")[[1]]
      i <- i + 2L
    } else {
      workbenches <- c(workbenches, args[i])
      i <- i + 1L
    }
  }

  list(output = output, statuses = statuses, workbenches = workbenches)
}

# ── Data loading ──────────────────────────────────────────────────────────────

# Load a single tasks.ttl, run SPARQL, return tibble + workbench column
load_tasks <- function(ttl_path, wb_name) {
  tryCatch({
    rdf_obj <- rdf_parse(ttl_path, format = "turtle")
    result  <- rdf_query(rdf_obj, SPARQL_TASKS)
    tryCatch(rdf_free(rdf_obj), error = function(e) NULL)

    if (nrow(result) == 0L) {
      message("  ○ No tasks found in: ", wb_name)
      return(NULL)
    }

    result |> mutate(workbench = wb_name)
  }, error = function(e) {
    message("  ✗ Could not parse: ", wb_name, "\n    ", conditionMessage(e))
    NULL
  })
}

# Normalise dates, derive sort keys, optionally filter by status
clean_tasks <- function(df, status_filter = NULL) {
  today <- Sys.Date()

  out <- df |>
    mutate(
      status = factor(statusLabel, levels = STATUS_LEVELS),

      # Missing startDate → today; missing targetDate → start + 30d (flagged)
      start_date  = if_else(!is.na(startDate),  ymd(startDate),  today),
      open_ended  = is.na(targetDate),
      target_date = if_else(!is.na(targetDate), ymd(targetDate), start_date + 30L),

      # Sort keys
      status_rank   = STATUS_PRIORITY[as.character(status)],
      priority_rank = coalesce(PRIORITY_RANK[str_to_lower(priority)], 2L),

      # Workbench label: strip wb-YYYY-MM- prefix for display
      wb_label = str_remove(workbench, "^wb-\\d{4}-\\d{2}-"),

      # Task label: trim whitespace, used for axis
      task_label = str_squish(name)
    ) |>
    filter(!is.na(status))   # drop rows with unrecognised status

  if (!is.null(status_filter)) {
    out <- out |> filter(statusLabel %in% status_filter)
  }

  out
}

# ── ggplot2 Gantt ─────────────────────────────────────────────────────────────

plot_gantt <- function(df, out_path) {
  today <- Sys.Date()

  # Build ordered y factor: within each wb, sort by status then start date
  ordered_df <- df |>
    arrange(wb_label, status_rank, priority_rank, start_date) |>
    mutate(
      y_label = paste0(wb_label, "  |  ", task_label),
      y_label = factor(y_label, levels = rev(unique(y_label)))
    )

  solid_df  <- filter(ordered_df, !open_ended)
  dashed_df <- filter(ordered_df,  open_ended)

  p <- ggplot(ordered_df, aes(y = y_label, color = status)) +

    # Dated tasks: solid bars
    {if (nrow(solid_df)  > 0L)
      geom_segment(data = solid_df,
                   aes(x = start_date, xend = target_date, yend = y_label),
                   linewidth = 5, lineend = "round", alpha = 0.88)} +

    # Open-ended tasks: dashed bar to indicate no firm deadline
    {if (nrow(dashed_df) > 0L)
      geom_segment(data = dashed_df,
                   aes(x = start_date, xend = target_date, yend = y_label),
                   linewidth = 5, lineend = "round", alpha = 0.55,
                   linetype = "dashed")} +

    # Start-point dot
    geom_point(aes(x = start_date), shape = 21,
               fill = "white", size = 2, stroke = 1) +

    # Today reference line
    geom_vline(xintercept = as.numeric(today),
               color = "#2C3E50", linewidth = 0.4, linetype = "dashed") +
    annotate("text", x = today, y = Inf, label = "today",
             hjust = -0.2, vjust = 1.6, size = 2.8,
             color = "#2C3E50", fontface = "italic") +

    # Scales & labels
    scale_color_manual(values = STATUS_COLORS, drop = FALSE,
                       guide  = guide_legend(override.aes = list(
                         linewidth = 3, lineend = "round"))) +
    scale_x_date(date_breaks = "1 month", date_labels = "%b '%y",
                 expand = expansion(mult = c(0.02, 0.06))) +

    # Facet by workbench
    facet_grid(wb_label ~ ., scales = "free_y", space = "free_y",
               switch = "y") +

    labs(
      title    = "Active Workbench — Task Timeline",
      subtitle = paste("Generated", format(today, "%Y-%m-%d"),
                       "· dashed bars = no target date set"),
      x        = NULL,
      y        = NULL,
      color    = "Status"
    ) +

    theme_minimal(base_size = 11) +
    theme(
      strip.text.y.left  = element_text(angle = 0, hjust = 1,
                                        face = "bold", size = 10,
                                        color = "#2C3E50"),
      strip.placement    = "outside",
      strip.background   = element_rect(fill = "#ECF0F1", color = NA),
      panel.grid.major.y = element_blank(),
      panel.grid.minor.x = element_blank(),
      panel.grid.major.x = element_line(color = "#ECF0F1"),
      axis.text.x        = element_text(angle = 30, hjust = 1, size = 9),
      axis.text.y        = element_text(size = 9, hjust = 1),
      legend.position    = "bottom",
      legend.title       = element_text(face = "bold", size = 9),
      plot.title         = element_text(face = "bold", size = 14),
      plot.subtitle      = element_text(color = "#7F8C8D", size = 9),
      plot.margin        = margin(12, 24, 12, 12),
      panel.spacing      = unit(0.8, "lines")
    )

  # Height scales with number of tasks
  h <- max(4, nrow(ordered_df) * 0.42 + 2.5)
  ggsave(out_path, p, width = 13, height = h, dpi = 150, bg = "white")
  message("✓ Gantt saved: ", out_path)
  invisible(p)
}

# ── timevis interactive timeline ──────────────────────────────────────────────

plot_timevis <- function(df, out_path) {
  today <- Sys.Date()

  groups <- df |>
    distinct(wb_label) |>
    transmute(id = wb_label, content = wb_label)

  tv_data <- df |>
    mutate(row_id = row_number()) |>
    transmute(
      id      = row_id,
      content = task_label,
      start   = as.character(start_date),
      end     = as.character(target_date),
      group   = wb_label,
      # HTML tooltip on hover
      title   = paste0(
        "<div style='padding:6px;font-family:monospace;font-size:12px'>",
        "<b>", task_label, "</b><br/>",
        "<span style='color:", STATUS_COLORS[statusLabel], "'>■</span> ",
        statusLabel,
        if_else(!is.na(priority),
                paste0(" &nbsp;·&nbsp; priority: ", priority), ""),
        if_else(open_ended, " &nbsp;·&nbsp; <i>no target date</i>", ""),
        if_else(!is.na(note),
                paste0("<br/><i>", note, "</i>"), ""),
        "</div>"
      ),
      style   = paste0(
        "background-color:", STATUS_COLORS[statusLabel], ";",
        "border-color:",     STATUS_COLORS[statusLabel], ";",
        "color:white;",
        "border-radius:4px;",
        if_else(open_ended, "opacity:0.6;border-style:dashed;", "")
      )
    )

  tv <- timevis(
    data    = tv_data,
    groups  = groups,
    options = list(
      start            = as.character(today - 21L),
      end              = as.character(today + 120L),
      editable         = FALSE,
      stack            = TRUE,
      showMajorLabels  = TRUE,
      zoomMin          = 604800000,   # 1 week in ms
      groupOrder       = "content"
    )
  )

  saveWidget(tv, out_path, selfcontained = TRUE,
             title = "Workbench Timeline")
  message("✓ Interactive timeline saved: ", out_path)
  invisible(tv)
}

# ── Main ──────────────────────────────────────────────────────────────────────

main <- function(workbenches = character(0),
                 output      = "both",
                 statuses    = NULL) {
  # Merge function args with CLI args (CLI wins when called via Rscript)
  cli <- parse_args()
  if (!interactive()) {
    workbenches <- cli$workbenches
    output      <- cli$output
    statuses    <- cli$statuses
  }

  script_dir <- get_script_dir()

  # Discover all wb-YYYY-MM-* directories
  all_dirs <- list.dirs(script_dir, full.names = TRUE, recursive = FALSE)
  wb_dirs  <- all_dirs[str_detect(basename(all_dirs), "^wb-\\d{4}-\\d{2}-")]

  # Filter if specific workbenches requested
  if (length(workbenches) > 0L) {
    wb_dirs <- wb_dirs[basename(wb_dirs) %in% workbenches]
    if (length(wb_dirs) == 0L) {
      stop("No matching workbenches: ", paste(workbenches, collapse = ", "))
    }
  }

  if (length(wb_dirs) == 0L) {
    message("No workbench directories found in: ", script_dir)
    return(invisible(NULL))
  }

  message("\nFound ", length(wb_dirs), " workbench(es):")
  message(paste0("  • ", basename(wb_dirs), collapse = "\n"))
  message("")

  # Load tasks from each tasks.ttl
  task_list <- lapply(wb_dirs, function(d) {
    ttl <- file.path(d, "tasks.ttl")
    if (!file.exists(ttl)) {
      message("  ○ Skipping (no tasks.ttl): ", basename(d))
      return(NULL)
    }
    message("  Loading: ", basename(d), "/tasks.ttl")
    load_tasks(ttl, basename(d))
  })

  df_raw <- bind_rows(Filter(Negate(is.null), task_list))

  if (nrow(df_raw) == 0L) {
    message("\nNo tasks found across all workbenches.")
    return(invisible(NULL))
  }

  df <- clean_tasks(df_raw, statuses)

  n_wb <- n_distinct(df$workbench)
  message("\n", nrow(df), " task(s) across ", n_wb, " workbench(es)\n")

  # Status summary
  df |>
    count(status, .drop = FALSE) |>
    mutate(line = paste0("  ", str_pad(status, 10), " : ", n)) |>
    pull(line) |>
    paste(collapse = "\n") |>
    message()

  message("")

  # Render outputs
  if (output %in% c("both", "static")) {
    png_path <- file.path(script_dir, "workbench-timeline.png")
    plot_gantt(df, png_path)
  }

  if (output %in% c("both", "interactive")) {
    html_path <- file.path(script_dir, "workbench-timeline.html")
    plot_timevis(df, html_path)
  }

  invisible(df)
}

main()
