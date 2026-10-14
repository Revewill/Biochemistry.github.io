library(ggplot2)
library(grid)

# ================= 文件 =================
INPUT <- "Data-Spec-14.10.26.csv"

if (!file.exists(INPUT)) {
  INPUT <- "Data-Spec-14.10.26(1).csv"
}
if (!file.exists(INPUT)) {
  stop("找不到 Data-Spec-14.10.26.csv，请检查工作目录。")
}

OUTPUT_PNG <- "Spectrophotometric-Assay-14.10.26.png"
OUTPUT_TXT <- "Spectrophotometric-Assay-14.10.26.txt"

PATH_LENGTH_CM <- 1

# ================= 读取 =================
input_lines <- readLines(INPUT, warn = FALSE)

raw <- read.csv(
  text = paste0(paste(input_lines, collapse = "\n"), "\n"),
  header = FALSE,
  fill = TRUE,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

if (nrow(raw) < 3 || ncol(raw) < 15) {
  stop("数据格式不符合预期。")
}

get_numbers <- function(row, columns) {
  suppressWarnings(as.numeric(
    unlist(raw[row, columns, drop = FALSE], use.names = FALSE)
  ))
}

std <- data.frame(
  C = get_numbers(2, 2:13),
  A = get_numbers(3, 2:13),
  Operator = factor(
    rep(c("Standard 1-6", "Standard 1'-6'"), 6),
    levels = c("Standard 1-6", "Standard 1'-6'")
  ),
  Level = rep(1:6, each = 2)
)

unknown <- data.frame(
  Sample = c("Unknown 7", "Unknown 7'"),
  A = get_numbers(3, 14:15)
)

if (
  any(!is.finite(std$C)) ||
  any(!is.finite(std$A)) ||
  any(!is.finite(unknown$A))
) {
  stop("浓度或吸光度中存在无效数值。")
}

# ================= 拟合与统计 =================
s1 <- std[std$Operator == "Standard 1-6", ]
s2 <- std[std$Operator == "Standard 1'-6'", ]

fit1 <- lm(A ~ C, data = s1)
fit2 <- lm(A ~ C, data = s2)
fit_all <- lm(A ~ C, data = std)

fit_parallel <- lm(A ~ C + Operator, data = std)
fit_interaction <- lm(A ~ C * Operator, data = std)
parallel_test <- anova(fit_parallel, fit_interaction)

std$Residual <- residuals(fit_all)

unknown$C <- (
  unknown$A - coef(fit_all)[["(Intercept)"]]
) / coef(fit_all)[["C"]]

unknown$Within_range <- (
  unknown$C >= min(std$C) &
  unknown$C <= max(std$C)
)

get_stats <- function(model) {
  sm <- summary(model)

  c(
    intercept = unname(coef(model)[1]),
    slope = unname(coef(model)[2]),
    R2 = sm$r.squared,
    adjusted_R2 = sm$adj.r.squared,
    P_slope = sm$coefficients["C", "Pr(>|t|)"],
    residual_SD = sm$sigma,
    residual_df = df.residual(model)
  )
}

st1 <- get_stats(fit1)
st2 <- get_stats(fit2)
sta <- get_stats(fit_all)

stars <- function(p) {
  if (!is.finite(p)) return("NA")
  if (p < 0.001) return("***")
  if (p < 0.01) return("**")
  if (p < 0.05) return("*")
  "ns"
}

p_expression <- function(p) {
  if (p < 0.001) {
    exponent <- floor(log10(p))
    mantissa <- p / 10^exponent
    sprintf("%.2f %%*%% 10^{%d}", mantissa, exponent)
  } else {
    sprintf("%.4f", p)
  }
}

stats_expression <- function(st, prefix = NULL) {
  body <- sprintf(
    'italic(R)^2 == %.5f * "," ~~ italic(P) == %s ~ "%s"',
    st[["R2"]],
    p_expression(st[["P_slope"]]),
    stars(st[["P_slope"]])
  )

  if (is.null(prefix)) {
    body
  } else {
    paste0('"', prefix, '" ~~ ', body)
  }
}

# ================= 配色 =================
BLUE <- "#226482"
RED_DARK <- "#633737"
GREEN <- "#A5D6A7"
PURPLE <- "#BCA0CC"

TEXT <- "#252A2E"
LINE <- "#262626"
LINE_LIGHT <- "#B7BDC2"

blue_gradient <- colorRampPalette(
  c("#8ED3F5", "#59A9CE", "#226482")
)(6)

red_gradient <- colorRampPalette(
  c("#F6CACA", "#F2A0A0", "#A95858")
)(6)

grey_gradient <- colorRampPalette(
  c("#C5C5C5", "#858585", "#333333")
)(6)

std$PointColour <- ifelse(
  std$Operator == "Standard 1-6",
  blue_gradient[std$Level],
  red_gradient[std$Level]
)

std$GreyColour <- grey_gradient[std$Level]

s1 <- std[std$Operator == "Standard 1-6", ]
s2 <- std[std$Operator == "Standard 1'-6'", ]

# ================= TXT 输出 =================
report <- capture.output({
  cat("SPECTROPHOTOMETRIC ASSAY: A280\n")
  cat("============================================\n\n")
  cat("Input:", INPUT, "\n")
  cat("Concentration unit: mg/mL\n")
  cat("Model: A280 = intercept + slope * concentration\n")
  cat("All models retain an intercept.\n")
  cat("No additional blank subtraction was applied.\n")
  cat("Each operator prepared one six-level standard series.\n")
  cat("Unknown readings are technical measurements, not biological replicates.\n\n")

  models <- list(
    "Standard 1-6" = fit1,
    "Standard 1'-6'" = fit2,
    "Combined standards" = fit_all
  )

  for (nm in names(models)) {
    model <- models[[nm]]
    st <- get_stats(model)

    cat("--------------------------------------------\n")
    cat(nm, "\n")

    cat(sprintf(
      "Equation: A280 = %.8f * C %s %.8f\n",
      st[["slope"]],
      ifelse(st[["intercept"]] >= 0, "+", "-"),
      abs(st[["intercept"]])
    ))
    cat(sprintf("Number of readings = %d\n", nobs(model)))
    cat(sprintf("R-squared = %.9f\n", st[["R2"]]))
    cat(sprintf(
      "Adjusted R-squared = %.9f\n", st[["adjusted_R2"]]
    ))
    cat(sprintf(
      "Slope P (two-sided) = %.8g (%s)\n",
      st[["P_slope"]], stars(st[["P_slope"]])
    ))
    cat(sprintf(
      "Residual SD = %.8f\n", st[["residual_SD"]]
    ))
    cat(sprintf(
      "Residual df = %d\n", st[["residual_df"]]
    ))

    cat("Coefficient estimates and tests:\n")
    print(coef(summary(model)))

    cat("95% coefficient confidence intervals:\n")
    print(confint(model))

    cat(sprintf(
      "E(1%%, 1 cm) = %.6f, assuming path length = %.3f cm\n\n",
      10 * st[["slope"]] / PATH_LENGTH_CM,
      PATH_LENGTH_CM
    ))
  }

  cat("============================================\n")
  cat("BETWEEN-OPERATOR SLOPE COMPARISON\n\n")
  cat("Reduced model: A ~ C + Operator\n")
  cat("Full model: A ~ C * Operator\n")
  print(parallel_test)

  interaction_name <- grep(
    ":", names(coef(fit_interaction)), value = TRUE
  )

  cat("\nSlope difference: second operator minus first operator\n")
  print(
    coef(summary(fit_interaction))[
      interaction_name, , drop = FALSE
    ]
  )

  cat("95% confidence interval for slope difference:\n")
  print(
    confint(fit_interaction)[
      interaction_name, , drop = FALSE
    ]
  )

  cat(sprintf(
    "\nRelative slope difference (symmetric) = %.4f%%\n",
    100 * abs(st1[["slope"]] - st2[["slope"]]) /
      mean(abs(c(st1[["slope"]], st2[["slope"]])))
  ))

  cat("A nonsignificant interaction does not establish equivalence.\n")
  cat("Inference is conditional on the linear-model assumptions.\n")
  cat("Results describe these two preparations, not general operator performance.\n\n")

  cat("============================================\n")
  cat("UNKNOWN SAMPLE: COMBINED CALIBRATION\n\n")
  print(unknown, row.names = FALSE)

  cat(sprintf(
    "\nMean concentration = %.8f mg/mL\n", mean(unknown$C)
  ))
  cat(sprintf(
    "Technical SD = %.8f mg/mL\n", sd(unknown$C)
  ))
  cat(sprintf(
    "Technical CV = %.5f%%\n",
    100 * sd(unknown$C) / abs(mean(unknown$C))
  ))
  cat(sprintf(
    "Mean concentration, two significant figures = %s mg/mL\n",
    format(signif(mean(unknown$C), 2), trim = TRUE)
  ))

  cat("Identical recorded readings do not imply zero measurement uncertainty.\n")
  cat("No additional sample dilution factor has been applied.\n")
  cat("Unknowns are not included in standard-curve fitting.\n\n")

  cat("============================================\n")
  cat("STANDARD READINGS AND COMBINED-MODEL RESIDUALS\n\n")

  print(
    std[, c("C", "A", "Operator", "Residual")],
    row.names = FALSE
  )

  cat("\nFigure P values test H0: slope = 0.\n")
  cat("* P < 0.05; ** P < 0.01; *** P < 0.001; ns P >= 0.05.\n")
  cat("Each residual bar represents one reading.\n")
  cat("No per-concentration residual tests are performed.\n")
  cat("Point coordinates in panels a and b are unchanged.\n\n")

  cat("FIGURE PANEL DESCRIPTIONS\n")
  cat("a: Separate linear calibrations for the two standard preparations.\n")
  cat("b: Combined calibration and unknown-sample interpolation.\n")
  cat("c: Individual residuals from the combined calibration.\n")
})

writeLines(report, OUTPUT_TXT)
cat(paste(report, collapse = "\n"), "\n")

# ================= 统一主题 =================
paper_theme <- theme_classic(
  base_size = 10,
  base_family = "sans"
) +
  theme(
    aspect.ratio = 1.35,
    axis.line = element_line(colour = TEXT, linewidth = 0.45),
    axis.ticks = element_line(colour = TEXT, linewidth = 0.4),
    axis.ticks.length = unit(1.4, "mm"),
    axis.text = element_text(colour = TEXT, size = 8.5),
    axis.title = element_text(colour = TEXT, size = 10),
    axis.title.x = element_text(margin = margin(t = 8)),
    axis.title.y = element_text(margin = margin(r = 8)),
    plot.title = element_blank(),
    plot.tag = element_text(
      size = 13, face = "bold", colour = TEXT
    ),
    plot.margin = margin(12, 13, 10, 9),
    legend.position = "none"
  )

# ================= 点与图例 =================
add_standard_points <- function(p, grayscale = FALSE) {
  d1 <- s1
  d2 <- s2

  d1$DisplayColour <- if (grayscale) {
    d1$GreyColour
  } else {
    d1$PointColour
  }

  d2$DisplayColour <- if (grayscale) {
    d2$GreyColour
  } else {
    d2$PointColour
  }

  p +
    geom_point(
      data = d1,
      aes(C, A, fill = DisplayColour),
      shape = 24,
      size = 2.35,
      stroke = 0.35,
      colour = "white",
      inherit.aes = FALSE
    ) +
    geom_point(
      data = d2,
      aes(C, A, colour = DisplayColour),
      shape = 21,
      size = 2.4,
      stroke = 0.75,
      fill = NA,
      inherit.aes = FALSE
    ) +
    scale_fill_identity() +
    scale_colour_identity()
}

add_key <- function(
    p, x, y, label,
    fill = NA,
    edge = "white",
    shape = 21,
    size = 2.8,
    stroke = 0.65,
    text_offset = 0.045
) {
  p +
    annotate(
      "point",
      x = x, y = y,
      shape = shape,
      size = size,
      fill = fill,
      colour = edge,
      stroke = stroke
    ) +
    annotate(
      "text",
      x = x + text_offset, y = y,
      label = label,
      hjust = 0, vjust = 0.5,
      size = 2.65,
      family = "sans",
      colour = TEXT
    )
}

x_limits <- c(-0.055, 1.065)
y_limits <- c(-0.035, 0.80)

line_grid <- data.frame(
  C = seq(-0.015, 1.02, length.out = 250)
)

line1 <- transform(
  line_grid, A = as.numeric(predict(fit1, newdata = line_grid))
)
line2 <- transform(
  line_grid, A = as.numeric(predict(fit2, newdata = line_grid))
)
line_all <- transform(
  line_grid, A = as.numeric(predict(fit_all, newdata = line_grid))
)

axis_scales <- function(p) {
  p +
    scale_x_continuous(
      breaks = c(0, 0.25, 0.50, 0.75, 1.00),
      labels = function(z) sprintf("%.2f", z),
      expand = expansion(mult = 0)
    ) +
    scale_y_continuous(
      breaks = seq(0, 0.6, 0.2),
      labels = function(z) sprintf("%.1f", z),
      expand = expansion(mult = 0)
    ) +
    coord_cartesian(xlim = x_limits, ylim = y_limits) +
    labs(
      x = "Protein concentration (mg/mL)",
      y = expression(plain(A)[280])
    )
}

# ================= a：分别拟合 =================
p_a <- ggplot() +
  geom_line(
    data = line1, aes(C, A),
    colour = LINE_LIGHT,
    linewidth = 0.95,
    lineend = "round"
  ) +
  geom_line(
    data = line2, aes(C, A),
    colour = LINE,
    linewidth = 0.55,
    linetype = "dashed"
  )

p_a <- add_standard_points(p_a)

p_a <- p_a +
  annotate(
    "text",
    x = -0.015, y = 0.755,
    label = stats_expression(st1, "1-6:"),
    parse = TRUE,
    hjust = 0, size = 2.65,
    family = "sans", colour = BLUE
  ) +
  annotate(
    "text",
    x = -0.015, y = 0.700,
    label = stats_expression(st2, "1'-6':"),
    parse = TRUE,
    hjust = 0, size = 2.65,
    family = "sans", colour = RED_DARK
  )

key_a_x <- 0.60

p_a <- add_key(
  p_a, key_a_x, 0.200,
  "Standard 1-6",
  fill = blue_gradient[4],
  shape = 24,
  size = 2.5,
  stroke = 0.35
)

p_a <- add_key(
  p_a, key_a_x, 0.155,
  "Standard 1'-6'",
  fill = NA,
  edge = red_gradient[4],
  shape = 21,
  size = 3.0,
  stroke = 0.75
)

p_a <- p_a +
  annotate(
    "segment",
    x = key_a_x - 0.025,
    xend = key_a_x + 0.025,
    y = 0.105, yend = 0.105,
    linewidth = 0.95, colour = LINE_LIGHT
  ) +
  annotate(
    "text",
    x = key_a_x + 0.045, y = 0.105,
    label = "Fit: 1-6",
    hjust = 0, size = 2.65,
    family = "sans", colour = TEXT
  ) +
  annotate(
    "segment",
    x = key_a_x - 0.025,
    xend = key_a_x + 0.025,
    y = 0.060, yend = 0.060,
    linewidth = 0.55,
    colour = LINE,
    linetype = "dashed"
  ) +
  annotate(
    "text",
    x = key_a_x + 0.045, y = 0.060,
    label = "Fit: 1'-6'",
    hjust = 0, size = 2.65,
    family = "sans", colour = TEXT
  )

p_a <- axis_scales(p_a) +
  labs(tag = "a") +
  paper_theme

# ================= b：总体拟合 =================
p_b <- ggplot() +
  geom_line(
    data = line_all, aes(C, A),
    colour = LINE,
    linewidth = 0.65
  )

unknown_guides <- unique(unknown[, c("C", "A")])

p_b <- p_b +
  geom_segment(
    data = unknown_guides,
    aes(x = C, xend = C, y = 0, yend = A),
    colour = "#7D8780",
    linewidth = 0.35,
    linetype = "dotted"
  ) +
  geom_segment(
    data = unknown_guides,
    aes(x = 0, xend = C, y = A, yend = A),
    colour = "#7D8780",
    linewidth = 0.35,
    linetype = "dotted"
  )

p_b <- add_standard_points(p_b, grayscale = TRUE)

p_b <- p_b +
  annotate(
    "point",
    x = unknown$C[1], y = unknown$A[1],
    shape = 22,
    size = 3.6,
    stroke = 0.5,
    fill = GREEN,
    colour = "white"
  ) +
  annotate(
    "point",
    x = unknown$C[2], y = unknown$A[2],
    shape = 23,
    size = 2.4,
    stroke = 0.4,
    fill = PURPLE,
    colour = "white"
  ) +
  annotate(
    "text",
    x = -0.015, y = 0.750,
    label = stats_expression(sta),
    parse = TRUE,
    hjust = 0, size = 2.9,
    colour = TEXT, family = "sans"
  ) +
  annotate(
    "text",
    x = mean(unknown$C) - 0.055,
    y = mean(unknown$A) + 0.115,
    label = sprintf(
      "Unknown\n%.3f mg/mL", mean(unknown$C)
    ),
    hjust = 1,
    size = 2.9,
    lineheight = 1.12,
    colour = "#51435C",
    family = "sans"
  )

key_b_x <- 0.64

p_b <- add_key(
  p_b, key_b_x, 0.205,
  "Standard 1-6",
  fill = grey_gradient[4],
  shape = 24,
  size = 2.5,
  stroke = 0.35
)

p_b <- add_key(
  p_b, key_b_x, 0.160,
  "Standard 1'-6'",
  fill = NA,
  edge = grey_gradient[4],
  shape = 21,
  size = 3.0,
  stroke = 0.75
)

p_b <- add_key(
  p_b, key_b_x, 0.115,
  "Unknown 7",
  fill = GREEN,
  shape = 22,
  size = 2.8,
  stroke = 0.45
)

p_b <- add_key(
  p_b, key_b_x, 0.070,
  "Unknown 7'",
  fill = PURPLE,
  shape = 23,
  size = 2.8,
  stroke = 0.45
)

p_b <- axis_scales(p_b) +
  labs(tag = "b") +
  paper_theme

# ================= c：残差柱图 =================
concentrations <- sort(unique(std$C))
std$ConcentrationGroup <- match(std$C, concentrations)

std$BarX <- std$ConcentrationGroup +
  ifelse(
    std$Operator == "Standard 1-6",
    -0.165,
    0.165
  )

# 下限抬高至 -0.0032；上限保持 0.005
res_limits <- c(-0.0032, 0.005)

if (any(
  std$Residual < res_limits[1] |
  std$Residual > res_limits[2]
)) {
  warning("部分残差超出指定显示范围，请调整 res_limits。")
}

p_c <- ggplot() +
  geom_col(
    data = std,
    aes(
      x = BarX,
      y = Residual,
      fill = PointColour
    ),
    width = 0.32,
    colour = NA
  ) +
  geom_hline(
    yintercept = 0,
    colour = "#70777B",
    linewidth = 0.45
  ) +
  scale_fill_identity() +
  scale_x_continuous(
    breaks = seq_along(concentrations),
    labels = sprintf("%.1f", concentrations),
    expand = expansion(mult = 0)
  ) +
  scale_y_continuous(
    breaks = c(-0.003, -0.001, 0, 0.001, 0.003, 0.005),
    labels = function(z) sprintf("%.3f", z),
    expand = expansion(mult = 0)
  ) +
  coord_cartesian(
    xlim = c(0.45, length(concentrations) + 0.55),
    ylim = res_limits
  ) +
  labs(
    x = "Protein concentration (mg/mL)",
    y = expression("Residual (" * plain(A)[280] * ")"),
    tag = "c"
  ) +
  paper_theme

p_c <- add_key(
  p_c,
  x = 3.75, y = 0.00455,
  label = "Standard 1-6",
  fill = blue_gradient[4],
  edge = blue_gradient[4],
  shape = 22,
  size = 2.7,
  stroke = 0.2,
  text_offset = 0.22
)

p_c <- add_key(
  p_c,
  x = 3.75, y = 0.00395,
  label = "Standard 1'-6'",
  fill = red_gradient[4],
  edge = red_gradient[4],
  shape = 22,
  size = 2.7,
  stroke = 0.2,
  text_offset = 0.22
)

# ================= 三联图排版 =================
draw_figure <- function() {
  grid.newpage()

  # 保留原面板布局；底部不绘制任何文字
  layout <- grid.layout(
    nrow = 3,
    ncol = 3,
    heights = unit.c(
      unit(0.55, "in"),
      unit(1, "null"),
      unit(0.38, "in")
    ),
    widths = unit(rep(1, 3), "null")
  )

  pushViewport(viewport(layout = layout))

  pushViewport(viewport(
    layout.pos.row = 1,
    layout.pos.col = 1:3
  ))

  grid.text(
    "Spectrophotometric assay",
    x = 0.5, y = 0.66,
    gp = gpar(
      fontfamily = "sans",
      fontsize = 15,
      col = TEXT
    )
  )

  grid.lines(
    x = unit(c(0.035, 0.985), "npc"),
    y = unit(c(0.20, 0.20), "npc"),
    gp = gpar(col = TEXT, lwd = 0.8)
  )

  popViewport()

  plots <- list(p_a, p_b, p_c)

  for (i in seq_along(plots)) {
    print(
      plots[[i]],
      newpage = FALSE,
      vp = viewport(
        layout.pos.row = 2,
        layout.pos.col = i
      )
    )
  }

  popViewport()
}

# ================= 预览与保存 =================
draw_figure()

save_figure <- function() {
  png(
    filename = OUTPUT_PNG,
    width = 11.7,
    height = 5.7,
    units = "in",
    res = 600,
    bg = "white"
  )

  on.exit(dev.off(), add = TRUE)
  draw_figure()
}

save_figure()

cat("\n三联图已保存:", OUTPUT_PNG, "\n")
cat("统计结果已保存:", OUTPUT_TXT, "\n")