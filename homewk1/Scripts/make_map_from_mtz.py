#!/usr/bin/env python
import gemmi
import os

mtz_file = "/home/revewill/share/map_for_water-building.mtz"
output_file = "/root/biochem/results/2fo-fc.ccp4"

if not os.path.exists(mtz_file):
    print(f"错误：文件不存在 {mtz_file}")
    exit(1)

print(f"读取 MTZ 文件: {mtz_file}")

# 读取 MTZ
mtz = gemmi.read_mtz_file(mtz_file)
print(f"列: {mtz.column_labels()}")

# 生成密度图
print("正在生成密度图...")
grid = mtz.transform_f_phi_to_map("2FOFCWT", "PH2FOFCWT", sample_rate=3.0)

# === 关键修正：使用 Ccp4Map 类保存 ===
print(f"保存到: {output_file}")
ccp4_map = gemmi.Ccp4Map()
ccp4_map.grid = grid
ccp4_map.update_ccp4_header()
ccp4_map.write_ccp4_map(output_file)

print(f"网格大小: {grid.nu} x {grid.nv} x {grid.nw}")
print("✅ 完成")
