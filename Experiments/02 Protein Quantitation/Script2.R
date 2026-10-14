library(ggplot2)
library(grid)

# ================= 文件 =================
INPUT <- "Data-BCA-14.10.26.csv"

if (!file.exists(INPUT)) {
  INPUT <- "Data-BCA-14.10.26(1).csv"
}
if (!file.exists(INPUT)) {
  stop("找不到 BCA 数据文件，请检查工作目录。")
}

OUTPUT_PNG <- "BCA-Assay-14.10.26.png"
OUTPUT_TXT <- "BCA-Assay-14.10.26.txt"

# ================= 读取 =================
input_lines <- readLines(INPUT, warn = FALSE)

raw <- read.csv(
  text = paste0(paste(input_lines, collapse = "\n"), "\n"),
  header = FALSE,
  fill = TRUE,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

if (nrow(raw) < 3 || ncol(raw) < 19) {
  stop("数据格式不符合预期：需要12个标准读数和6个未知读数。")
}

get_numbers <- function(row, columns) {
  suppressWarnings(as.numeric(
    unlist(raw[row, columns, drop = FALSE], use.names = FALSE)
  ))
}

std <- data.frame(
  C = get_numbers(2, 2:13),
  A_raw = get_numbers(3, 2:13),
  Operator = factor(
    rep(c("Standard 1-6", "Standard 1'-6'"), 6),
    levels = c("Standard 1-6", "Standard 1'-6'")
  ),
  Level = rep(1:6, each = 2)
)

unknown <- data.frame(
  Sample = c("7", "7'", "8", "8'", "9", "9'"),
  A_raw = get_numbers(3, 14:19),
  Dilution = rep(c(1, 2, 4), each = 2),
  Series = rep(c("Unprimed", "Primed"), 3)
)

if (
  any(!is.finite(std$C)) ||
  any(!is.finite(std$A_raw)) ||
  any(!is.finite(unknown$A_raw))
) {
  stop("数据含无效数值，请检查 CSV。")
}

# ================= 统一扣除平均空白 =================
blank_mean <- mean(std$A_raw[std$C == 0])

std$A <- std$A_raw - blank_mean
unknown$A <- unknown$A_raw - blank_mean

# 使用同一个平均空白，保留截距
# 不对每位操作者分别扣空白，以保留两套数据的相对差异

# ================= 拟合 =================
s1 <- std[std$Operator == "Standard 1-6", ]
s2 <- std[std$Operator == "Standard 1'-6'", ]

fit1 <- lm(A ~ C, data = s1)
fit2 <- lm(A ~ C, data = s2)
fit_all <- lm(A ~ C, data = std)

fit_parallel <- lm(A ~ C + Operator, data = std)
fit_interaction <- lm(A ~ C * Operator, data = std)
parallel_test <- anova(fit_parallel, fit_interaction)

# 二次项检查：只输出诊断，不自动替换图中的直线
fit_quad <- lm(A ~ C + I(C^2), data = std)
curvature_test <- anova(fit_all, fit_quad)

# 控制操作者截距和斜率后，再检查共同二次项
fit_interaction_quad <- lm(
  A ~ C * Operator + I(C^2),
  data = std
)
curvature_operator_test <- anova(
  fit_interaction, fit_interaction_quad
)

std$Residual <- residuals(fit_all)

# ================= 未知浓度 =================
# C_assayed：加显色剂前、已经预稀释的样品浓度
# C_original：乘回预稀释倍数后的原液浓度
unknown$C_assayed <- (
  unknown$A - coef(fit_all)[["(Intercept)"]]
) / coef(fit_all)[["C"]]

unknown$C_original <- unknown$C_assayed * unknown$Dilution

unknown$Within_response_range <- (
  unknown$A >= min(std$A) &
  unknown$A <= max(std$A)
)

unknown$Within_concentration_range <- (
  unknown$C_assayed >= min(std$C) &
  unknown$C_assayed <= max(std$C)
)

unknown$Within_range <- (
  unknown$Within_response_range &
  unknown$Within_concentration_range
)

unknown$Status <- ifelse(
  unknown$Within_range,
  "Within calibration range",
  "Extrapolation: exclude from final summary"
)

dilution_summary <- do.call(
  rbind,
  lapply(c(1, 2, 4), function(d) {
    z <- unknown[unknown$Dilution == d, ]

    data.frame(
      Dilution = d,
      N_readings = nrow(z),
      Mean_assayed = mean(z$C_assayed),
      Mean_original = mean(z$C_original),
      SD_original = sd(z$C_original),
      CV_percent = 100 * sd(z$C_original) /
        abs(mean(z$C_original)),
      All_within_range = all(z$Within_range)
    )
  })
)

# ================= 统计辅助函数 =================
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

# 原液、1/2、1/4：依次由深到浅
green_unknown <- c("#56875A", "#82B585", "#A5D6A7")
purple_unknown <- c("#77558B", "#9B7CAE", "#BCA0CC")

std$PointColour <- ifelse(
  std$Operator == "Standard 1-6",
  blue_gradient[std$Level],
  red_gradient[std$Level]
)
std$GreyColour <- grey_gradient[std$Level]

unknown$ShadeIndex <- match(unknown$Dilution, c(1, 2, 4))
unknown$Colour <- ifelse(
  unknown$Series == "Unprimed",
  green_unknown[unknown$ShadeIndex],
  purple_unknown[unknown$ShadeIndex]
)
unknown$Shape <- ifelse(unknown$Series == "Unprimed", 22, 23)

s1 <- std[std$Operator == "Standard 1-6", ]
s2 <- std[std$Operator == "Standard 1'-6'", ]

# ================= TXT 输出 =================
report <- capture.output({
  cat("BCA ASSAY: A562\n")
  cat("============================================\n\n")
  cat("Input:", INPUT, "\n")
  cat("Concentration unit: mg/mL\n")
  cat(sprintf("Mean blank A562 = %.8f\n", blank_mean))
  cat("The same mean blank is subtracted from all standards and unknowns.\n")
  cat("All calibration models retain an intercept.\n")
  cat("Figures d-f show LINEAR models.\n")
  cat("Unknown concentrations below are provisional linear estimates.\n\n")

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
      "Blank-corrected equation: A562 = %.8f * C %s %.8f\n",
      st[["slope"]],
      ifelse(st[["intercept"]] >= 0, "+", "-"),
      abs(st[["intercept"]])
    ))

    raw_intercept <- st[["intercept"]] + blank_mean
    cat(sprintf(
      "Raw-absorbance equation: A562_raw = %.8f * C %s %.8f\n",
      st[["slope"]],
      ifelse(raw_intercept >= 0, "+", "-"),
      abs(raw_intercept)
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
    cat("\n")
  }

  cat("============================================\n")
  cat("BETWEEN-OPERATOR SLOPE COMPARISON\n\n")
  print(parallel_test)

  interaction_name <- grep(
    ":", names(coef(fit_interaction)), value = TRUE
  )

  cat("\nSlope difference: second minus first operator\n")
  print(coef(summary(fit_interaction))[
    interaction_name, , drop = FALSE
  ])

  cat("95% confidence interval for slope difference:\n")
  print(confint(fit_interaction)[
    interaction_name, , drop = FALSE
  ])

  cat(sprintf(
    "\nRelative slope difference (symmetric) = %.4f%%\n",
    100 * abs(st1[["slope"]] - st2[["slope"]]) /
      mean(abs(c(st1[["slope"]], st2[["slope"]])))
  ))

  cat("Slope comparison assumes the linear model is adequate.\n")
  cat("Nonsignificance does not establish equivalence.\n")
  cat("Only one calibration preparation per operator is available.\n\n")

  cat("============================================\n")
  cat("MODEL CHECK: LINEAR VS QUADRATIC\n\n")
  cat("Combined standards:\n")
  print(curvature_test)

  cat("\nQuadratic model coefficients:\n")
  print(coef(summary(fit_quad)))
  cat("95% coefficient confidence intervals:\n")
  print(confint(fit_quad))

  q <- coef(fit_quad)
  cat(sprintf(
    "\nQuadratic equation: A562_corrected = %.8f + %.8f*C + %.8f*C^2\n",
    q[1], q[2], q[3]
  ))
  cat(sprintf(
    "Quadratic R-squared = %.9f\n",
    summary(fit_quad)$r.squared
  ))
  cat(sprintf(
    "Quadratic adjusted R-squared = %.9f\n",
    summary(fit_quad)$adj.r.squared
  ))

  cat("\nCommon curvature after allowing operator-specific intercepts and slopes:\n")
  print(curvature_operator_test)

  cat("\nThese are curvature checks, not proof of full method validity.\n")
  cat("No automatic model replacement or point deletion is performed.\n")
  cat("If curvature is supported, reconsider linear concentration estimates before final reporting.\n\n")

  cat("============================================\n")
  cat("UNKNOWN SAMPLE: LINEAR CALIBRATION\n\n")
  print(
    unknown[, c(
      "Sample", "A_raw", "A", "Dilution",
      "C_assayed", "C_original", "Within_range", "Status"
    )],
    row.names = FALSE
  )

  cat("\nDilution-specific summaries:\n")
  print(dilution_summary, row.names = FALSE)

  cat("\nC_assayed: diluted sample concentration before addition of BCA reagent.\n")
  cat("C_original = C_assayed * dilution factor (1, 2 or 4).\n")
  cat("No additional factor of 11 is applied: standards receive the same reagent dilution.\n")
  cat("Out-of-range results are extrapolations and must not enter the final concentration summary.\n")
  cat("Different dilutions are not independent biological samples.\n")
  cat("No pooled mean across all six readings is reported.\n")
  cat("BCA response slope is not the protein's A280 percent absorption coefficient.\n\n")

  cat("============================================\n")
  cat("STANDARD READINGS AND LINEAR RESIDUALS\n\n")
  print(
    std[, c("C", "A_raw", "A", "Operator", "Residual")],
    row.names = FALSE
  )

  cat("\nFIGURE NOTES\n")
  cat("d: Operator-specific linear calibrations.\n")
  cat("e: Combined linear calibration; grey standards and coloured unknown readings.\n")
  cat("Green squares: unprimed unknowns; purple diamonds: primed unknowns.\n")
  cat("Unknown shades identify dilution conditions; open symbols indicate extrapolation.\n")
  cat("The dashed extension beyond the standard range is extrapolation, not validated calibration.\n")
  cat("f: Individual residuals from the combined linear model.\n")
  cat("Figure P values test H0: slope = 0, not model adequacy.\n")
  cat("* P < 0.05; ** P < 0.01; *** P < 0.001; ns P >= 0.05.\n")
  cat("Standard concentration errors and shared preparation errors are not modelled.\n")
})

