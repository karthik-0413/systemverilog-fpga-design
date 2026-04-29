.PHONY: all clean sim

all: sim

clean:
	rm -rf xsim.dir *.pb *.jou *.log *.wdb

sim: clean
	bash run_sim.sh

# Run simulation in batch mode (no GUI)
batch: clean
	xvlog -sv ../axis_fir_4tap_tm.sv
	xvlog -sv tb_axis_fir_4tap_tm.sv
	xelab -debug typical tb_axis_fir_4tap_tm -s sim
	xsim sim -runall -nolog
