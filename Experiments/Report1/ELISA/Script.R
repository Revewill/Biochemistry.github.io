# ============================================================
# ELISA v5
# 追加到 v4 末尾运行
#
# 更新：
# b 色标位置
# c/f 使用 dilution denominator
# d 恢复散点
# e 总体 P + 跨组横线
# g 使用 #F2A0A0
# 恢复并更新 CSV/TXT 输出
# ============================================================

required_v5 <- c(
  "std", "plate", "selected", "scores",
  "unknown", "cv_global_p", "cv_test_summary",
  "p_a", "p_g", "cv_data", "blocking_export"
)

missing_v5 <- required_v5[
  !vapply(required_v5, exists, logical(1))
]

if (length(missing_v5)) {
  stop(
    "请先运行 v3 和 v4。缺少对象：",
    paste(missing_v5, collapse = ", ")
  )
}

# ---------- 1. 改用相对原液含量及稀释分母 ----------
#
# v3/v4 的内部横坐标为 1000/D。
# 以下仅作等价坐标变换，保留原拟合结果；
# 对外输出不再报告 ug/mL。
#
# relative_fraction = 1 / dilution denominator
#
# 即使原液绝对浓度未知，
# 仍然可以报告相对于同一原液的等效稀释倍数。

NOMINAL_DENOMINATOR <- 2000

standard_denominators <- c(
  400, 800, 1600, 3200, 6400, 12800
)

std$denominator <- standard_denominators[
  std$col - 1
]

std$relative_fraction <- 1 / std$denominator

unknown$estimated_fraction <- (
  unknown$estimated_conc / 1000
)

unknown$estimated_denominator <- (
  1 / unknown$estimated_fraction
)

unknown$recovery_percent <- (
  100 *
    unknown$estimated_fraction /
    (1 / NOMINAL_DENOMINATOR)
)

mean_denominator <- mean(
  unknown$estimated_denominator
)

sd_denominator <- sd(
  unknown$estimated_denominator
)

cv_denominator <- (
  100 * sd_denominator / mean_denominator
)

recovery_relative <- mean(
  unknown$recovery_percent
)

# 注意：平均倒数不等于均值的倒数。
equivalent_denominator_of_mean_fraction <- (
  1 / mean(unknown$estimated_fraction)
)

# 用稀释分母预测原模型。
predict_denominator <- function(D) {
  predict_model(selected, 1000 / D)
}

# ---------- 2. b：独立外置色标 ----------

p_b <- ggplot(
  plate,
  aes(col, yy)
) +
  geom_point(
    shape = 21,
    size = 4.3,
    fill = "#F5F7F8",
    colour = "#D9E0E5",
    stroke = 0.35
  ) +
  geom_point(
    data = subset(plate, active),
    aes(fill = raw),
    shape = 21,
    size = 4.3,
    colour = "#84745D",
    stroke = 0.35
  ) +
  scale_fill_gradientn(
    colours = orange_palette,
    limits = heat_limits,
    name = expression(A[490])
  ) +
  scale_x_continuous(
    breaks = 1:12,
    position = "top",
    limits = c(0.4, 12.6),
    expand = expansion(mult = c(0, 0))
  ) +
  scale_y_continuous(
    breaks = 1:8,
    labels = rev(LETTERS[1:8]),
    limits = c(0.4, 8.6),
    expand = expansion(mult = c(0, 0))
  ) +
  coord_fixed() +
  labs(
    title = "Plate overview",
    x = NULL,
    y = NULL
  ) +
  guides(
    fill = guide_colourbar(
      barheight = grid::unit(2.1, "cm"),
      barwidth = grid::unit(0.32, "cm")
    )
  ) +
  theme(
    axis.line = element_blank(),
    axis.ticks = element_blank(),

    plot.title = element_text(
      margin = margin(
        t = 0, r = 0, b = 10, l = 20
      )
    ),

    legend.position = "right",
    legend.justification = "center",
    legend.box.spacing = grid::unit(1.5, "mm"),
    legend.margin = margin(0, 0, 0, 0),
    legend.background = element_blank(),
    legend.title = element_text(size = 9),
    legend.text = element_text(size = 8)
  )

p_b <- tag_panel(p_b, "b")

# ---------- 3. c：横轴改为 dilution denominator ----------
#
# 使用普通数值轴，坐标间距对应实际稀释分母。
# 不把不等距数字伪装成等距连续变量。
# 曲线方向自然变为随稀释分母增大而下降。