writeLines(report, OUTPUT_TXT)
cat(paste(report, collapse = "\n"), "\n")

# ================= 主题 =================
paper_theme <- theme_classic(
  base_size = 10, base_family = "sans"
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
    plot.tag = element_text(size = 13, face = "bold", colour = TEXT),
    plot.margin = margin(12, 13, 10, 9),
    legend.position = "none"
  )

# ================= 辅助函数 =================
add_standard_points <- function(p, grayscale = FALSE) {
  d1 <- s1
  d2 <- s2

  d1$DisplayColour <- if (grayscale) d1$GreyColour else d1$PointColour
  d2$DisplayColour <- if (grayscale) d2$GreyColour else d2$PointColour

  p +
    geom_point(
      data = d1, aes(C, A, fill = DisplayColour),
      shape = 24, size = 2.35, stroke = 0.35,
      colour = "white", inherit.aes = FALSE
    ) +
    geom_point(
      data = d2, aes(C, A, colour = DisplayColour),
      shape = 21, size = 2.4, stroke = 0.75,
      fill = NA, inherit.aes = FALSE
    ) +
    scale_fill_identity() +
    scale_colour_identity()
}

add_key <- function(
    p, x, y, label, fill = NA, edge = "white",
    shape = 21, size = 2.4, stroke = 0.65,
    text_offset = 0.012, text_size = 2.65
) {
  p +
    annotate(
      "point", x = x, y = y,
      shape = shape, size = size, stroke = stroke,
      fill = fill, colour = edge
    ) +
    annotate(
      "text", x = x + text_offset, y = y,
      label = label, hjust = 0, vjust = 0.5,
      size = text_size, family = "sans", colour = TEXT
    )
}

