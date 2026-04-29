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
xvlog -sv ../rtl/full_adder.sv ../rtl/adder_16bit.sv || exit 1

echo "[2/3] Compiling testbench..."
xvlog -sv tb_adder_exhaustive.sv || exit 1

echo "[3/3] Running simulation..."
xelab -debug typical tb_adder_exhaustive -s sim || exit 1
xsim sim -runall || exit 1

echo ""
echo "Test completed!"
