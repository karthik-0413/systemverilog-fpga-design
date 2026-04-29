# RISC-V Simulation Commands
# Set up waveforms in xsim native format and run simulation

# Log all signals in the testbench hierarchy
# This captures signals to the default xsim waveform database
log_wave [get_objects -r *]

# Run for 500 ns (enough time for the test to complete)
# The program has about 21 instructions at 10ns/cycle = 210ns minimum
# Adding buffer for any timing variations
run 500 ns

# Exit the simulation
quit
