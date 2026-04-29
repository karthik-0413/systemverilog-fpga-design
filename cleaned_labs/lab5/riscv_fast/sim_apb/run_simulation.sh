#!/bin/bash

# RISC-V APB Program Simulation Script

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "Starting RISC-V APB Program Simulation..."
echo ""

echo "Compiling design files..."
xvlog -sv ../rtl/riscv_fast.sv ../rtl/riscv_top.sv ../rtl/apb_top.sv bram_4kb.sv ../rtl/mem_to_apb_bridge.sv ../rtl/apb_gpio.sv ../rtl/apb_timer.sv riscv_apb_tb.sv
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
echo "Running simulation..."
xsim testbench -tclbatch run_sim_commands.tcl

echo ""
echo "Simulation complete!"
echo "Waveforms saved to: wave.wdb (xsim native format)"
echo "Configuration saved to: wave.wcfg"
echo ""