make_line <- function(model, from, to) {
  z <- data.frame(C = seq(from, to, length.out = 250))
  z$A <- as.numeric(predict(model, newdata = z))
  z
}

add_axes <- function(p, xlim, ylim, xbreaks, ybreaks) {
  p +
    scale_x_continuous(
      breaks = xbreaks,
      labels = function(z) sprintf("%.2f", z),
      expand = expansion(mult = 0)
    ) +
    scale_y_continuous(
      breaks = ybreaks,
      labels = function(z) sprintf("%.2f", z),
      expand = expansion(mult = 0)
    ) +
    coord_cartesian(xlim = xlim, ylim = ylim) +
    labs(
      x = "Protein concentration (mg/mL)",
      y = expression(plain(A)[562] ~ "(blank-corrected)")
    )
}

# ================= d：两人分别拟合 =================
line1 <- make_line(fit1, -0.003, 0.255)
line2 <- make_line(fit2, -0.003, 0.255)

p_d <- ggplot() +
  geom_line(
    data = line1, aes(C, A),
    colour = LINE_LIGHT, linewidth = 0.95,
    lineend = "round"
  ) +
  geom_line(
    data = line2, aes(C, A),
    colour = LINE, linewidth = 0.55,
    linetype = "dashed"
  )

p_d <- add_standard_points(p_d)

