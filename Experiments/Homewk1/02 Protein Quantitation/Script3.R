# Figure 2h: independent A280 / BCA concentration comparison
# Put this script and both raw CSV files in the same working directory.
# Requires ggplot2. Does not source Script1/Script2 or use their objects.

if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop('Please install ggplot2 first: install.packages("ggplot2")')
}
library(ggplot2)

# ================= Files =================
# Change DATA_DIR if your CSV files are in another directory.
DATA_DIR <- "."
OUTPUT_DIR <- DATA_DIR

# NULL = auto-detect the base name or one numbered copy, e.g. (2).
# If several copies exist, enter the exact filename here to avoid ambiguity.
SPEC_FILE <- NULL
BCA_FILE <- NULL

resolve_csv <- function(stem, override = NULL) {
  if (!is.null(override)) {
    path <- file.path(DATA_DIR, override)
    if (!file.exists(path)) stop("File not found: ", path)
    return(path)
  }
  candidates <- list.files(DATA_DIR, full.names = TRUE)
  names_only <- basename(candidates)
  pattern <- paste0(
    "^\\Q", stem, "\\E(?:\\([0-9]+\\))?\\.csv$"
  )
  hits <- candidates[grepl(pattern, names_only, perl = TRUE)]
  if (length(hits) == 0) stop("Cannot find CSV: ", stem)
  if (length(hits) > 1) {
    stop(
      "Multiple CSV copies found: ", paste(basename(hits), collapse = ", "),
      ". Set SPEC_FILE or BCA_FILE to the intended filename."
    )
  }
  hits
}

spec_input <- resolve_csv("Data-Spec-14.10.26", SPEC_FILE)
bca_input <- resolve_csv("Data-BCA-14.10.26", BCA_FILE)
if (!dir.exists(OUTPUT_DIR)) dir.create(OUTPUT_DIR, recursive = TRUE)

read_assay <- function(path, last_column) {
  lines <- readLines(path, warn = FALSE)
  raw <- read.csv(
    text = paste0(paste(lines, collapse = "\n"), "\n"),
    header = FALSE, fill = TRUE,
    stringsAsFactors = FALSE, check.names = FALSE
  )
  if (nrow(raw) < 3 || ncol(raw) < last_column) {
    stop("Unexpected CSV dimensions: ", path)
  }
  numbers <- function(row, columns) {
    suppressWarnings(as.numeric(unlist(
      raw[row, columns, drop = FALSE], use.names = FALSE
    )))
  }
  std <- data.frame(C = numbers(2, 2:13), A = numbers(3, 2:13))
  unknown <- numbers(3, 14:last_column)
  if (any(!is.finite(c(std$C, std$A, unknown)))) {
    stop("Invalid numeric data: ", path)
  }
  if (length(unique(std$C)) < 3) stop("Too few standard levels.")
  list(std = std, unknown = unknown)
}

# ================= Linear calibrations =================
spec <- read_assay(spec_input, 15)
bca <- read_assay(bca_input, 19)

# A280: no additional blank subtraction.
# BCA: subtract the same mean blank from standards and unknowns.
if (!any(bca$std$C == 0)) stop("BCA blank standards are missing.")
bca_blank <- mean(bca$std$A[bca$std$C == 0])
bca$std$A <- bca$std$A - bca_blank
bca$unknown <- bca$unknown - bca_blank

spec_fit <- lm(A ~ C, data = spec$std)
bca_fit <- lm(A ~ C, data = bca$std)

# ================= 95% calibration intervals =================
# Invert the prediction limits for the mean of m unknown readings:
# (mean(A_unknown) - a - b*C)^2 <=
# t^2*s^2*[1/m + 1/n + (C - mean(C_std))^2/Sxx].
# Assumes independent normal equal-variance response errors and a valid
# linear model. Standard concentrations and dilution factors are exact.
# SD, SEM and calibration intervals are different quantities.
calibration_interval <- function(model, readings, dilution, label) {
  mf <- model.frame(model)
  x <- mf$C
  y <- model.response(mf)
  n <- length(x)
  m <- length(readings)
  a <- unname(coef(model)[["(Intercept)"]])
  b <- unname(coef(model)[["C"]])
  if (!is.finite(b) || b <= 0) stop("Calibration slope must be positive.")
  xbar <- mean(x)
  sxx <- sum((x - xbar)^2)
  k <- (qt(0.975, df.residual(model)) * summary(model)$sigma)^2
  delta <- mean(readings) - mean(y)
  qa <- b^2 - k / sxx
  qb <- -2 * b * delta
  qc <- delta^2 - k * (1 / m + 1 / n)
  disc <- qb^2 - 4 * qa * qc
  if (!is.finite(disc) || qa <= 0 || disc <= 0) {
    stop("A finite two-sided calibration interval could not be calculated.")
  }
  limits <- sort(xbar + c(-qb - sqrt(disc), -qb + sqrt(disc)) / (2 * qa))
  individual <- (readings - a) / b
  estimate <- mean(individual)
  data.frame(
    Method = label, N_readings = m, Dilution = dilution,
    Estimate = estimate * dilution,
    Lower95 = limits[1] * dilution,
    Upper95 = limits[2] * dilution,
    Technical_SD = sd(individual) * dilution,
    Readings_within_range = all(
      readings >= min(y) & readings <= max(y) &
        individual >= min(x) & individual <= max(x)
    ),
    Interval_within_range = limits[1] >= min(x) && limits[2] <= max(x)
  )
}