standard_summary <- subset(
  group_summary,
  col %in% 2:7
)

standard_summary$denominator <- (
  standard_denominators
)

curve_dilution <- data.frame(
  denominator = exp(
    seq(
      log(400),
      log(12800),
      length.out = 600
    )
  )
)

curve_dilution$y <- predict_denominator(
  curve_dilution$denominator
)

cal_legend_col <- c(
  row_col,
  "Sample A" = "#E7B900",
  "Fitted curve" = blue,
  "Nominal A" = nominal_col
)

curve_ymax <- max(
  std$y,
  standard_summary$mean_corrected +
    standard_summary$SD_raw
)

p_c <- ggplot(
  std,
  aes(denominator, y)
) +
  geom_line(
    data = curve_dilution,
    aes(colour = "Fitted curve"),
    linewidth = 0.95,
    key_glyph = "path"
  ) +
  geom_errorbar(
    data = standard_summary,
    aes(
      y = mean_corrected,
      ymin = mean_corrected - SD_raw,
      ymax = mean_corrected + SD_raw
    ),
    width = 100,
    colour = "#A0AAB1",
    linewidth = 0.45,
    show.legend = FALSE
  ) +
  geom_point(
    aes(
      colour = row,
      shape = row
    ),
    size = 2.5,
    stroke = 0.75
  ) +
  geom_vline(
    aes(
      xintercept = NOMINAL_DENOMINATOR,
      colour = "Nominal A"
    ),
    linetype = "dashed",
    linewidth = 0.5,
    key_glyph = "path"
  ) +
  geom_point(
    data = unknown,
    aes(
      x = estimated_denominator,
      y = corrected,
      colour = "Sample A",
      shape = "Sample A"
    ),
    inherit.aes = FALSE,
    size = 3.6
  ) +
  scale_colour_manual(
    values = cal_legend_col,
    breaks = names(cal_legend_col)
  ) +
  scale_shape_manual(
    values = c(
      row_shape,
      "Sample A" = 18
    )
  ) +
  scale_x_continuous(
    breaks = c(
      0, 2000, 4000, 8000, 12000
    ),
    limits = c(0, 13400),
    expand = expansion(mult = c(0.01, 0))
  ) +
  scale_y_continuous(
    limits = c(
      min(std$y) - 0.04,
      curve_ymax + 0.13
    ),
    expand = expansion(mult = c(0, 0))
  ) +
  annotate(
    "text",
    x = 6700,
    y = curve_ymax + 0.065,
    label = sprintf(
      "italic(R)^2 == %.4f",
      selected_R2
    ),
    parse = TRUE,
    hjust = 0.5,
    size = 3.5,
    colour = ink
  ) +
  annotate(
    "text",
    x = 6700,
    y = curve_ymax + 0.005,
    label = sprintf(
      "italic(P) == %.4f",
      trend_test$p.value
    ),
    parse = TRUE,
    hjust = 0.5,
    size = 3.5,
    colour = ink
  ) +
  labs(
    title = paste0(
      "Calibration — ",
      selected$type
    ),
    x = "Dilution denominator",
    y = expression(
      "Blank-corrected " * A[490]
    )
  ) +
  guides(
    shape = "none",
    colour = guide_legend(
      nrow = 2,
      byrow = TRUE,
      override.aes = list(
        shape = c(16, 17, 1, 18, NA, NA),
        linetype = c(0, 0, 0, 0, 1, 2),
        linewidth = c(0, 0, 0, 0, 0.8, 0.5)
      )
    )
  ) +
  theme(
    legend.position = "bottom",
    legend.text = element_text(size = 8)
  )

p_c <- tag_panel(p_c, "c")

# ---------- 4. d：恢复散点残差 ----------

residual_limit <- max(
  abs(std$residual)
) * 1.20

p_d <- ggplot(
  std,
  aes(
    dilution,
    residual,
    colour = row,
    shape = row
  )
) +
  geom_hline(
    yintercept = 0,
    colour = "#AAB5BC",
    linewidth = 0.45
  ) +
  geom_point(
    position = position_dodge(width = 0.42),
    size = 2.7,
    stroke = 0.8
  ) +
  scale_colour_manual(values = row_col) +
  scale_shape_manual(values = row_shape) +
  scale_y_continuous(
    limits = c(
      -residual_limit,
      residual_limit
    ),
    expand = expansion(mult = c(0, 0))
  ) +
  labs(
    title = "Calibration residuals",
    x = "Dilution denominator",
    y = expression(
      "Observed - fitted " * A[490]
    )
  ) +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(
      angle = 35,
      hjust = 1
    )
  )

