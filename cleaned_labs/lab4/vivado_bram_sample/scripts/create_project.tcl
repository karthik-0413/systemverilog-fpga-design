# Script to create BRAM test design for PYNQ-Z1

# Set project path
set proj_path [file dirname [file dirname [info script]]]

# Create Vivado project
create_project bram_test $proj_path -part xc7z020clg400-1 -force
set_property board_part www.digilentinc.com:pynq-z1:part0:1.0 [current_project]

# Add RTL source files (reference external files, don't import)
add_files -norecurse [glob $proj_path/src/*.sv $proj_path/src/*.v]
# Remove import_files to use external sources directly
# import_files -force -norecurse
update_compile_order -fileset sources_1

# Create block design
create_bd_design "design_1"
update_compile_order -fileset sources_1

# Add Processing System 7 IP
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

# Configure PS7 for PYNQ-Z1
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]

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

# Add AXI BRAM Controller - single port (Port A only)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0
set_property -dict [list \
  CONFIG.SINGLE_PORT_BRAM {1} \
  CONFIG.DATA_WIDTH {32} \
  CONFIG.ECC_TYPE {0} \
  CONFIG.MEM_DEPTH {1024} \
  CONFIG.PROTOCOL {AXI4} \
  CONFIG.SUPPORTS_NARROW_BURST {0} \
] [get_bd_cells axi_bram_ctrl_0]

# Add AXI GPIO IP - single dual-channel GPIO
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
set_property -dict [list \
  CONFIG.C_ALL_OUTPUTS {1} \
  CONFIG.C_GPIO_WIDTH {1} \
  CONFIG.C_IS_DUAL {1} \
  CONFIG.C_ALL_INPUTS_2 {1} \
  CONFIG.C_GPIO2_WIDTH {1} \
] [get_bd_cells axi_gpio_0]

# Add custom BRAM wrapper module
create_bd_cell -type module -reference bram_wrapper bram_wrapper_0

# Connect AXI BRAM Controller to Port A
connect_bd_intf_net [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTA]

# Connect FSM wrapper to BRAM Port B via standard interface
connect_bd_intf_net [get_bd_intf_pins bram_wrapper_0/BRAM_PORTB] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTB]

# Connect GPIO ch1 output to FSM reset (assert=reset, deassert=run)
connect_bd_net [get_bd_pins axi_gpio_0/gpio_io_o] [get_bd_pins bram_wrapper_0/reset]
# Connect FSM done directly to GPIO ch2 input
# connect_bd_net [get_bd_pins bram_wrapper_0/done] [get_bd_pins axi_gpio_0/gpio2_io_i]

# Connect clock and reset
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_bram_ctrl_0/s_axi_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_gpio_0/s_axi_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins bram_wrapper_0/clk]

connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins axi_gpio_0/s_axi_aresetn]

# Apply AXI interconnect automation
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_bram_ctrl_0/S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_gpio_0/S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins axi_gpio_0/S_AXI]

# Validate and save block design
validate_bd_design
save_bd_design

# Setup the wrapper for implementation
make_wrapper -files [get_files "${proj_path}/bram_test.srcs/sources_1/bd/design_1/design_1.bd"] -top
add_files -norecurse "${proj_path}/bram_test.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v"
update_compile_order -fileset sources_1
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Run Synthesis
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# Run Implementation
launch_runs impl_1 -jobs 8
wait_on_run impl_1

# Generate Bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# Export Overlay
write_hw_platform -fixed -force -include_bit -file [get_property DIRECTORY [current_project]]/export/bram_test_overlay.xsa

puts "Done creating BRAM test overlay"
puts "Overlay file: [get_property DIRECTORY [current_project]]/export/bram_test_overlay.xsa"
