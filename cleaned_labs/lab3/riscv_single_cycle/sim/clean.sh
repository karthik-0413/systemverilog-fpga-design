#!/bin/bash
# Clean simulation output files

echo "Cleaning simulation output files..."

rm -rf xsim.dir
rm -rf .Xil
rm -f *.log
rm -f *.jou
rm -f wave.wdb
rm -f wave.wcfg
rm -f webtalk*.log
rm -f webtalk*.jou

echo "Clean complete!"