p_d <- tag_panel(p_d, "d")

# ---------- 5. e：跨全部柱子的横线与 P ----------

cv_line_y <- max(cv_data$CV_raw) * 1.16
cv_text_y <- cv_line_y + 0.85
cv_top <- cv_text_y + 1.1

p_e <- ggplot(
  cv_data,
  aes(
    group,
    CV_raw,
    fill = mean_raw
  )
) +
  geom_col(
    width = 0.62,
    colour = NA
  ) +
  geom_text(
    aes(
      label = sprintf("%.1f", CV_raw)
    ),
    vjust = -0.55,
    size = 3.1,
    colour = ink
  ) +
  scale_fill_gradientn(
    colours = orange_palette,
    limits = heat_limits,
    guide = "none"
  ) +
  annotate(
    "segment",
    x = 0.7,
    xend = 7.3,
    y = cv_line_y,
    yend = cv_line_y,
    linewidth = 0.4,
    colour = axis_col
  ) +
  annotate(
    "text",
    x = 4,
    y = cv_text_y,
    label = sprintf(
      "italic(P) == %.3f",
      cv_global_p
    ),
    parse = TRUE,
    size = 3.3,
    colour = ink
  ) +
  scale_y_continuous(
    limits = c(0, cv_top),
    expand = expansion(mult = c(0, 0))
  ) +
  labs(
    title = "Within-condition repeatability",
    x = "Dilution denominator / sample",
    y = "Raw absorbance CV (%)"
  ) +
  theme(
    axis.text.x = element_text(
      angle = 40,
      hjust = 1
    )
  )

p_e <- tag_panel(p_e, "e")

# ---------- 6. f：稀释分母的理论值与实测值 ----------
#
# Measured：
# 三孔分别转换为稀释分母，然后计算 mean ± SD。
#
# Recovery：
# 基于相对抗体含量 1/D 计算，
# 不是 mean(D)/2000。

recovery_dilution <- data.frame(
  group = factor(
    c("Theoretical", "Measured"),
    levels = c("Theoretical", "Measured")
  ),
  denominator = c(
    NOMINAL_DENOMINATOR,
    mean_denominator
  ),
  SD = c(
    NA_real_,
    sd_denominator
  )
)

f_top <- max(
  NOMINAL_DENOMINATOR,
  mean_denominator + sd_denominator
) * 1.36

p_f <- ggplot(
  recovery_dilution,
  aes(
    group,
    denominator,
    fill = group
  )
) +
  geom_col(
    width = 0.55,
    colour = NA
  ) +
  geom_errorbar(
    data = subset(
      recovery_dilution,
      group == "Measured"
    ),
    aes(
      ymin = denominator - SD,
      ymax = denominator + SD
    ),
    width = 0.17,
    colour = axis_col,
    linewidth = 0.55
  ) +
  annotate(
    "text",
    x = 1.5,
    y = f_top * 0.93,
    label = sprintf(
      "Recovery = %.1f%%",
      recovery_relative
    ),
    size = 3.3,
    colour = ink
  ) +
  scale_fill_manual(
    values = c(
      Theoretical = pale_blue,
      Measured = pale_purple
    )
  ) +
  scale_y_continuous(
    limits = c(0, f_top),
    expand = expansion(mult = c(0, 0))
  ) +
  labs(
    title = "Sample A recovery",
    x = NULL,
    y = "Dilution denominator"
  ) +
  theme(
    legend.position = "none",
    axis.text.x = element_text(size = 9)
  )

p_f <- tag_panel(p_f, "f")

# ---------- 7. g：更换 Unblocked 的红色 ----------

p_g <- p_g +
  scale_fill_manual(
    values = c(
      Blocked = pale_green,
      Unblocked = "#F2A0A0"
    )
  )

# ============================================================
# 最终排版与导出
# 替换 v5 第 8 节及其后的全部代码
# ============================================================

