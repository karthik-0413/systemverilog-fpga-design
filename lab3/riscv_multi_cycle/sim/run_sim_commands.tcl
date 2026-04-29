# RISC-V Multi Cycle Simulation Commands
# Set up waveforms in xsim native format and run simulation

# Log all signals in the testbench hierarchy
# This captures signals to the default xsim waveform database
log_wave [get_objects -r *]

# Run for 2000 ns
# Multi-cycle processor takes multiple cycles per instruction
# ~30 instructions × 5-6 cycles average × 10ns/cycle = ~1500-1800ns
# Adding buffer for timing variations
run 2000 ns

# Exit the simulation
quit
