# Interactive BRAM test design creation for PYNQ-Z1
# This script shows progress for interactive viewing

# Set project path
set proj_path [file dirname [file dirname [info script]]]

# Create Vivado project
create_project bram_test $proj_path -part xc7z020clg400-1 -force
set_property board_part www.digilentinc.com:pynq-z1:part0:1.0 [current_project]

puts "=== STEP 1: Project Created ==="
puts "Project created at: $proj_path"

# Add RTL source files (reference external files, don't import)
add_files -norecurse [glob $proj_path/src/*.sv $proj_path/src/*.v]
# Remove import_files to use external sources directly
# import_files -force -norecurse
update_compile_order -fileset sources_1

puts "=== STEP 2: RTL Sources Added ==="
puts "Added bram_test_fsm.sv and bram_wrapper.v"
puts "Check the Sources window to see the files"

# Create block design
create_bd_design "design_1"
update_compile_order -fileset sources_1

puts "=== STEP 3: Block Design Created ==="
puts "Empty block design 'design_1' created"

# Add Processing System 7 IP
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

puts "=== STEP 4: PS7 Added ==="
puts "Processing System 7 added to block design"

# Configure PS7 for PYNQ-Z1
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]

puts "=== STEP 5: PS7 Configured ==="
puts "PS7 configured for PYNQ-Z1 with external ports"

# Add Block Memory Generator IP - Dual Port for AXI + RTL
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_0
set_property -dict [list \
  CONFIG.Memory_Type {True_Dual_Port_RAM} \
  CONFIG.Write_Width_A {32} \
  CONFIG.Write_Depth_A {1024} \
  CONFIG.Read_Width_A {32} \
  CONFIG.Write_Width_B {32} \
  CONFIG.Read_Width_B {32} \
  CONFIG.Operating_Mode_A {WRITE_FIRST} \
  CONFIG.Operating_Mode_B {WRITE_FIRST} \
  CONFIG.Enable_A {Use_ENA_Pin} \
  CONFIG.Enable_B {Use_ENB_Pin} \
  CONFIG.Use_Byte_Write_Enable {true} \
  CONFIG.Byte_Size {8} \
  CONFIG.Assume_Synchronous_Clk {false} \
  CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
  CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
] [get_bd_cells blk_mem_gen_0]

puts "=== STEP 6: Block Memory Generator Added ==="
puts "BRAM configured as 4K dual-port with byte write enable"
puts "  Port A: Will connect to AXI BRAM Controller (Python access)"
puts "  Port B: Will connect to Custom RTL FSM (RISC-V style)"

# Add AXI BRAM Controller with proper configuration - single port (Port A only)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0
set_property -dict [list \
  CONFIG.SINGLE_PORT_BRAM {1} \
  CONFIG.DATA_WIDTH {32} \
  CONFIG.ECC_TYPE {0} \
  CONFIG.MEM_DEPTH {1024} \
  CONFIG.PROTOCOL {AXI4} \
  CONFIG.SUPPORTS_NARROW_BURST {0} \
] [get_bd_cells axi_bram_ctrl_0]

puts "=== STEP 7: AXI BRAM Controller Added ==="
puts "AXI BRAM Controller will provide Python access to Port A"

# Add AXI GPIO IP - Dual channel for start/output and busy/done input
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0

# Configure GPIO - Channel 1: output (reset), Channel 2: input (done)
set_property -dict [list \
  CONFIG.C_ALL_OUTPUTS {1} \
  CONFIG.C_GPIO_WIDTH {1} \
  CONFIG.C_IS_DUAL {1} \
  CONFIG.C_ALL_INPUTS_2 {1} \
  CONFIG.C_GPIO2_WIDTH {1} \
] [get_bd_cells axi_gpio_0]

puts "=== STEP 8: AXI GPIO Added ==="
puts "GPIO Channel 1: Reset signal (output) - assert to reset, deassert to run"
puts "GPIO Channel 2: Done signal (input)"

# Add custom BRAM wrapper module
create_bd_cell -type module -reference bram_wrapper bram_wrapper_0

puts "=== STEP 9: Custom FSM Wrapper Added ==="
puts "bram_wrapper_0 added with RISC-V-style interface"

# Connect AXI BRAM Controller to Port A
connect_bd_intf_net [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTA]

puts "=== STEP 10: BRAM Port A Connected ==="
puts "AXI BRAM Controller connected to BRAM Port A (Python access)"

# Connect FSM wrapper to BRAM Port B via standard interface
connect_bd_intf_net [get_bd_intf_pins bram_wrapper_0/BRAM_PORTB] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTB]

puts "=== STEP 11: BRAM Port B Connected ==="
puts "FSM wrapper connected to BRAM Port B (RISC-V-style RTL)"

# Connect GPIO ch1 output to FSM reset (assert=reset, deassert=run)
connect_bd_net [get_bd_pins axi_gpio_0/gpio_io_o] [get_bd_pins bram_wrapper_0/reset]
# Connect FSM done directly to GPIO ch2 input
connect_bd_net [get_bd_pins bram_wrapper_0/done] [get_bd_pins axi_gpio_0/gpio2_io_i]

puts "=== STEP 12: GPIO Signals Connected ==="
puts "Reset signal connected to GPIO ch1, Done signal connected to GPIO ch2"

# Connect clock and reset
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_bram_ctrl_0/s_axi_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_gpio_0/s_axi_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins bram_wrapper_0/clk]

connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins axi_gpio_0/s_axi_aresetn]

puts "=== STEP 13: Clock and Reset Connected ==="
puts "All clock and reset signals connected"

# Apply AXI interconnect automation
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_bram_ctrl_0/S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_gpio_0/S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins axi_gpio_0/S_AXI]

puts "=== STEP 14: AXI Interconnect Automated ==="
puts "SmartConnect and all AXI connections made"

# Assign AXI addresses (auto-assigned by Vivado)
assign_bd_address [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0]
assign_bd_address [get_bd_addr_segs axi_gpio_0/S_AXI/Reg]

# Get assigned addresses for display
set bram_seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces processing_system7_0/Data] -filter {NAME =~ *axi_bram_ctrl*}]
set gpio_seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces processing_system7_0/Data] -filter {NAME =~ *axi_gpio*}]
set bram_offset [get_property OFFSET $bram_seg]
set gpio_offset [get_property OFFSET $gpio_seg]

puts "=== STEP 15: AXI Address Ranges Assigned ==="
puts "BRAM offset: $bram_offset"
puts "GPIO offset: $gpio_offset"
puts "(Check Address Editor for complete memory map)"

# Validate and save block design
validate_bd_design
save_bd_design

puts "=== STEP 16: Block Design Validated and Saved ==="
puts "Design validation complete"
puts "You can now see the complete block diagram!"

# Setup the wrapper for implementation
make_wrapper -files [get_files "${proj_path}/bram_test.srcs/sources_1/bd/design_1/design_1.bd"] -top
add_files -norecurse "${proj_path}/bram_test.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v"
update_compile_order -fileset sources_1
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "=== STEP 17: Wrapper Created ==="

# Run Synthesis
puts "Starting synthesis..."
launch_runs synth_1 -jobs 8
wait_on_run synth_1
puts "Synthesis complete!"

puts "=== STEP 18: Synthesis Complete ==="

# Run Implementation
puts "Starting implementation..."
launch_runs impl_1 -jobs 8
wait_on_run impl_1
puts "Implementation complete!"

puts "=== STEP 19: Implementation Complete ==="

# Generate Bitstream
puts "Generating bitstream..."
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "Bitstream generated!"

puts "=== STEP 20: Bitstream Generated ==="

# Export Overlay
write_hw_platform -fixed -force -include_bit -file [get_property DIRECTORY [current_project]]/export/bram_test_overlay.xsa

puts "=== STEP 21: XSA Exported ==="
puts "Overlay file: [get_property DIRECTORY [current_project]]/export/bram_test_overlay.xsa"

puts "=== BUILD COMPLETE ==="
