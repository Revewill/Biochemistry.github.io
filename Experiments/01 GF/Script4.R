library(ggplot2)

# Accept the original filename or one numbered downloaded copy.
resolve_input <- function(filename) {
  if (file.exists(filename)) return(filename)
  stem <- sub("\\.csv$", "", filename)
  candidates <- list.files(pattern = "\\.csv$", full.names = FALSE)
  pattern <- paste0("^\\Q", stem, "\\E\\([0-9]+\\)\\.csv$")
  hits <- candidates[grepl(pattern, candidates, perl = TRUE)]
  if (length(hits) != 1) {
    stop("Please specify the input filename: ", filename,
         "; matching numbered copies: ", paste(hits, collapse = ", "))
  }
  hits
}


INPUT      <- "RegressionData-30.09.26.csv"
OUTPUT_TXT <- "Regression-30.09.26.txt"
OUTPUT_PNG <- "Regression-30.09.26.png"

INPUT <- resolve_input(INPUT)
OUTPUT_RESIDUAL <- "Residuals-30.09.26.png"

# ================= 读取 =================
df <- read.csv(INPUT, header = TRUE, stringsAsFactors = FALSE)

if (nrow(df) < 5 || ncol(df) < 5) stop("Unexpected regression table dimensions.")

Table    <- df[2:nrow(df), ]
Unknown  <- Table[3, ]
Table_wo <- Table[-3, ]

x <- as.numeric(Table_wo[[3]])
y <- as.numeric(Table_wo[[5]])

if (any(!is.finite(c(x, y)))) stop("Invalid standard values.")

# ================= 回归 =================
fit <- lm(y ~ x)
fit_summary <- summary(fit)

a  <- unname(coef(fit)[2])
b  <- unname(coef(fit)[1])
r2 <- fit_summary$r.squared

# 斜率的双侧 t 检验：H0: slope = 0
p_value <- fit_summary$coefficients["x", "Pr(>|t|)"]
n_std   <- length(x)

sig <- if (p_value < 0.001) {
  "***"
} else if (p_value < 0.01) {
  "**"
} else if (p_value < 0.05) {
  "*"
} else {
  "ns"
}

p_label <- if (p_value < 0.001) {
  formatC(p_value, format = "e", digits = 2)
} else {
  sprintf("%.4f", p_value)
}

# ================= 未知蛋白 =================
kav_u   <- as.numeric(Unknown[[3]])
logmw_u <- a * kav_u + b
mw_u    <- 10^logmw_u

# Observed minus fitted log10(MW/kDa), standards only.
residual_table <- data.frame(
  Kav = x, MW_kDa = as.numeric(Table_wo[[4]]),
  Observed_logMW = y, Fitted_logMW = fitted(fit),
  Residual = residuals(fit)
)
residual_table <- residual_table[order(residual_table$Kav), ]

# ================= TXT 与控制台输出 =================
report <- capture.output({
  cat("Linear regression: logMW = a * Kav + b\n")
  cat("========================================\n\n")

  cat(sprintf("a (slope)     = %.6f\n", a))
  cat(sprintf("b (intercept) = %.6f\n", b))
  cat(sprintf("R^2           = %.6f\n", r2))
  cat(sprintf("P (slope, two-sided) = %.6g (%s)\n", p_value, sig))
  cat(sprintf("n (standards)       = %d\n", n_std))
  cat(sprintf("Residual df         = %d\n\n", df.residual(fit)))

  cat("Test: H0: slope = 0; two-sided t-test.\n")
  cat("Significance: * P < 0.05; ** P < 0.01; *** P < 0.001;\n")
  cat("              ns P >= 0.05.\n\n")

  cat(sprintf(
    "Equation: logMW = %.6f * Kav %s %.6f\n\n",
    a, ifelse(b >= 0, "+", "-"), abs(b)
  ))

  cat("Data points used (Kav, logMW):\n")
  for (i in seq_along(x)) {
    cat(sprintf("  (%.4f, %.6f)\n", x[i], y[i]))
  }

  cat("\nStandard residuals (observed minus fitted log10(MW/kDa)):\n")
  print(residual_table, row.names = FALSE, digits = 8)
  cat("Panel c: one bar per standard; unknown excluded.\n")
  cat("Only three standards and one residual degree of freedom; residuals are descriptive.\n")

  cat("\nUnknown protein:\n")
  cat(sprintf("  Kav      = %.4f\n", kav_u))
  cat(sprintf("  logMW    = %.6f\n", logmw_u))
  cat(sprintf("  MW (kDa) = %.4f\n", mw_u))
})

