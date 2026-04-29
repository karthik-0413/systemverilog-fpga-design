#!/bin/bash
# Run simulation with waveform dumping

TEST_MODE="HP"

echo "========================================"
echo "Parallel FIR Filter Simulation"
echo "Test Mode: $TEST_MODE"
echo "========================================"
echo ""

# Clean previous files
rm -rf xsim.dir *.wdb *.jou *.log

# Compile DUT
echo "[1/4] Compiling DUT..."
xvlog -sv ../fir_filter_parallel.sv || exit 1

# Compile testbench
echo "[2/4] Compiling testbench..."
xvlog -sv tb_fir_filter.sv || exit 1

# Create TCL script for waveform setup
echo "[3/4] Setting up waveforms..."
cat > run_with_waves.tcl << 'EOF'
log_wave -recursive /tb_fir_filter/*
run all
EOF

# Run simulation with waveform capture
echo "[4/4] Running simulation with waveform capture..."
xelab -debug typical tb_fir_filter -s sim --generic_top "TEST_MODE=\"$TEST_MODE\"" || exit 1
xsim sim -gui -tclbatch run_with_waves.tcl -wdb tb_fir_filter.wdb
#xsim sim -tclbatch run_with_waves.tcl -wdb tb_fir_filter.wdb

echo ""
echo "Waveform viewer opened. Simulation completed!"
