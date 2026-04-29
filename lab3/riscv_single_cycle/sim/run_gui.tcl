# RISC-V Simulation with GUI
# This script opens the xsim GUI and allows interactive simulation control

# Log all signals in the design
# This captures signals to the default xsim waveform database
log_wave [get_objects -r *]

# Run the simulation for 500 ns
# This will execute automatically and capture waveforms
run 500 ns

puts "Simulation completed!"
puts "Waveforms saved in xsim native format"