p_d <- p_d +
  annotate(
    "text", x = -0.003, y = 0.252,
    label = stats_expression(st1, "1-6:"),
    parse = TRUE, hjust = 0, size = 2.65,
    family = "sans", colour = BLUE
  ) +
  annotate(
    "text", x = -0.003, y = 0.232,
    label = stats_expression(st2, "1'-6':"),
    parse = TRUE, hjust = 0, size = 2.65,
    family = "sans", colour = RED_DARK
  )

p_d <- add_key(
  p_d, 0.150, 0.075, "Standard 1-6",
  fill = blue_gradient[4], shape = 24,
  size = 2.35, stroke = 0.35
)
p_d <- add_key(
  p_d, 0.150, 0.058, "Standard 1'-6'",
  edge = red_gradient[4], shape = 21, stroke = 0.75
)

p_d <- p_d +
  annotate(
    "segment", x = 0.144, xend = 0.156,
    y = 0.040, yend = 0.040,
    colour = LINE_LIGHT, linewidth = 0.95
  ) +
  annotate(
    "text", x = 0.162, y = 0.040,
    label = "Fit: 1-6", hjust = 0,
    size = 2.65, family = "sans", colour = TEXT
  ) +
  annotate(
    "segment", x = 0.144, xend = 0.156,
    y = 0.023, yend = 0.023,
    colour = LINE, linewidth = 0.55,
    linetype = "dashed"
  ) +
  annotate(
    "text", x = 0.162, y = 0.023,
    label = "Fit: 1'-6'", hjust = 0,
    size = 2.65, family = "sans", colour = TEXT
  )

p_d <- add_axes(
  p_d,
  xlim = c(-0.014, 0.270),
  ylim = c(-0.015, 0.270),
  xbreaks = seq(0, 0.25, 0.05),
  ybreaks = seq(0, 0.20, 0.05)
) +
  labs(tag = "d") +
  paper_theme

# ================= e：总体校准与未知点 =================
# 校准范围内：黑色实线
# 超出最高标准浓度：灰色虚线外推
line_all <- make_line(fit_all, 0, max(std$C))
x_unknown_max <- max(unknown$C_assayed)

p_e <- ggplot() +
  geom_line(
    data = line_all, aes(C, A),
    colour = LINE, linewidth = 0.65
  )

if (x_unknown_max > max(std$C)) {
  line_extra <- make_line(
    fit_all, max(std$C), x_unknown_max + 0.005
  )
  p_e <- p_e +
    geom_line(
      data = line_extra, aes(C, A),
      colour = "#92999E", linewidth = 0.55,
      linetype = "dashed"
    )
}