writeLines(report, OUTPUT_TXT)
cat(paste(report, collapse = "\n"), "\n")

# ================= 配色 =================
col_pt       <- "#226482"
col_edge     <- "#FFFFFF"
col_line     <- "#8ED3F5"
col_unk      <- "#F2A0A0"
col_unk_text <- "#633737"
col_text     <- "#252A2E"

plot_df <- data.frame(x = x, y = y)

# ================= 绘图范围 =================
x_span <- diff(range(x))
y_span <- diff(range(y))

x_lim <- c(
  min(x) - 0.12 * x_span,
  max(x) + 0.12 * x_span
)

y_lim <- c(
  min(y) - 0.16 * y_span,
  max(y) + 0.22 * y_span
)

# 两端各延伸标准品 x 范围的 8%
x_ext <- 0.08 * x_span

line_df <- data.frame(
  x = seq(
    min(x) - x_ext,
    max(x) + x_ext,
    length.out = 200
  )
)
line_df$y <- a * line_df$x + b

# ================= 图内统计标注 =================
r2_label <- sprintf("italic(R)^2 == %.4f", r2)

# 仅 P 使用斜体，其余内容保持正体
p_plot_label <- sprintf(
  'italic(P) == "%s" ~ "%s" ~ "(n = %d)"',
  p_label, sig, n_std
)

stat_x <- x_lim[2] - 0.025 * diff(x_lim)
stat_y <- y_lim[2] - 0.045 * diff(y_lim)

# ================= 画图 =================
p <- ggplot(plot_df, aes(x, y)) +

  # 未知蛋白插值辅助线
  annotate(
    "segment",
    x = kav_u, xend = kav_u,
    y = y_lim[1], yend = logmw_u,
    colour = col_unk,
    linewidth = 0.35,
    linetype = "dotted",
    alpha = 0.8
  ) +

  # 浅蓝色拟合线
  geom_line(
    data = line_df,
    colour = col_line,
    linewidth = 0.8,
    lineend = "round"
  ) +

  # 标准品：深蓝圆点、白色描边
  geom_point(
    shape = 21,
    size = 3.8,
    stroke = 0.95,
    fill = col_pt,
    colour = col_edge
  ) +

  # 未知蛋白：粉色菱形、白色描边
  annotate(
    "point",
    x = kav_u, y = logmw_u,
    shape = 23,
    size = 4.1,
    stroke = 0.95,
    fill = col_unk,
    colour = col_edge
  ) +

  # 未知蛋白结果
  annotate(
    "text",
    x = kav_u + 0.045 * x_span,
    y = logmw_u + 0.12 * y_span,
    label = sprintf("Unknown\n%.2f kDa", mw_u),
    hjust = 0,
    vjust = 0.5,
    size = 3.0,
    lineheight = 1.15,
    colour = col_unk_text,
    family = "sans"
  ) +

  # R²
  annotate(
    "text",
    x = stat_x,
    y = stat_y,
    label = r2_label,
    parse = TRUE,
    hjust = 1,
    vjust = 1,
    size = 3.1,
    colour = col_text,
    family = "sans"
  ) +

  # 斜体 P、星号及标准品数量
  annotate(
    "text",
    x = stat_x,
    y = stat_y - 0.095 * y_span,
    label = p_plot_label,
    parse = TRUE,
    hjust = 1,
    vjust = 1,
    size = 3.0,
    colour = col_text,
    family = "sans"
  ) +

  # 横轴仅保留四个主刻度
  scale_x_continuous(
    breaks = c(0.10, 0.20, 0.30, 0.40),
    minor_breaks = NULL,
    labels = function(z) sprintf("%.2f", z),
    expand = expansion(mult = 0)
  ) +

  scale_y_continuous(
    breaks = scales::breaks_pretty(n = 5),
    labels = function(z) sprintf("%.1f", z),
    expand = expansion(mult = 0)
  ) +

  coord_cartesian(
    xlim = x_lim,
    ylim = y_lim
  ) +

  labs(
    x = expression(plain(K)[plain(av)]),
    y = expression(plain(log)(plain(MW) / plain(kDa))),
    tag = "b"
  ) +

  theme_classic(
    base_size = 10,
    base_family = "sans"
  ) +

  theme(
    aspect.ratio = 1.55,

    axis.line = element_line(
      colour = col_text,
      linewidth = 0.45
    ),
    axis.ticks = element_line(
      colour = col_text,
      linewidth = 0.40
    ),
    axis.ticks.length = grid::unit(1.5, "mm"),

    axis.text = element_text(
      family = "sans",
      colour = col_text,
      size = 9
    ),
    axis.text.x = element_text(
      margin = margin(t = 4)
    ),
    axis.text.y = element_text(
      margin = margin(r = 4)
    ),

    axis.title = element_text(
      family = "sans",
      colour = col_text,
      size = 11
    ),
    axis.title.x = element_text(
      margin = margin(t = 8)
    ),
    axis.title.y = element_text(
      margin = margin(r = 8)
    ),

    plot.tag = element_text(size = 13, face = "bold", colour = col_text),
    plot.margin = margin(12, 14, 10, 8)
  )

