#!/bin/bash
# Test RIPPLE_CARRY_GENERATE implementation

echo "========================================"
echo "Testing RIPPLE_CARRY_GENERATE Implementation"
echo "========================================"
echo ""

# Clean previous files
rm -rf xsim.dir *.wdb *.jou *.log

# Compile RTL with RIPPLE_CARRY_GENERATE flag
echo "[1/3] Compiling RTL with -d RIPPLE_CARRY_GENERATE..."
xvlog -sv -d RIPPLE_CARRY_GENERATE ../rtl/full_adder.sv ../rtl/adder_16bit.sv || exit 1

echo "[2/3] Compiling testbench..."
xvlog -sv tb_adder_exhaustive.sv || exit 1

echo "[3/3] Running simulation..."
xelab -debug typical tb_adder_exhaustive -s sim || exit 1
xsim sim -runall || exit 1

echo ""
echo "Test completed!"