# 每个稀释条件用平均响应画一组插值辅助线
# 超范围的原液不画插值辅助线
for (d in c(1, 2, 4)) {
  z <- unknown[unknown$Dilution == d, ]
  if (all(z$Within_range)) {
    cx <- mean(z$C_assayed)
    ay <- mean(z$A)

    p_e <- p_e +
      annotate(
        "segment", x = cx, xend = cx,
        y = 0, yend = ay,
        colour = "#A1A7A3", linewidth = 0.3,
        linetype = "dotted"
      ) +
      annotate(
        "segment", x = 0, xend = cx,
        y = ay, yend = ay,
        colour = "#A1A7A3", linewidth = 0.3,
        linetype = "dotted"
      )
  }
}

p_e <- add_standard_points(p_e, grayscale = TRUE)

# 六个未知读数各自画在真实反算坐标上
for (i in seq_len(nrow(unknown))) {
  z <- unknown[i, ]
  p_e <- p_e +
    annotate(
      "point",
      x = z$C_assayed, y = z$A,
      shape = z$Shape,
      size = 2.8,
      stroke = if (z$Within_range) 0.45 else 0.75,
      fill = if (z$Within_range) z$Colour else NA,
      colour = if (z$Within_range) "white" else z$Colour
    )
}

p_e <- p_e +
  annotate(
    "text", x = -0.003, y = 0.330,
    label = stats_expression(sta),
    parse = TRUE, hjust = 0, size = 2.8,
    family = "sans", colour = TEXT
  ) +
  annotate(
    "text",
    x = mean(unknown$C_assayed[unknown$Dilution == 1]),
    y = max(unknown$A[unknown$Dilution == 1]) + 0.023,
    label = "Undiluted\nout of range",
    hjust = 0.5, size = 2.6, lineheight = 1.1,
    family = "sans", colour = "#65556E"
  )

# 图例：灰阶标准点
key_e_x <- 0.225

p_e <- add_key(
  p_e, key_e_x, 0.132, "Standard 1-6",
  fill = grey_gradient[4], shape = 24,
  size = 2.35, stroke = 0.35,
  text_offset = 0.017
)
p_e <- add_key(
  p_e, key_e_x, 0.112, "Standard 1'-6'",
  edge = grey_gradient[4], shape = 21,
  size = 2.4, stroke = 0.75,
  text_offset = 0.017
)

# 每行用绿色方块 + 紫色菱形表示一对未知读数
pair_key <- function(p, y, index, label, hollow = FALSE) {
  p +
    annotate(
      "point", x = key_e_x, y = y,
      shape = 22, size = 2.4,
      stroke = if (hollow) 0.65 else 0.4,
      fill = if (hollow) NA else green_unknown[index],
      colour = if (hollow) green_unknown[index] else "white"
    ) +
    annotate(
      "point", x = key_e_x + 0.017, y = y,
      shape = 23, size = 2.4,
      stroke = if (hollow) 0.65 else 0.4,
      fill = if (hollow) NA else purple_unknown[index],
      colour = if (hollow) purple_unknown[index] else "white"
    ) +
    annotate(
      "text", x = key_e_x + 0.032, y = y,
      label = label, hjust = 0,
      size = 2.5, family = "sans", colour = TEXT
    )
}

p_e <- pair_key(p_e, 0.087, 1, "7 / 7': neat", hollow = TRUE)
p_e <- pair_key(p_e, 0.065, 2, "8 / 8': 1/2")
p_e <- pair_key(p_e, 0.043, 3, "9 / 9': 1/4")

p_e <- add_axes(
  p_e,
  xlim = c(-0.020, max(0.40, x_unknown_max + 0.025)),
  ylim = c(-0.020, 0.350),
  xbreaks = seq(0, 0.40, 0.10),
  ybreaks = seq(0, 0.30, 0.10)
) +
  labs(tag = "e") +
  paper_theme

# ================= f：线性模型残差柱图 =================
concentrations <- sort(unique(std$C))
std$ConcentrationGroup <- match(std$C, concentrations)

std$BarX <- std$ConcentrationGroup +
  ifelse(std$Operator == "Standard 1-6", -0.165, 0.165)

