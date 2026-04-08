#!/bin/bash
# GIST analysis pipeline for RBP4 - runs with sander (AmberTools)

set -e  # exit on error

# Log file
LOG="md_pipeline.log"
exec > >(tee -a "$LOG") 2>&1

echo "=========================================="
echo "Starting MD pipeline at $(date)"
echo "=========================================="

# Check if PDB exists
if [ ! -f "RBP4.str.predict.pdb" ]; then
    echo "ERROR: RBP4.str.predict.pdb not found in current directory"
    exit 1
fi

# Step 1: tleap
echo ""
echo "[Step 1] Running tleap..."
cat > leap.in << 'EOFLEAP'
source leaprc.protein.ff14SB
source leaprc.water.tip3p
prot = loadpdb RBP4.str.predict.pdb
solvateOct prot TIP3PBOX 10.0
addIons prot Na+ 0
saveamberparm prot rbp4.prmtop rbp4.inpcrd
quit
EOFLEAP
tleap -f leap.in > leap.out 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: tleap failed. Check leap.out"
    exit 1
fi
echo "tleap completed successfully"

Step 2: Minimization
echo ""
echo "[Step 2] Running minimization (1000 steps)..."
cat > min.in << 'EOFM'
Minimization
&cntrl
  imin=1, maxcyc=1000, ncyc=500,
  ntb=1, cut=10.0,
  ntpr=100
/
EOFM
sander -O -i min.in -o min.out -p rbp4.prmtop -c rbp4.inpcrd -r min.rst
if [ $? -ne 0 ]; then
    echo "ERROR: Minimization failed. Check min.out"
    exit 1
fi
echo "Minimization completed"

# Step 3: Heating (NVT) - modified parameters
echo ""
echo "[Step 3] Running heating (NVT, 100 ps, gentle ramp)..."
cat > heat.in << 'EOFH'
Heating NVT with temperature ramp
&cntrl
  irest=0, ntx=1,
  nstlim=100000, dt=0.001,
  ntt=3, gamma_ln=2.0, temp0=300.0,
  ntb=1, cut=10.0,
  ntr=1, restraint_wt=25.0,
  restraintmask="!:WAT & !@H=",
  ntpr=500, ntwx=5000,
  nmropt=1
/
&wt type='TEMP0', istep1=0, istep2=100000, value1=0.0, value2=300.0 /
&wt type='END' /
EOFH

sander -O -i heat.in -o heat.out -p rbp4.prmtop -c min.rst -r heat.rst -ref min.rst
if [ $? -ne 0 ]; then
    echo "ERROR: Heating failed. Check heat.out"
    exit 1
fi
echo "Heating completed"

# Step 4: Equilibration (NPT) - modified parameters (dt=0.002, nstlim=50000 for 100 ps)
echo ""
echo "[Step 4] Running equilibration (NPT, 100 ps)..."
cat > equil.in << 'EOFE'
Equilibration NPT
&cntrl
  irest=1, ntx=5,
  nstlim=100000, dt=0.001,
  ntt=3, gamma_ln=2.0, temp0=300.0,
  ntb=2, ntp=1, pres0=1.0, taup=2.0,
  cut=10.0,
  ntr=1, restraint_wt=25.0,
  restraintmask="!:WAT & !@H=",
  ntpr=500, ntwx=5000
/
EOFE

sander -O -i equil.in -o equil.out -p rbp4.prmtop -c heat.rst -r equil.rst -ref heat.rst
if [ $? -ne 0 ]; then
    echo "ERROR: Equilibration failed. Check equil.out"
    exit 1
fi
echo "Equilibration completed"

# Step 5: Production MD (5 ns) - dt=0.002, nstlim=2500000
echo ""
echo "[Step 5] Running production MD (5 ns, 2.5M steps)..."
cat > md.in << 'EOFM'
Production MD 5 ns
&cntrl
  irest=1, ntx=5,
  nstlim=2500000, dt=0.002,
  ntt=3, gamma_ln=2.0, temp0=300.0,
  ntb=2, ntp=1, pres0=1.0, taup=1.0,
  cut=10.0,
  ntwx=5000, ntpr=500, ntwr=5000
/
EOFM

sander -O -i md.in -o md.out -p rbp4.prmtop -c equil.rst -r md.rst -x mdcrd.nc
if [ $? -ne 0 ]; then
    echo "ERROR: Production MD failed. Check md.out"
    exit 1
fi
echo "Production MD completed"

# Step 6: Calculate pocket center (optional, for GIST)
echo ""
echo "[Step 6] Calculating pocket center from aromatic residues..."

python3 << 'EOFP'
import sys
with open("RBP4.str.predict.pdb", "r") as f:
    coords = []
    for line in f:
        if line.startswith("ATOM") and line[12:16].strip() in ["PHE","TRP","TYR"]:
            try:
                x = float(line[30:38]); y = float(line[38:46]); z = float(line[46:54])
                coords.append([x,y,z])
            except:
                pass
    if coords:
        cx = sum(c[0] for c in coords)/len(coords)
        cy = sum(c[1] for c in coords)/len(coords)
        cz = sum(c[2] for c in coords)/len(coords)
        with open("pocket_center.txt", "w") as out:
            out.write(f"Pocket center: {cx:.3f} {cy:.3f} {cz:.3f}\n")
        print(f"Pocket center calculated: {cx:.3f} {cy:.3f} {cz:.3f}")
    else:
        print("WARNING: Could not calculate pocket center - no aromatic residues found")
        with open("pocket_center.txt", "w") as out:
            out.write("Pocket center: 0.000 0.000 0.000\n")
EOFP

echo ""
echo "=========================================="
echo "MD PIPELINE COMPLETED SUCCESSFULLY at $(date)"
echo "=========================================="
echo ""
echo "Generated files:"
ls -lh rbp4.prmtop rbp4.inpcrd min.rst heat.rst equil.rst md.rst mdcrd.nc pocket_center.txt 2>/dev/null
echo ""
