#!/bin/bash

INPUT_FILE="TrueData-30.09.26.csv"
OUTPUT_FILE="Peaks-30.09.26.csv"

# ===== 可调参数 =====
START_ROW=4          # 数据起始行
MIN_HEIGHT=5.0       # 最小峰高（UV 绝对值阈值）
MIN_PROMINENCE=0.01  # 最小峰突出度
SMOOTH_WIN=5         # 平滑窗口（奇数）
# ====================

> "$OUTPUT_FILE"

awk -F',' -v start="$START_ROW" -v minh="$MIN_HEIGHT" \
         -v minp="$MIN_PROMINENCE" -v win="$SMOOTH_WIN" '
NR <= 3 {
    # 保留前3行表头（第1、2列）
    header[NR] = $1 "," $2
    next
}
NR >= start {
    idx++
    x[idx] = $1
    y[idx] = $2 + 0
    total = idx
}
END {
    if (total < 3) {
        print "数据点太少" > "/dev/stderr"
        exit
    }

    # ---- 1. 滑动平均平滑 ----
    half = int(win / 2)
    for (i = 1; i <= total; i++) {
        sum = 0; cnt = 0
        for (j = i - half; j <= i + half; j++) {
            if (j >= 1 && j <= total) { sum += y[j]; cnt++ }
        }
        ys[i] = sum / cnt
    }

    # ---- 先写表头 ----
    for (i = 1; i <= 3; i++) {
        print header[i] >> "'"$OUTPUT_FILE"'"
    }

    # ---- 2. 找局部极大值（平滑后）+ 阈值筛选 ----
    for (i = 2; i < total; i++) {
        if (ys[i] > ys[i-1] && ys[i] >= ys[i+1]) {
            if (ys[i] < minh) continue

            lmin = ys[i]
            for (j = i-1; j >= 1; j--) {
                if (ys[j] < lmin) lmin = ys[j]
                if (ys[j] > ys[i]) break
            }
            rmin = ys[i]
            for (j = i+1; j <= total; j++) {
                if (ys[j] < rmin) rmin = ys[j]
                if (ys[j] > ys[i]) break
            }
            prom = ys[i] - (lmin > rmin ? lmin : rmin)

            if (prom >= minp) {
                print x[i] "," y[i] >> "'"$OUTPUT_FILE"'"
            }
        }
    }
}
' "$INPUT_FILE"

