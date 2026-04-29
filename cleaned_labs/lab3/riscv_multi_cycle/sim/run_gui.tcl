# RISC-V Multi Cycle Simulation with GUI
# This script opens the xsim GUI and allows interactive simulation control

# Log all signals in the design
# This captures signals to the default xsim waveform database
log_wave [get_objects -r *]

# Run the simulation for 2000 ns
# This will execute automatically and capture waveforms
# Multi-cycle processor requires more time than single-cycle
run 2000 ns

puts "Simulation completed!"
puts "Waveforms saved in xsim native format"
