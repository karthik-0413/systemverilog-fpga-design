# RISC-V Single Cycle Processor Simulation Script
# This script compiles and runs the xsim simulation with waveform capture

# Set the working directory
set work_dir [file dirname [info script]]
cd $work_dir

# Create a new project (optional, can use file-based simulation)
puts "Starting RISC-V Single Cycle Processor Simulation..."

# Compile the design
puts "Compiling design files..."
xvlog -sv riscvsingle.sv

# Elaborate the design
puts "Elaborating design..."
xelab -debug all testbench

# Run simulation with waveform capture
puts "Running simulation..."
xsim testbench -gui -tclbatch run_sim_commands.tcl

puts "Simulation complete!"