results <- rbind(
  calibration_interval(spec_fit, spec$unknown, 1, "A280"),
  calibration_interval(bca_fit, bca$unknown[3:4], 2, "BCA 1/2"),
  calibration_interval(bca_fit, bca$unknown[5:6], 4, "BCA 1/4")
)
if (!all(results$Readings_within_range)) {
  stop("A selected unknown lies outside its calibration range; review before plotting.")
}
results$Group <- 1:3
results$BarFill <- c("#ABCADB", "#BDD9BF", "#D2C1DE")

# ================= Figure h =================
TEXT <- "#252A2E"
paper_theme <- theme_classic(base_size = 10, base_family = "sans") +
  theme(
    aspect.ratio = 1.35,
    axis.line = element_line(colour = TEXT, linewidth = 0.45),
    axis.ticks = element_line(colour = TEXT, linewidth = 0.4),
    axis.ticks.length = grid::unit(1.4, "mm"),
    axis.text = element_text(colour = TEXT, size = 8.5),
    axis.title = element_text(colour = TEXT, size = 10),
    axis.title.x = element_text(margin = margin(t = 8)),
    axis.title.y = element_text(margin = margin(r = 8)),
    plot.title = element_blank(),
    plot.tag = element_text(size = 13, face = "bold", colour = TEXT),
    plot.margin = margin(12, 13, 10, 9),
    legend.position = "none"
  )

ymax <- max(0.55, ceiling(max(results$Upper95) / 0.05) * 0.05 + 0.05)
ymin <- min(0, floor(min(results$Lower95) / 0.05) * 0.05)
p_h <- ggplot(results, aes(x = Group, y = Estimate)) +
  geom_col(
    aes(fill = BarFill), width = 0.56,
    colour = "#858D93", linewidth = 0.55
  ) +
  geom_errorbar(
    aes(ymin = Lower95, ymax = Upper95),
    width = 0.13, linewidth = 0.5, colour = "#555D63"
  ) +
  geom_text(
    aes(y = Upper95 + 0.018, label = sprintf("%.3f", Estimate)),
    colour = "#454C52", size = 2.9, family = "sans"
  ) +
  scale_fill_identity() +
  scale_x_continuous(
    breaks = 1:3, labels = c("A280", "BCA\n1/2", "BCA\n1/4"),
    expand = expansion(mult = 0)
  ) +
  scale_y_continuous(
    breaks = pretty(c(ymin, ymax), n = 6),
    labels = function(z) sprintf("%.1f", z),
    expand = expansion(mult = 0)
  ) +
  coord_cartesian(xlim = c(0.45, 3.55), ylim = c(ymin, ymax)) +
  labs(
    x = "Method / sample dilution",
    y = "Original protein concentration (mg/mL)", tag = "h"
  ) + paper_theme

print(p_h)
output_png <- file.path(OUTPUT_DIR, "Protein-Concentration-Comparison-14.10.26.png")
output_txt <- file.path(OUTPUT_DIR, "Protein-Concentration-Comparison-14.10.26.txt")
ggsave(output_png, plot = p_h, width = 4.1, height = 5.3,
       units = "in", dpi = 600, bg = "white")

# ================= Report =================
report <- capture.output({
  cat("PROTEIN CONCENTRATION COMPARISON: PANEL h\n")
  cat("============================================\n\n")
  cat("A280 input:", spec_input, "\n")
  cat("BCA input:", bca_input, "\n")
  cat(sprintf("BCA mean blank = %.8f\n", bca_blank))
  cat("All calibrations are linear and retain an intercept.\n")
  cat("Unit: mg/mL; dilution factors: 1, 2, 4.\n\n")
  for (nm in c("A280", "BCA")) {
    fit <- if (nm == "A280") spec_fit else bca_fit
    cat(nm, "calibration (BCA absorbance is blank-corrected):\n")
    print(coef(summary(fit)))
    cat(sprintf("Residual SD = %.8f; R-squared = %.9f\n\n",
                summary(fit)$sigma, summary(fit)$r.squared))
  }
  print(results[, setdiff(names(results), c("Group", "BarFill"))],
        row.names = FALSE, digits = 8)
  cat("\nBars: estimates from mean unknown absorbance.\n")
  cat("Error bars: 95% calibration intervals, NOT SD or SEM.\n")
  cat("Intervals invert prediction limits for the mean of the unknown readings.\n")
  cat("Assumptions: valid linear calibration; independent normal equal-variance response errors.\n")
  cat("Unknown response variance is estimated from calibration residuals.\n")
  cat("Standard concentrations and dilution factors are treated as exact.\n")
  cat("Pipetting, dilution uncertainty, shared preparation errors and model misspecification are not included.\n")
  cat("Identical A280 readings do not imply zero calibration uncertainty.\n")
  cat("BCA intervals are conditional on the linear model despite residual curvature.\n")
  cat("Both BCA estimates share a calibration; they are not independent biological groups.\n")
  cat("Undiluted BCA extrapolations are excluded; no pooled BCA estimate is reported.\n")
  cat("No significance test is performed; interval overlap does not establish equivalence.\n")
  cat("Method reference: https://www.itl.nist.gov/div898/handbook/pmd/section5/pmd521.htm\n")
})
writeLines(report, output_txt)
cat(paste(report, collapse = "\n"), "\n")
cat("\nSaved figure:", output_png, "\nSaved report:", output_txt, "\n")
