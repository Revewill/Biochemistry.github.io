library(ggplot2)

INPUT      <- "TrueData-30.09.26.csv"
PEAKS_FILE <- "Peaks-30.09.26.csv"
OUTPUT     <- "ElutionCurve-30.09.26.png"

# ---------- 配色 ----------
col_curve    <- "#8ED3F5"
col_unk      <- "#F2A0A0"
col_unk_text <- "#633737"

# ---------- 读取曲线数据 ----------
df <- read.csv(
  INPUT,
  header = FALSE,
  skip = 3,
  col.names = c("vol", "uv"),
  stringsAsFactors = FALSE
)

df$vol <- as.numeric(df$vol)
df$uv  <- as.numeric(df$uv)
df <- df[is.finite(df$vol) & is.finite(df$uv), ]

# ---------- 自动提取 Unknown 横坐标 ----------
peaks <- read.csv(
  PEAKS_FILE,
  header = FALSE,
  skip = 3,
  stringsAsFactors = FALSE
)

if (nrow(peaks) < 2) {
  stop("Peaks 文件的数据行不足两行。")
}

unknown_ve <- suppressWarnings(
  as.numeric(peaks[nrow(peaks) - 1, 1])
)

if (!is.finite(unknown_ve)) {
  stop("Peaks 倒数第二行第一列不是有效数字。")
}

# ---------- 预处理 ----------
i0 <- which(df$vol > 55)[1]

if (is.na(i0)) {
  stop("曲线数据中没有横坐标大于 55 的点。")
}

df <- df[i0:nrow(df), ]

# ---------- 平滑 ----------
sp <- smooth.spline(df$vol, df$uv, spar = 0.4)
df_s <- data.frame(vol = sp$x, uv = sp$y)

# ---------- 曲线范围 ----------
x_rng <- range(df_s$vol)
y_rng <- range(df_s$uv)

x_span <- diff(x_rng)
y_span <- diff(y_rng)

if (unknown_ve < x_rng[1] || unknown_ve > x_rng[2]) {
  stop("Unknown 横坐标超出了当前曲线范围。")
}

# ---------- 绘图区范围 ----------
x_min <- x_rng[1] - x_span * 0.10
x_max <- x_rng[2] + x_span * 0.10
y_min <- y_rng[1] - y_span * 0.18
y_max <- y_rng[2] + y_span * 0.30

# ---------- Unknown 标注位置 ----------
unknown_uv <- predict(sp, x = unknown_ve)$y

# 在上一版位置基础上整体上移
# 当前 4.4 × 2.8 英寸导出尺寸下，约为 1 cm
move_up <- y_span * 0.08

triangle_y <- unknown_uv + y_span * 0.08 + move_up
label_y    <- triangle_y + y_span * 0.12

# ---------- 轴的端点 ----------
x_axis_x0 <- x_rng[1] + x_span * 0.12
x_axis_x1 <- x_rng[2] - x_span * 0.12

y_axis_y0 <- y_rng[1] + y_span * 0.12
y_axis_y1 <- y_rng[2] - y_span * 0.12

x_axis_y <- y_min
y_axis_x <- x_min

# ---------- 绘图 ----------
p <- ggplot(df_s, aes(x = vol, y = uv)) +

  geom_line(
    color = col_curve,
    linewidth = 1.2,
    lineend = "round"
  ) +

  annotate(
    "point",
    x = unknown_ve,
    y = triangle_y,
    shape = 25,
    size = 3.2,
    stroke = 0.35,
    fill = col_unk,
    colour = col_unk
  ) +

  annotate(
    "text",
    x = unknown_ve,
    y = label_y,
    label = "Unknown",
    family = "sans",
    size = 3.2,
    hjust = 0.5,
    vjust = 0.5,
    colour = col_unk_text
  ) +

  annotate(
    "segment",
    x = x_axis_x0, xend = x_axis_x1,
    y = x_axis_y, yend = x_axis_y,
    linewidth = 0.7,
    color = "black",
    lineend = "round"
  ) +

  annotate(
    "segment",
    x = y_axis_x, xend = y_axis_x,
    y = y_axis_y0, yend = y_axis_y1,
    linewidth = 0.7,
    color = "black",
    lineend = "round"
  ) +

  scale_x_continuous(
    limits = c(x_min, x_max),
    breaks = NULL,
    expand = c(0, 0)
  ) +

  scale_y_continuous(
    limits = c(y_min, y_max),
    breaks = NULL,
    expand = c(0, 0)
  ) +

  labs(
    x = "Elution volume (mL)",
    y = "UV absorbance"
  ) +

  theme_void() +

  theme(
    axis.title.x = element_text(
      size = 10,
      color = "black",
      margin = margin(t = 10)
    ),
    axis.title.y = element_text(
      size = 10,
      color = "black",
      angle = 90,
      margin = margin(r = 10)
    ),
    plot.margin = margin(10, 10, 10, 10)
  )

print(p)

# ---------- 保存 ----------
ggsave(
  OUTPUT,
  plot = p,
  width = 4.4,
  height = 2.8,
  dpi = 600,
  bg = "white"
)

cat(sprintf("自动提取的 Unknown 横坐标 = %.4f mL\n", unknown_ve))
cat("图已保存:", OUTPUT, "\n")