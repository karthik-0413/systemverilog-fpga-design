# Waveform setup for 4-tap FIR filter simulation (Unified FSM)

# Add all signals to waveform
add_wave {{/tb_axis_fir_4tap_tm_fsm_unified/*}}

# Add DUT internal signals
add_wave {{/tb_axis_fir_4tap_tm_fsm_unified/dut/*}}

# Run simulation for 2000ns
run 2000ns
exit
