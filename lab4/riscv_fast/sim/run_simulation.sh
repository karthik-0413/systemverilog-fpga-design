#!/bin/bash

# RISC-V Fast Processor Simulation Script
# This script runs the xsim simulation with waveform capture

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "Starting RISC-V Fast Processor Simulation..."
echo ""

# Compile the design files
echo "Compiling design files..."
xvlog -sv ../rtl/bram.sv ../rtl/riscv_fast.sv ../rtl/riscv_top.sv riscv_fast_tb.sv
if [ $? -ne 0 ]; then
    echo "Compilation failed!"
    exit 1
fi

echo ""
# Elaborate the design
echo "Elaborating design..."
xelab -debug all testbench
if [ $? -ne 0 ]; then
    echo "Elaboration failed!"
    exit 1
fi

echo ""
# Run simulation with waveform capture
echo "Running simulation..."
xsim testbench -tclbatch run_sim_commands.tcl

echo ""
echo "Simulation complete!"
echo "Waveforms saved to: wave.wdb (xsim native format)"
echo "Configuration saved to: wave.wcfg"
echo ""
echo "To view waveforms in Vivado:"
echo "  File → Open → Open Waveform → Select wave.wdb"
echo ""