# ---------- c：相对浓度坐标，刻度显示稀释比例 ----------
#
# 数值坐标 = 1 / dilution denominator
# 刻度文字 = 1:12800、1:6400……
# 不使用 ug/mL，不需要知道原液绝对浓度。
#
# 左侧稀：1:12800
# 右侧浓：1:400
# 刻度间距由真实相对浓度决定，不是等距分类轴。

std$relative_fraction <- 1 / std$denominator

standard_summary <- subset(
  group_summary,
  col %in% 2:7
)

standard_summary$denominator <- c(
  400, 800, 1600, 3200, 6400, 12800
)

standard_summary$relative_fraction <- (
  1 / standard_summary$denominator
)

unknown$estimated_fraction <- (
  1 / unknown$estimated_denominator
)

nominal_fraction <- 1 / NOMINAL_DENOMINATOR

curve_fraction <- data.frame(
  relative_fraction = seq(
    1 / 12800,
    1 / 400,
    length.out = 600
  )
)

# 与已有拟合完全等价，仅转换绘图坐标。
curve_fraction$y <- predict_denominator(
  1 / curve_fraction$relative_fraction
)

tick_denominators <- c(
  12800, 6400, 3200, 1600, 800, 400
)

tick_positions <- 1 / tick_denominators
tick_labels <- paste0("1:", tick_denominators)

cal_legend_col <- c(
  row_col,
  "Sample A" = "#E7B900",
  "Fitted curve" = blue,
  "Nominal A" = nominal_col
)

curve_ymax <- max(
  std$y,
  standard_summary$mean_corrected +
    standard_summary$SD_raw
)

p_c <- ggplot(
  std,
  aes(relative_fraction, y)
) +
  geom_line(
    data = curve_fraction,
    aes(colour = "Fitted curve"),
    linewidth = 0.95,
    key_glyph = "path"
  ) +
  geom_errorbar(
    data = standard_summary,
    aes(
      y = mean_corrected,
      ymin = mean_corrected - SD_raw,
      ymax = mean_corrected + SD_raw
    ),
    width = 0.000025,
    colour = "#A0AAB1",
    linewidth = 0.45,
    show.legend = FALSE
  ) +
  geom_point(
    aes(
      colour = row,
      shape = row
    ),
    size = 2.5,
    stroke = 0.75
  ) +
  geom_vline(
    aes(
      xintercept = nominal_fraction,
      colour = "Nominal A"
    ),
    linetype = "dashed",
    linewidth = 0.5,
    key_glyph = "path"
  ) +
  geom_point(
    data = unknown,
    aes(
      x = estimated_fraction,
      y = corrected,
      colour = "Sample A",
      shape = "Sample A"
    ),
    inherit.aes = FALSE,
    size = 3.6
  ) +
  scale_colour_manual(
    values = cal_legend_col,
    breaks = names(cal_legend_col)
  ) +
  scale_shape_manual(
    values = c(
      row_shape,
      "Sample A" = 18
    )
  ) +
  scale_x_continuous(
    breaks = tick_positions,
    labels = tick_labels,
    limits = c(0, 0.00265),
    expand = expansion(mult = c(0.01, 0)),
    guide = guide_axis(
      angle = 60,
      check.overlap = FALSE
    )
  ) +
  scale_y_continuous(
    limits = c(
      min(std$y) - 0.04,
      curve_ymax + 0.13
    ),
    expand = expansion(mult = c(0, 0))
  ) +
  annotate(
    "text",
    x = 0.00125,
    y = curve_ymax + 0.065,
    label = sprintf(
      "italic(R)^2 == %.4f",
      selected_R2
    ),
    parse = TRUE,
    hjust = 0.5,
    size = 3.5,
    colour = ink
  ) +
  annotate(
    "text",
    x = 0.00125,
    y = curve_ymax + 0.005,
    label = sprintf(
      "italic(P) == %.4f",
      trend_test$p.value
    ),
    parse = TRUE,
    hjust = 0.5,
    size = 3.5,
    colour = ink
  ) +
  labs(
    title = paste0(
      "Calibration — ",
      selected$type
    ),
    x = "Primary antibody dilution (relative concentration)",
    y = expression(
      "Blank-corrected " * A[490]
    )
  ) +
  guides(
    shape = "none",
    colour = guide_legend(
      nrow = 2,
      byrow = TRUE,
      override.aes = list(
        shape = c(16, 17, 1, 18, NA, NA),
        linetype = c(0, 0, 0, 0, 1, 2),
        linewidth = c(0, 0, 0, 0, 0.8, 0.5)
      )
    )
  ) +
  theme(
    legend.position = "bottom",
    legend.text = element_text(size = 8),
    axis.text.x = element_text(size = 8)
  )

