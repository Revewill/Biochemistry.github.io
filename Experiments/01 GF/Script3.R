INPUT  <- "Peaks-30.09.26.csv"
OUTPUT <- "RegressionData-30.09.26.csv"

V0 <- 29.4462

# ---------- 读取 Peaks 文件（跳过3行表头） ----------
df <- read.csv(INPUT, header = FALSE, skip = 3,
               stringsAsFactors = FALSE)

vol_all <- suppressWarnings(as.numeric(df[[1]]))
vol_all <- vol_all[!is.na(vol_all)]

# 取最后5个
v <- tail(vol_all, 5)

# ---------- 构造各列 ----------
col1 <- round(v, 4)                 # Volume (mL)
col2 <- round(v - V0, 4)            # Ve (mL) = Volume - V0
col3 <- round((col2 - col2[1]) / (120 - col2[1]), 4)   # Kav

# 第4列（MW）：手动向量
mw_raw <- c("-", 67, 45, "?", 13.7)

# 第5列（logMW）：数值取 log10，非数值原样
mw_log <- sapply(mw_raw, function(x) {
  num <- suppressWarnings(as.numeric(x))
  if (is.na(num)) {
    return(x)
  } else {
    return(format(log10(num), digits = 6, trim = TRUE))
  }
})

# ---------- 组装并写出 ----------
out <- data.frame(
  `Volume (mL)` = col1,
  `Ve (mL)`     = col2,
  `Kav`         = col3,
  `MW (kDa)`    = mw_raw,
  `logMW`       = mw_log,
  check.names   = FALSE,
  stringsAsFactors = FALSE
)

write.csv(out, OUTPUT, row.names = FALSE, quote = FALSE)

cat("已写入:", OUTPUT, "\n")
print(out)