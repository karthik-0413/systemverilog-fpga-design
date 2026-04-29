#!/bin/bash
# Run coverage testbench with code coverage (line, toggle, branch, condition)

echo "========================================"
echo "Running Coverage Test"
echo "========================================"
echo ""

# Clean previous files
rm -rf xsim.dir *.wdb *.jou *.log xsim.codecov

# Compile
echo "[1/4] Compiling RTL..."
xvlog -sv ../rtl/full_adder.sv ../rtl/adder_16bit.sv || exit 1

echo "[2/4] Compiling testbench..."
xvlog -sv tb_adder_constrained_random.sv || exit 1
#xvlog -sv tb_adder_exhaustive.sv || exit 1

echo "[3/4] Elaborating with code coverage enabled..."
# Code coverage flags (NOT functional coverage):
#   l = Line coverage
#   t = Toggle coverage
#   b = Branch coverage
#   c = Condition coverage
#xelab -debug typical tb_adder_exhaustive -s sim \
xelab -debug typical tb_adder_constrained_random -s sim \
      --cc_type ltbc \
      --cc_db adder_cov \
      --cc_dir ./xsim.codecov || exit 1

echo "[4/4] Running simulation with coverage collection..."
xsim sim --cc_db adder_cov --cc_dir ./xsim.codecov -runall || exit 1

echo ""
echo "========================================"
echo "Code Coverage Summary"
echo "========================================"
xcrg -cc_db adder_cov -cc_dir ./xsim.codecov -report_format text
echo ""
echo "For HTML report:"
echo "  xcrg -cc_db adder_cov -cc_dir ./xsim.codecov -report_dir ./cov_report -report_format html"
echo "========================================"
