#!/usr/bin/env python
import gemmi
import sys
import os

if len(sys.argv) != 6:
    print("用法: python find_waters_gemmi.py 输入.pdb MTZ文件 输出.pdb 阈值 最小距离")
    sys.exit(1)

pdb_file = sys.argv[1]
mtz_file = sys.argv[2]
output_pdb = sys.argv[3]
threshold = float(sys.argv[4])
min_dist = float(sys.argv[5])

# 读 PDB
print(f"读取 PDB: {pdb_file}")
structure = gemmi.read_structure(pdb_file)
model = structure[0]

# 读 MTZ
print(f"读取 MTZ: {mtz_file}")
mtz = gemmi.read_mtz_file(mtz_file)
grid = mtz.transform_f_phi_to_map("2FOFCWT", "PH2FOFCWT", sample_rate=3.0)

# 计算密度图统计
print("计算密度图统计...")
total = 0
total_sq = 0
n = 0
step = max(1, grid.nu // 50)
for i in range(0, grid.nu, step):
    for j in range(0, grid.nv, step):
        for k in range(0, grid.nw, step):
            val = grid.get_value(i, j, k)
            total += val
            total_sq += val * val
            n += 1

mean = total / n
variance = (total_sq / n) - (mean * mean)
std = variance ** 0.5 if variance > 0 else 1.0
print(f"密度图: 平均值={mean:.3f}, 标准差={std:.3f}")

abs_threshold = mean + threshold * std
print(f"绝对阈值: {abs_threshold:.3f}")

# 手动找峰：扫描所有高于阈值的点，用 flood_fill 找连通区域
print(f"扫描密度峰...")

# 标记已经访问过的点
visited = set()
peak_positions = []

# 遍历所有网格点
for i in range(grid.nu):
    for j in range(grid.nv):
        for k in range(grid.nw):
            if (i, j, k) in visited:
                continue
            
            val = grid.get_value(i, j, k)
            if val < abs_threshold:
                continue
            
            # 从这一点开始做 flood fill
            points = []
            max_val = val
            max_i, max_j, max_k = i, j, k
            stack = [(i, j, k)]
            visited.add((i, j, k))
            
            while stack:
                x, y, z = stack.pop()
                points.append((x, y, z))
                
                # 检查26个邻域
                for dx in [-1, 0, 1]:
                    for dy in [-1, 0, 1]:
                        for dz in [-1, 0, 1]:
                            if dx == 0 and dy == 0 and dz == 0:
                                continue
                            nx, ny, nz = x+dx, y+dy, z+dz
                            if (nx, ny, nz) in visited:
                                continue
                            if nx < 0 or nx >= grid.nu or ny < 0 or ny >= grid.nv or nz < 0 or nz >= grid.nw:
                                continue
                            nval = grid.get_value(nx, ny, nz)
                            if nval < abs_threshold:
                                continue
                            visited.add((nx, ny, nz))
                            stack.append((nx, ny, nz))
                            if nval > max_val:
                                max_val = nval
                                max_i, max_j, max_k = nx, ny, nz
            
            # 用 blob 里密度最高的点作为峰位置
            if points:
                # 网格坐标转分数坐标（直接用除法）
                u = max_i / grid.nu
                v = max_j / grid.nv
                w = max_k / grid.nw
                # 分数坐标转正交坐标
                pos = grid.unit_cell.orthogonalize(gemmi.Fractional(u, v, w))
                peak_positions.append(pos)

print(f"找到 {len(peak_positions)} 个密度峰")

# 获取现有原子位置
existing_positions = []
for chain in model:
    for residue in chain:
        for atom in residue:
            existing_positions.append(atom.pos)

# 添加新水分子
added = 0
skipped = 0
for i, pos in enumerate(peak_positions):
    # 检查是否离现有原子太近
    too_close = False
    for existing in existing_positions:
        if pos.dist(existing) < 1.5:
            too_close = True
            break
    if too_close:
        skipped += 1
        continue
    
    # 创建新残基
    res = gemmi.Residue()
    res.name = "HOH"
    res.seqid = gemmi.SeqId(len(existing_positions)+i+1, ' ')
    res.het_flag = 'H'
    
    atom = gemmi.Atom()
    atom.name = "O"
    atom.element = gemmi.Element("O")
    atom.pos = pos
    atom.occ = 1.0
    atom.b_iso = 20.0
    res.add_atom(atom)
    
    model[0].add_residue(res)
    existing_positions.append(pos)
    added += 1

print(f"\n结果: 添加 {added} 个新水分子, 跳过 {skipped} 个")

structure.write_pdb(output_pdb)
print(f"保存到: {output_pdb}")
print("✅ 完成")
