.PHONY: sim clean help

help:
	@echo "RISC-V Single Cycle Processor Simulation Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make sim    - Run the simulation"
	@echo "  make clean  - Clean simulation output files"
	@echo "  make help   - Show this help message"

sim:
	bash run_simulation.sh

clean:
	rm -rf xsim.dir .Xil *.log *.jou
	rm -f wave.wdb wave.wcfg
	rm -f webtalk*.log webtalk*.jou
	@echo "Simulation output cleaned"