p_c <- tag_panel(p_c, "c")

# ---------- 2. 重新拼图 ----------

top_row <- wrap_plots(
  p_a,
  p_b,
  nrow = 1,
  widths = c(1, 1),
  guides = "keep"
)

middle_row <- wrap_plots(
  p_c,
  p_d,
  nrow = 1,
  widths = c(1, 1),
  guides = "keep"
)

bottom_row <- wrap_plots(
  p_e,
  p_f,
  p_g,
  nrow = 1,
  widths = c(3, 2, 2),
  guides = "keep"
)

figure <- wrap_plots(
  top_row,
  middle_row,
  bottom_row,
  ncol = 1,
  heights = c(0.90, 1.15, 0.95),
  guides = "keep"
)

# ---------- 3. 最终文件保存位置 ----------
# 直接保存到当前 R 工作目录，不创建子文件夹。

FINAL_DIR <- getwd()
DATE_LABEL <- "28.10.26"

final_path <- function(name, extension) {
  file.path(
    FINAL_DIR,
    paste0(
      name,
      "-",
      DATE_LABEL,
      ".",
      extension
    )
  )
}

write_final_csv <- function(data, name) {
  write.csv(
    data,
    final_path(name, "csv"),
    row.names = FALSE
  )
}

# ---------- 4. 保存唯一 TIFF 总图 ----------

figure_path <- final_path(
  "ELISA-Figure",
  "tiff"
)

if (requireNamespace("ragg", quietly = TRUE)) {

  ragg::agg_tiff(
    filename = figure_path,
    width = FIG_WIDTH,
    height = FIG_HEIGHT,
    units = "in",
    res = FIG_DPI,
    compression = "lzw",
    background = "white"
  )

} else {

  grDevices::tiff(
    filename = figure_path,
    width = FIG_WIDTH,
    height = FIG_HEIGHT,
    units = "in",
    res = FIG_DPI,
    compression = "lzw",
    bg = "white"
  )
}

tryCatch(
  print(figure),
  finally = grDevices::dev.off()
)

# 使用 R 自带设备导出 SVG，无需下载任何包
svg_path <- final_path("ELISA-Figure", "svg")

grDevices::svg(
  filename = svg_path,
  width = FIG_WIDTH,
  height = FIG_HEIGHT,
  family = FONT,
  bg = "white",
  onefile = TRUE
)

tryCatch(
  print(figure),
  finally = grDevices::dev.off()
)

message(
  "SVG 已保存：",
  normalizePath(svg_path, mustWork = TRUE)
)

# ---------- 5. 整理分析结果 ----------
# 不导出 96 孔原始数据或单独的对照原始读数表。

standard_results <- std[, c(
  "well",
  "row",
  "denominator",
  "relative_fraction",
  "corrected",
  "fitted",
  "residual"
)]

sample_results <- unknown[, c(
  "well",
  "row",
  "corrected",
  "estimated_fraction",
  "estimated_denominator",
  "recovery_percent"
)]

sample_summary <- data.frame(
  nominal_denominator = NOMINAL_DENOMINATOR,

  mean_denominator = mean_denominator,

  SD_denominator = sd_denominator,

  CV_denominator_percent = cv_denominator,

  denominator_of_mean_relative_fraction =
    equivalent_denominator_of_mean_fraction,

  mean_relative_fraction =
    mean(unknown$estimated_fraction),

  SD_relative_fraction =
    sd(unknown$estimated_fraction),

  CV_relative_fraction_percent =
    100 *
    sd(unknown$estimated_fraction) /
    mean(unknown$estimated_fraction),

  recovery_percent = recovery_relative,

  relative_content_bias_percent =
    recovery_relative - 100
)

# ---------- 6. 模型转换为稀释分母 D 的公式 ----------

a_fit <- unname(selected$coef[1])
b_fit <- unname(selected$coef[2])

