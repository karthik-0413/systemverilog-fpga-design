#!/bin/bash
# Simulation script for 4-tap parallel FIR filter (Unified FSM version)

set -e

echo "=========================================="
echo "  Compiling RTL and Testbench (Unified FSM)"
echo "=========================================="

# Compile SystemVerilog modules
xvlog -sv ../axis_fir_4tap_tm_fsm_unified.sv
xvlog -sv tb_axis_fir_4tap_tm_fsm_unified.sv

echo ""
echo "=========================================="
echo "  Elaborating Design"
echo "=========================================="

# Elaborate testbench
xelab -debug typical tb_axis_fir_4tap_tm_fsm_unified -s sim_fsm_unified

echo ""
echo "=========================================="
echo "  Running Simulation"
echo "=========================================="

# Run simulation

#xsim sim_fsm_unified -gui -tclbatch run_with_waves_fsm_unified.tcl
xsim sim_fsm_unified -tclbatch run_with_waves_fsm_unified.tcl

echo ""
echo "=========================================="
echo "  Simulation Complete"
echo "=========================================="