print(p)

# ================= 保存 =================
ggsave(
  filename = OUTPUT_PNG,
  plot = p,
  width = 4.0,
  height = 5.7,
  units = "in",
  dpi = 600,
  bg = "white"
)

cat("\n统计结果已保存:", OUTPUT_TXT, "\n")
cat("图已保存:", OUTPUT_PNG, "\n")

# ================= c: standard calibration residuals =================
# Equal category spacing, as in Fig.2c; labels show each standard's Kav.
# No residual is defined for the unknown protein without a known MW.
residual_table$BarX <- seq_len(nrow(residual_table))
residual_table$BarColour <- colorRampPalette(
  c("#8ED3F5", "#59A9CE", "#226482")
)(nrow(residual_table))

res_max <- max(abs(residual_table$Residual))
if (!is.finite(res_max) || res_max == 0) res_max <- 0.001
res_breaks <- pretty(c(-res_max, res_max), n = 5)
res_limits <- range(c(res_breaks, -res_max * 1.15, res_max * 1.15))

p_c <- ggplot(residual_table) +
  geom_col(
    aes(x = BarX, y = Residual, fill = BarColour),
    width = 0.60, colour = NA
  ) +
  geom_hline(yintercept = 0, colour = "#70777B", linewidth = 0.45) +
  scale_fill_identity() +
  scale_x_continuous(
    breaks = residual_table$BarX,
    labels = sprintf("%.4f", residual_table$Kav),
    expand = expansion(mult = 0)
  ) +
  scale_y_continuous(
    breaks = res_breaks,
    labels = function(z) sprintf("%.3f", z),
    expand = expansion(mult = 0)
  ) +
  coord_cartesian(
    xlim = c(0.45, nrow(residual_table) + 0.55),
    ylim = res_limits
  ) +
  labs(
    x = expression(plain(K)[plain(av)]),
    y = expression("Residual (" * plain(log)[10](plain(MW) / plain(kDa)) * ")"),
    tag = "c"
  ) +
  theme_classic(base_size = 10, base_family = "sans") +
  theme(
    aspect.ratio = 1.55,
    axis.line = element_line(colour = col_text, linewidth = 0.45),
    axis.ticks = element_line(colour = col_text, linewidth = 0.4),
    axis.ticks.length = grid::unit(1.5, "mm"),
    axis.text = element_text(colour = col_text, size = 9),
    axis.text.x = element_text(margin = margin(t = 4)),
    axis.text.y = element_text(margin = margin(r = 4)),
    axis.title = element_text(colour = col_text, size = 11),
    axis.title.x = element_text(margin = margin(t = 8)),
    axis.title.y = element_text(margin = margin(r = 8)),
    plot.tag = element_text(size = 13, face = "bold", colour = col_text),
    plot.margin = margin(12, 14, 10, 8),
    legend.position = "none"
  )

print(p_c)
ggsave(
  filename = OUTPUT_RESIDUAL, plot = p_c,
  width = 4.0, height = 5.7, units = "in", dpi = 600, bg = "white"
)
cat("Residual panel saved:", OUTPUT_RESIDUAL, "\n")
