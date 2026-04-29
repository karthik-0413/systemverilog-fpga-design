# RISC-V Fast Processor Simulation Commands
# Set up waveforms in xsim native format and run simulation

# Log all signals in the testbench hierarchy
# This captures signals to the default xsim waveform database
log_wave [get_objects -r *]

# Run for 10000 ns to match the testbench timeout
# The testbench has a built-in timeout at 10000ns, so run long enough
# for the test to complete or timeout
run 10000 ns

# Exit the simulation
quit
