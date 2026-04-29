#!/bin/bash
# Run simulation with waveform dumping

echo "========================================"
echo "Pipelined Adder 16-bit Simulation"
echo "========================================"
echo ""

# Clean previous files
rm -rf xsim.dir *.wdb *.jou *.log

# Compile DUT
echo "[1/4] Compiling DUT..."
xvlog -sv ../pipelined_adder_16bit.sv || exit 1

# Compile testbench
echo "[2/4] Compiling testbench..."
xvlog -sv tb_pipelined_adder_16bit.sv || exit 1

# Create TCL script for waveform setup
echo "[3/4] Setting up waveforms..."
cat > run_with_waves.tcl << 'EOF'
log_wave -recursive /tb_pipelined_adder_16bit/*
run all
EOF

# Run simulation with waveform capture
echo "[4/4] Running simulation with waveform capture..."
xelab -debug typical tb_pipelined_adder_16bit -s sim || exit 1
xsim sim -gui -tclbatch run_with_waves.tcl -wdb tb_pipelined_adder_16bit.wdb
#xsim sim -tclbatch run_with_waves.tcl -wdb tb_pipelined_adder_16bit.wdb

echo ""
echo "Waveform viewer opened. Simulation completed!"
