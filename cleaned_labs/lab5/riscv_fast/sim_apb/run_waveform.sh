#!/bin/bash

# RISC-V APB Program Simulation Script with waveform capture

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "Starting RISC-V APB Program Simulation with waveform capture..."
echo ""

echo "Compiling design files..."
xvlog -sv ../rtl/riscv_fast.sv ../rtl/riscv_top.sv bram_4kb.sv ../rtl/mem_to_apb_bridge.sv ../rtl/apb_gpio.sv riscv_apb_tb.sv
if [ $? -ne 0 ]; then
    echo "Compilation failed!"
    exit 1
fi

echo ""
echo "Elaborating design..."
xelab -debug all testbench
if [ $? -ne 0 ]; then
    echo "Elaboration failed!"
    exit 1
fi

echo ""
echo "Running simulation and capturing waveforms..."
xsim testbench --wdb wave.wdb --tclbatch run_waveform.tcl

echo ""
echo "Simulation complete!"
echo "Waveform database saved to: wave.wdb"
echo "Open it in Vivado with the waveform viewer."
echo ""