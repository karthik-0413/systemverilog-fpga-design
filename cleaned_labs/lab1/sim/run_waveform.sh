#!/bin/bash
# Run exhaustive testbench with waveform dumping and viewing
# Tests MAXVAL x MAXVAL combinations and opens waveform viewer

echo "========================================"
echo "Testing Exhaustive with Waveform Dump"
echo "========================================"
echo ""

# Clean previous files
rm -rf xsim.dir *.wdb *.jou *.log *.wcfg setup_waves.tcl

# Compile
echo "[1/4] Compiling RTL..."
xvlog -sv ../rtl/full_adder.sv ../rtl/adder_16bit.sv || exit 1

echo "[2/4] Compiling testbench..."
xvlog -sv tb_adder_exhaustive.sv || exit 1

echo "[3/4] Setting up waveforms..."

# Create TCL script for waveform setup and simulation
# -recursive stores all signals in the tb and instantiated module
cat > run_with_waves.tcl << 'EOF'
log_wave -recursive /tb_adder_exhaustive/*
run all
EOF

echo "[4/4] Running simulation with waveform capture..."
xelab -debug typical tb_adder_exhaustive -s sim || exit 1
xsim sim -gui -tclbatch run_with_waves.tcl -wdb tb_adder_exhaustive.wdb


echo ""
echo "Waveform viewer opened. Simulation completed!"

# NOTE
# If you make any edits to waveform --> you can run "save_wave_config myconfig_name.wcfg" in TCL shell to save changes
# Next tiem you rerun the simulation --> you can run "open_wave_config myconfig_name.wcfg" in TCL shell to load changes
