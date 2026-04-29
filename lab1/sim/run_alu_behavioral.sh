#!/bin/bash
# Test BEHAVIORAL implementation

echo "========================================"
echo "Testing BEHAVIORAL Implementation"
echo "========================================"
echo ""

# Clean previous files
rm -rf xsim.dir *.wdb *.jou *.log

# Compile RTL (behavioral is default, no flags needed)
echo "[1/3] Compiling RTL..."
xvlog -sv ../rtl/alu_16bit.sv || exit 1

echo "[2/3] Compiling testbench..."
xvlog -sv tb_alu_random.sv || exit 1

echo "[3/3] Running simulation..."
xelab -debug typical tb_alu_random -s sim || exit 1
xsim sim -runall || exit 1

echo ""
echo "Test completed!"