if (selected$type == "Log") {

  dilution_parameters <- c(
    a = a_fit + b_fit * log(1000),
    b = b_fit
  )

  dilution_equation <- "y = a - b*ln(D)"

} else if (selected$type == "Hyperbola") {

  dilution_parameters <- c(
    a = a_fit,
    b = b_fit,
    k = exp(selected$q[1]) / 1000
  )

  dilution_equation <- "y = a + b/(1 + k*D)"

} else if (selected$type == "Power") {

  dilution_parameters <- c(
    a = a_fit,
    b = b_fit * 1000^selected$q[1],
    q = selected$q[1]
  )

  dilution_equation <- "y = a + b*D^(-q)"

} else if (selected$type == "Exponential saturation") {

  dilution_parameters <- c(
    a = a_fit,
    b = b_fit,
    k = 1000 / exp(selected$q[1])
  )

  dilution_equation <- "y = a + b*(1 - exp(-k/D))"

} else {

  dilution_parameters <- c(
    a = a_fit,
    b = b_fit,
    k = exp(selected$q[1]) / 1000,
    h = exp(selected$q[2])
  )

  dilution_equation <- "y = a + b/(1 + (k*D)^h)"
}

model_parameters <- data.frame(
  model = selected$type,
  parameter = names(dilution_parameters),
  estimate = unname(dilution_parameters),
  equation = dilution_equation
)

# ---------- 7. 保存结果 CSV ----------
# 文件名不带编号、版本号或下划线。

write_final_csv(
  scores,
  "Model-Comparison"
)

write_final_csv(
  model_parameters,
  "Selected-Model-Parameters"
)

write_final_csv(
  standard_results,
  "Standard-Fit-and-Residuals"
)

write_final_csv(
  sample_results,
  "Sample-A-Backcalculation"
)

write_final_csv(
  sample_summary,
  "Sample-A-Summary"
)

write_final_csv(
  group_summary,
  "Group-Summary-and-CV"
)

write_final_csv(
  cv_test_summary,
  "Global-CV-Test"
)

write_final_csv(
  blocking_export,
  "Blocking-Comparison"
)

# ---------- 8. 保存完整分析 TXT ----------