# BCA 残差量级不同，不能照搬 A280 的纵轴范围
res_span <- diff(range(c(0, std$Residual)))
res_limits <- c(
  min(0, std$Residual) - 0.12 * res_span,
  max(0, std$Residual) + 0.45 * res_span
)

p_f <- ggplot() +
  geom_col(
    data = std,
    aes(BarX, Residual, fill = PointColour),
    width = 0.32, colour = NA
  ) +
  geom_hline(
    yintercept = 0,
    colour = "#70777B", linewidth = 0.45
  ) +
  scale_fill_identity() +
  scale_x_continuous(
    breaks = seq_along(concentrations),
    labels = sprintf("%.2f", concentrations),
    expand = expansion(mult = 0)
  ) +
  scale_y_continuous(
    breaks = pretty(res_limits, n = 5),
    labels = function(z) sprintf("%.3f", z),
    expand = expansion(mult = 0)
  ) +
  coord_cartesian(
    xlim = c(0.45, length(concentrations) + 0.55),
    ylim = res_limits
  ) +
  labs(
    x = "Protein concentration (mg/mL)",
    y = expression("Residual (" * plain(A)[562] * ")"),
    tag = "f"
  ) +
  paper_theme

legend_top <- res_limits[2] - 0.055 * diff(res_limits)
legend_step <- 0.085 * diff(res_limits)

p_f <- add_key(
  p_f, 3.75, legend_top, "Standard 1-6",
  fill = blue_gradient[4], edge = blue_gradient[4],
  shape = 22, size = 2.7, stroke = 0.2,
  text_offset = 0.22
)
p_f <- add_key(
  p_f, 3.75, legend_top - legend_step, "Standard 1'-6'",
  fill = red_gradient[4], edge = red_gradient[4],
  shape = 22, size = 2.7, stroke = 0.2,
  text_offset = 0.22
)

# ================= 三联图排版 =================
draw_figure <- function() {
  grid.newpage()

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
    "BCA method",
    x = 0.5, y = 0.66,
    gp = gpar(
      fontfamily = "sans", fontsize = 15, col = TEXT
    )
  )

  grid.lines(
    x = unit(c(0.035, 0.985), "npc"),
    y = unit(c(0.20, 0.20), "npc"),
    gp = gpar(col = TEXT, lwd = 0.8)
  )

  popViewport()

  plots <- list(p_d, p_e, p_f)
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
# ============================================================
# g：BCA 稀释一致性
# 柱高：乘回稀释倍数后的原液浓度均值
# 误差线：± SD（每组两个技术读数，不代表校准不确定度）
# 空心柱 / 空心点：超出标准范围的外推结果
# ============================================================

g_data <- unknown

g_data$Group <- match(
  g_data$Dilution,
  c(1, 2, 4)
)

# 两个读数左右轻微错开，纵坐标不变
g_data$PointX <- g_data$Group +
  ifelse(
    g_data$Series == "Unprimed",
    -0.075,
    0.075
  )

g_summary <- do.call(
  rbind,
  lapply(c(1, 2, 4), function(d) {
    z <- g_data[g_data$Dilution == d, ]

    data.frame(
      Dilution = d,
      Group = match(d, c(1, 2, 4)),
      N = nrow(z),
      Mean = mean(z$C_original),
      SD = sd(z$C_original),
      Within_range = all(z$Within_range)
    )
  })
)

# ================= 配色 =================

g_data$PointColour <- ifelse(
  g_data$Series == "Unprimed",
  "#7FAF82",
  "#9C7EB1"
)

g_data$PointFill <- ifelse(
  g_data$Within_range,
  g_data$PointColour,
  "white"
)

g_summary$BarFill <- ifelse(
  g_summary$Within_range,
  "#E1E5E8",
  "white"
)

# ================= 绘图 =================

