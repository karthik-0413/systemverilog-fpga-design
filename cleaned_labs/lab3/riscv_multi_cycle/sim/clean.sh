#!/bin/bash
# Clean simulation output files

echo "Cleaning simulation output files..."

rm -rf xsim.dir
rm -rf .Xil
rm -f *.log
rm -f *.jou
rm -f xsim.wdb
rm -f xsim.wcfg
rm -f webtalk*.log
rm -f webtalk*.jou
rm -f *.pb
rm -f work.testbench.wdb

echo "Clean complete!"
