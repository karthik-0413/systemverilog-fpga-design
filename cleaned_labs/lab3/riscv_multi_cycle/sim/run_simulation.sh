#!/bin/bash

# RISC-V Multi Cycle Processor Simulation Script
# This script runs the xsim simulation with waveform capture

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "Starting RISC-V Multi Cycle Processor Simulation..."
echo ""

# Compile the design files
echo "Compiling design files..."
xvlog -sv ../rtl/riscvmulti.sv riscvmulti_tb.sv
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
echo "Waveforms saved to: xsim.wdb (xsim native format)"
echo ""
echo "To view waveforms in Vivado:"
echo "  File → Open → Open Waveform → Select xsim.wdb"
echo ""