p_g <- ggplot() +
  geom_col(
    data = g_summary,
    aes(
      x = Group,
      y = Mean,
      fill = BarFill
    ),
    width = 0.56,
    colour = "#858D93",
    linewidth = 0.55
  ) +
  geom_errorbar(
    data = g_summary,
    aes(
      x = Group,
      ymin = Mean - SD,
      ymax = Mean + SD
    ),
    width = 0.13,
    linewidth = 0.5,
    colour = "#555D63"
  ) +
  geom_point(
    data = g_data,
    aes(
      x = PointX,
      y = C_original,
      shape = Series,
      colour = PointColour,
      fill = PointFill
    ),
    size = 2.8,
    stroke = 0.65
  ) +
  scale_shape_manual(
    values = c(
      "Unprimed" = 22,
      "Primed" = 23
    )
  ) +
  scale_colour_identity() +
  scale_fill_identity() +
  geom_text(
    data = g_summary,
    aes(
      x = Group,
      y = Mean - 0.045,
      label = sprintf("%.3f", Mean)
    ),
    colour = "#454C52",
    size = 2.9,
    family = "sans"
  ) +
  scale_x_continuous(
    breaks = 1:3,
    labels = c("Undiluted", "1/2", "1/4"),
    expand = expansion(mult = 0)
  ) +
  scale_y_continuous(
    breaks = seq(0, 0.5, 0.1),
    labels = function(z) sprintf("%.1f", z),
    expand = expansion(mult = 0)
  ) +
  coord_cartesian(
    xlim = c(0.45, 3.55),
    ylim = c(0, 0.50)
  ) +
  labs(
    x = "Sample dilution",
    y = "Original protein concentration (mg/mL)",
    tag = "g"
  ) +
  paper_theme

# 标记外推组，文字放在误差线和散点上方
g_extrapolated <- g_summary[
  !g_summary$Within_range,
  ,
  drop = FALSE
]

if (nrow(g_extrapolated) > 0) {
  g_extrapolated$LabelY <- vapply(
    seq_len(nrow(g_extrapolated)),
    function(i) {
      z <- g_extrapolated[i, ]

      max(
        z$Mean + z$SD,
        g_data$C_original[
          g_data$Dilution == z$Dilution
        ]
      ) + 0.022
    },
    numeric(1)
  )

  p_g <- p_g +
    geom_text(
      data = g_extrapolated,
      aes(
        x = Group,
        y = LabelY
      ),
      label = "Extrapolated",
      size = 2.65,
      colour = "#756781",
      family = "sans",
      inherit.aes = FALSE
    )
}

# ================= 图内图例 =================

p_g <- add_key(
  p_g,
  x = 0.85, y = 0.475,
  label = "7\u20139",
  fill = "#7FAF82",
  edge = "#7FAF82",
  shape = 22,
  size = 2.6,
  stroke = 0.5,
  text_offset = 0.14
)

p_g <- add_key(
  p_g,
  x = 2.10, y = 0.475,
  label = "7\u2032\u20139\u2032",
  fill = "#9C7EB1",
  edge = "#9C7EB1",
  shape = 23,
  size = 2.6,
  stroke = 0.5,
  text_offset = 0.14
)

# ================= 预览与保存 =================

print(p_g)

ggsave(
  filename = "BCA-Dilution-Consistency-14.10.26.png",
  plot = p_g,
  width = 4.1,
  height = 5.3,
  units = "in",
  dpi = 600,
  bg = "white"
)

g_report <- capture.output({
  cat("BCA DILUTION CONSISTENCY: PANEL g\n")
  cat("============================================\n\n")
  cat("Concentrations are calculated using the combined linear calibration.\n")
  cat("Original concentration = assayed concentration * dilution factor.\n")
  cat("Unit: mg/mL\n")
  cat("Bars: arithmetic means; error bars: +/- sample SD.\n")
  cat("Points: two technical readings per dilution condition.\n")
  cat("SD does not include calibration uncertainty.\n")
  cat("Open bars and points indicate extrapolation.\n")
  cat("Extrapolated results are displayed only, not included in a final concentration summary.\n")
  cat("No significance tests are performed.\n\n")

  print(
    g_summary[, c(
      "Dilution", "N", "Mean", "SD", "Within_range"
    )],
    row.names = FALSE
  )
})

writeLines(
  g_report,
  "BCA-Dilution-Consistency-14.10.26.txt"
)

cat(paste(g_report, collapse = "\n"), "\n")
cat("\n图已保存：BCA-Dilution-Consistency-14.10.26.png\n")
cat("统计结果已保存：BCA-Dilution-Consistency-14.10.26.txt\n")