analysis_text <- capture.output({

  cat("ELISA | 28.10.26\n")
  cat("========================\n\n")

  cat("INPUT\n")
  cat(normalizePath(INPUT_FILE), "\n\n")

  cat("UNITS\n")
  cat(
    "D denotes the dilution denominator.\n",
    "Relative antibody fraction = 1/D.\n",
    "No absolute antibody concentration is reported.\n",
    "Panel c uses a linear relative-concentration axis (1/D), labelled as dilution ratios.\n",
    "The curve is drawn only within the measured standard range.\n",
    sep = ""
  )

  cat("BACKGROUND CORRECTION\n")
  cat(sprintf(
    "No-primary mean = %.8f; SD = %.8f; n = 3.\n",
    background_mean,
    background_sd
  ))

  cat(
    "The common no-primary mean is subtracted from standards and sample A.\n",
    "No-antigen and no-blocking controls are not additionally subtracted.\n\n",
    sep = ""
  )

  cat("MODEL COMPARISON\n")
  print(
    scores,
    row.names = FALSE,
    digits = 7
  )

  cat(
    "\nSelected model:",
    selected$type,
    "\n"
  )

  cat(
    "Selection uses stable leave-one-concentration-level-out response RMSE.\n",
    "Sample A was excluded from model fitting and selection.\n",
    "AICc omits a common Gaussian constant.\n",
    "R2 = 1 - RSS/TSS and is descriptive for nonlinear models.\n\n",
    sep = ""
  )

  cat("SELECTED MODEL IN DILUTION COORDINATES\n")
  cat(dilution_equation, "\n")
  cat("y denotes background-corrected A490.\n")

  print(
    model_parameters,
    row.names = FALSE,
    digits = 8
  )

  cat("\nCALIBRATION ASSOCIATION TEST\n")
  print(trend_test)

  cat(
    "The displayed two-sided P tests monotonic association across six level means.\n",
    "It is not a test of nonlinear-model goodness of fit.\n",
    "Replacing relative content with dilution denominator reverses the association\n",
    "sign but leaves this two-sided P value unchanged.\n\n",
    sep = ""
  )

  cat("STANDARD FIT AND RESIDUALS\n")
  print(
    standard_results,
    row.names = FALSE,
    digits = 7
  )

  cat("\nSAMPLE A: INDIVIDUAL BACKCALCULATIONS\n")
  print(
    sample_results,
    row.names = FALSE,
    digits = 7
  )

  cat("\nSAMPLE A: SUMMARY\n")
  print(
    sample_summary,
    row.names = FALSE,
    digits = 7
  )

  cat(
    "\nPanel f shows the mean and sample SD of individual dilution-denominator estimates.\n",
    "Mean(1/D) is not equal to 1/mean(D).\n",
    "Recovery = mean[(1/D_estimated)/(1/2000)] * 100.\n",
    "Recovery is therefore not calculated from the ratio of the two bar heights.\n",
    "The nominal value has no assigned uncertainty bar.\n",
    "Measured SD describes technical-well spread, not total calibration uncertainty.\n\n",
    sep = ""
  )

  cat("GROUP SUMMARY AND REPEATABILITY\n")
  print(
    group_summary,
    row.names = FALSE,
    digits = 7
  )

  cat(
    "\nRaw CV = sample SD/raw group mean * 100.\n",
    "A common background subtraction leaves within-group SD unchanged.\n",
    "Panel e colours represent mean raw A490 using the panel b colour scale.\n\n",
    sep = ""
  )

  cat("GLOBAL EQUALITY-OF-CV TEST\n")
  print(
    cv_test_summary,
    row.names = FALSE,
    digits = 7
  )

  cat(
    "\nExploratory normal-model likelihood-ratio test calibrated by parametric bootstrap.\n",
    "H0: the six standard groups and sample A have equal population CVs.\n",
    "Group means may differ under both hypotheses.\n",
    "Independent normal technical wells are assumed; each group contains only three wells.\n",
    "Non-significance does not establish equivalence or good repeatability.\n",
    "No pairwise CV comparisons or tests against zero CV were performed.\n\n",
    sep = ""
  )

  cat("BLOCKING COMPARISON\n")
  print(
    blocking_export,
    row.names = FALSE,
    digits = 7
  )

  cat(
    "\nExploratory Welch test assumes independent technical wells.\n",
    "No row pairing is assumed.\n",
    "This comparison concerns total signal, not isolated nonspecific binding.\n",
    "Non-significance does not establish that blocking has no effect.\n\n",
    sep = ""
  )

  cat("FIGURE PANELS\n")
  cat(
    "a: blank space for the experimental schematic.\n",
    "b: raw plate map with a separate local colour scale.\n",
    "c: calibration against relative concentration (1/D), labelled as dilution ratios; yellow diamonds show A.\n",
    "d: individual standard residuals.\n",
    "e: raw CV bars and global equality-of-CV P value.\n",
    "f: nominal vs measured dilution denominator; measured error bar is SD.\n",
    "g: blocked vs unblocked means +/- SD with Welch P.\n\n",
    sep = ""
  )

  cat("OUTPUT FILES\n")
  cat(
    "ELISA-Figure-28.10.26.tiff: complete lossless figure.\n",
    "Model-Comparison-28.10.26.csv: comparison of candidate models.\n",
    "Selected-Model-Parameters-28.10.26.csv: selected equation and parameters.\n",
    "Standard-Fit-and-Residuals-28.10.26.csv: standard predictions and residuals.\n",
    "Sample-A-Backcalculation-28.10.26.csv: individual sample A estimates.\n",
    "Sample-A-Summary-28.10.26.csv: mean, SD, CV and recovery of sample A.\n",
    "Group-Summary-and-CV-28.10.26.csv: group summaries and repeatability.\n",
    "Global-CV-Test-28.10.26.csv: global CV comparison.\n",
    "Blocking-Comparison-28.10.26.csv: blocking comparison and test.\n\n",
    sep = ""
  )

  cat("SESSION INFORMATION\n")
  print(sessionInfo())
})

writeLines(
  analysis_text,
  final_path(
    "ELISA-Analysis",
    "txt"
  )
)

# ---------- 9. 保留结果对象 ----------

results_final <- list(
  model_comparison = scores,
  selected_model_parameters = model_parameters,
  standard_fit = standard_results,
  sample_A = sample_results,
  sample_A_summary = sample_summary,
  group_summary = group_summary,
  global_CV_test = cv_test_summary,
  blocking_comparison = blocking_export
)

print(figure)

cat(
  "\n最终版已保存至当前工作目录：\n",
  normalizePath(FINAL_DIR),
  "\n",
  sep = ""
)