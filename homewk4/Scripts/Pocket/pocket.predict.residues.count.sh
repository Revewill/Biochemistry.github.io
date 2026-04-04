#!/bin/bash
# Usage: ./pocket.predict.residues.count.sh <count_file> <original_file>
# Example: ./pocket.predict.residues.count.sh pocket.predict.residues.count.txt pocket.predict.residues.txt

count_file="$1"
orig_file="$2"

# 1. Collect positions for each AA from original file
awk '
BEGIN {
    split("GLY,ALA,VAL,LEU,ILE,MET,PHE,TRP,PRO", hydro, ",");
    for (i in hydro) hydrophobic[hydro[i]] = 1;
    split("SER,THR,TYR,ASN,GLN,LYS,ARG,HIS,ASP,GLU", hydrophi, ",");
    for (i in hydrophi) hydrophilic[hydrophi[i]] = 1;
    
    hydro_all = "";
    phil_all = "";
}
{
    # Extract residue ID
    match($0, /#1\/A:([0-9]+)/);
    pos = substr($0, RSTART+5, RLENGTH-5);
    aa = $5;
    
    if (aa in hydrophobic) {
        # Per-residue positions
        hydro_pos[aa] = hydro_pos[aa] ? hydro_pos[aa] "," pos : pos;
        hydro_sum[aa]++;
        # Combined positions
        hydro_all = hydro_all ? hydro_all "," pos : pos;
    } else if (aa in hydrophilic) {
        # Per-residue positions
        phil_pos[aa] = phil_pos[aa] ? phil_pos[aa] "," pos : pos;
        phil_sum[aa]++;
        # Combined positions
        phil_all = phil_all ? phil_all "," pos : pos;
    }
}
END {
    # Print
    printf "=== Hydrophobic Combined Positions ===\n";
    printf "%s\n\n", hydro_all;
    
    printf "=== Hydrophobic by Residue Type ===\n";
    for (aa in hydro_pos) {
        printf "  %s (n=%d): %s\n", aa, hydro_sum[aa], hydro_pos[aa];
    }
    
    printf "\n=== Hydrophilic Combined Positions ===\n";
    printf "%s\n\n", phil_all;
    
    printf "=== Hydrophilic by Residue Type ===\n";
    for (aa in phil_pos) {
        printf "  %s (n=%d): %s\n", aa, phil_sum[aa], phil_pos[aa];
    }
}' "$orig_file"

# 2. Calculate ratios from count file
awk '
BEGIN {
    split("GLY,ALA,VAL,LEU,ILE,MET,PHE,TRP,PRO", hydro, ",");
    for (i in hydro) hydrophobic[hydro[i]] = 1;
    split("SER,THR,TYR,ASN,GLN,LYS,ARG,HIS,ASP,GLU", hydrophi, ",");
    for (i in hydrophi) hydrophilic[hydrophi[i]] = 1;
    total_hydrophobic = 0;
    total_hydrophilic = 0;
}
{
    if ($2 in hydrophobic) total_hydrophobic += $1;
    else if ($2 in hydrophilic) total_hydrophilic += $1;
}
END {
    total = total_hydrophobic + total_hydrophilic;
    if (total > 0) {
        printf "\n=== Summary ===\n";
        printf "Hydrophobic: %d (%.2f%%)\n", total_hydrophobic, total_hydrophobic/total*100;
        printf "Hydrophilic: %d (%.2f%%)\n", total_hydrophilic, total_hydrophilic/total*100;
        printf "Ratio (Hpho/Hphi): %.2f\n", total_hydrophobic/total_hydrophilic;
    }
}' "$count_file"
