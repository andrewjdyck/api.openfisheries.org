
# Compares two builds of the landings API files (e.g. the current docs/ and a
# build from a new FAO release) over the years they share, and prints a
# Markdown report.
#
# Run from the repository root:
#   Rscript _bin/compare_landings.R old_dir new_dir [first_year] [last_year] > report.md

library(jsonlite)

read_landings_dir <- function(dir, kind) {
  files <- list.files(file.path(dir, "landings", kind), pattern = "\\.json$", full.names = TRUE)
  rows <- lapply(files, function(f) {
    d <- fromJSON(f)
    if (length(d) == 0) return(NULL)
    d$code <- sub("\\.json$", "", basename(f))
    d
  })
  do.call(rbind, rows)
}

fmt <- function(x, digits = 0) format(round(x, digits), big.mark = ",", scientific = FALSE, trim = TRUE)

pct <- function(new, old) ifelse(old == 0, NA, 100 * (new - old) / old)

md_table <- function(df) {
  cat("| ", paste(names(df), collapse = " | "), " |\n", sep = "")
  cat("|", paste(rep("---", ncol(df)), collapse = "|"), "|\n", sep = "")
  for (i in seq_len(nrow(df))) cat("| ", paste(df[i, ], collapse = " | "), " |\n", sep = "")
  cat("\n")
}

compare_codes <- function(old, new, years, label, top = 10) {
  old <- old[old$year %in% years, ]
  new <- new[new$year %in% years, ]
  old_tot <- tapply(old$catch, old$code, sum)
  new_tot <- tapply(new$catch, new$code, sum)
  only_old <- setdiff(names(old_tot), names(new_tot))
  only_new <- setdiff(names(new_tot), names(old_tot))
  common <- intersect(names(old_tot), names(new_tot))

  cat("## ", label, "\n\n", sep = "")
  cat("- Codes in old build: ", length(old_tot), "; in new build: ", length(new_tot),
      "; in both: ", length(common), "\n", sep = "")
  cat("- Only in old build (", length(only_old), "): ",
      if (length(only_old)) paste(only_old, collapse = ", ") else "none", "\n", sep = "")
  show_new <- head(only_new, 40)
  cat("- Only in new build (", length(only_new), "): ",
      if (length(only_new)) paste0(paste(show_new, collapse = ", "),
                                   if (length(only_new) > 40) ", ..." else "") else "none",
      "\n", sep = "")
  cat("- Catch in codes only in the new build, ", min(years), "-", max(years), ": ",
      fmt(sum(new_tot[only_new])), " t\n", sep = "")
  cat("- Catch in codes only in the old build, ", min(years), "-", max(years), ": ",
      fmt(sum(old_tot[only_old])), " t\n", sep = "")

  diffs <- data.frame(
    code = common,
    old = as.numeric(old_tot[common]),
    new = as.numeric(new_tot[common])
  )
  diffs$diff <- diffs$new - diffs$old
  diffs$pct <- pct(diffs$new, diffs$old)
  identical_n <- sum(abs(diffs$diff) < 0.5)
  within_1pct <- sum(!is.na(diffs$pct) & abs(diffs$pct) <= 1)
  cat("- Codes in both with the same total (within 0.5 t): ", identical_n, " of ", nrow(diffs),
      "; within 1%: ", within_1pct, "\n\n", sep = "")

  cat("Largest changes in total catch, ", min(years), "-", max(years), ":\n\n", sep = "")
  big <- head(diffs[order(-abs(diffs$diff)), ], top)
  md_table(data.frame(
    Code = big$code,
    `Old (t)` = fmt(big$old),
    `New (t)` = fmt(big$new),
    `Change (t)` = fmt(big$diff),
    `Change (%)` = fmt(big$pct, 1),
    check.names = FALSE
  ))
}

compare_landings <- function(old_dir, new_dir, years = NULL) {
  old_global <- fromJSON(file.path(old_dir, "landings.json"))
  new_global <- fromJSON(file.path(new_dir, "landings.json"))
  if (is.null(years)) years <- intersect(old_global$year, new_global$year)

  cat("# Landings comparison\n\n")
  cat("- Old build: `", old_dir, "` (", min(old_global$year), "-", max(old_global$year), ")\n", sep = "")
  cat("- New build: `", new_dir, "` (", min(new_global$year), "-", max(new_global$year), ")\n", sep = "")
  cat("- Compared years: ", min(years), "-", max(years), "\n\n", sep = "")

  g <- merge(old_global, new_global, by = "year", suffixes = c("_old", "_new"))
  g <- g[g$year %in% years, ]
  g$diff <- g$catch_new - g$catch_old
  g$pct <- pct(g$catch_new, g$catch_old)
  cat("## Global totals\n\n")
  cat("- Total over ", min(years), "-", max(years), ": old ", fmt(sum(g$catch_old)), " t, new ",
      fmt(sum(g$catch_new)), " t (", fmt(pct(sum(g$catch_new), sum(g$catch_old)), 2), "%)\n", sep = "")
  cat("- Largest yearly change: ", fmt(max(abs(g$pct)), 2), "% (",
      g$year[which.max(abs(g$pct))], ")\n\n", sep = "")
  md_table(data.frame(
    Year = g$year,
    `Old (t)` = fmt(g$catch_old),
    `New (t)` = fmt(g$catch_new),
    `Change (%)` = fmt(g$pct, 2),
    check.names = FALSE
  ))

  compare_codes(read_landings_dir(old_dir, "countries"), read_landings_dir(new_dir, "countries"),
                years, "Countries")
  compare_codes(read_landings_dir(old_dir, "species"), read_landings_dir(new_dir, "species"),
                years, "Species")
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 2) {
  years <- if (length(args) >= 4) as.integer(args[3]):as.integer(args[4]) else NULL
  compare_landings(args[1], args[2], years)
}
