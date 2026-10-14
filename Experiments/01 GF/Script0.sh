#!/bin/bash

INPUT_FILE="Data-30.09.26.csv"
OUTPUT_FILE="TrueData-30.09.26.csv"

> "$OUTPUT_FILE"

awk -F',' '
NR <= 3 {
    header[NR] = $1 "," $2
}
{
    if (NR >= 4) {
        line1[NR] = $1
        line2[NR] = $2
        line13[NR] = $13
        total = NR

        if ($14 ~ /SampleValve Sample/) {
            n0 = NR
        }
    }
}
END {
    if (n0 == 0) {
        print "未找到 SampleValve Sample" > "/dev/stderr"
        exit 1
    }

    v0 = line13[n0] + 0
    print ("n0 =", n0, " v0 =", v0) > "/dev/stderr"

    # 找与 v0 差值最小的行
    m = 0
    best = -1
    for (i = 4; i <= total; i++) {
        d = line1[i] + 0 - v0
        if (d < 0) d = -d
        if (best < 0 || d < best) {
            best = d
            m = i
        }
    }

    print ("m =", m, " closest value =", line1[m], " diff =", best) > "/dev/stderr"

    # 输出前3行表头
    for (i = 1; i <= 3; i++) {
        print header[i] >> "'"$OUTPUT_FILE"'"
    }

    # 输出 m 及以后
    for (i = m; i <= total; i++) {
        print line1[i] "," line2[i] >> "'"$OUTPUT_FILE"'"
    }
}
' "$INPUT_FILE"

