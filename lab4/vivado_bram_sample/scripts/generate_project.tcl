# Script to create RISC-V debug design for PYNQ-Z1

# Set project path
set proj_path [file dirname [file dirname [info script]]]

# Create Vivado project
create_project riscv_debug $proj_path -part xc7z020clg400-1 -force
set_property board_part www.digilentinc.com:pynq-z1:part0:1.0 [current_project]

# Add RTL source files
#   RV32I       — the RISC-V core (no internal BRAM, memory interface exposed)
#   riscv_wrapper — step controller + BRAM Port B + debug mux
add_files -norecurse [list \
  $proj_path/riscv_fast/rtl/riscv_fast.sv \
  $proj_path/riscv_fast/rtl/riscv_wrapper.v \
]
update_compile_order -fileset sources_1

# Create block design
create_bd_design "design_1"
update_compile_order -fileset sources_1

# -------------------------------------------------------
# Add Processing System 7 IP
# -------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]

# -------------------------------------------------------
# Add Block Memory Generator IP — True Dual Port
#   Port A: AXI BRAM Controller (PS uploads instructions)
#   Port B: riscv_wrapper       (CPU fetch / load / store)
# -------------------------------------------------------
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

# -------------------------------------------------------
# Add AXI BRAM Controller — single port (drives BRAM Port A)
# -------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0
set_property -dict [list \
  CONFIG.SINGLE_PORT_BRAM {1} \
  CONFIG.DATA_WIDTH {32} \
  CONFIG.ECC_TYPE {0} \
  CONFIG.MEM_DEPTH {1024} \
  CONFIG.PROTOCOL {AXI4} \
  CONFIG.SUPPORTS_NARROW_BURST {0} \
] [get_bd_cells axi_bram_ctrl_0]

# -------------------------------------------------------
# GPIO 0 — Reset control
#   Ch1 (output, 1-bit) : active-high reset to riscv_wrapper
#   Ch2 (input,  1-bit) : tied low (reserved / no 'done' signal)
# -------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
set_property -dict [list \
  CONFIG.C_ALL_OUTPUTS {1} \
  CONFIG.C_GPIO_WIDTH {1} \
  CONFIG.C_IS_DUAL {1} \
  CONFIG.C_ALL_INPUTS_2 {1} \
  CONFIG.C_GPIO2_WIDTH {1} \
] [get_bd_cells axi_gpio_0]

# -------------------------------------------------------
# GPIO 1 — Debug step/mux control
#   Ch1 (output, 5-bit) : debug_ctrl [4]=free_run [3]=step [2:0]=mux_sel
#   Ch2 (input, 32-bit) : debug_out  mux read-back
# -------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_1
set_property -dict [list \
  CONFIG.C_ALL_OUTPUTS {1} \
  CONFIG.C_GPIO_WIDTH {5} \
  CONFIG.C_IS_DUAL {1} \
  CONFIG.C_ALL_INPUTS_2 {1} \
  CONFIG.C_GPIO2_WIDTH {32} \
] [get_bd_cells axi_gpio_1]

# -------------------------------------------------------
# Constant tie-off for GPIO 0 Ch2 (no 'done' signal)
# -------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0
set_property -dict [list CONFIG.CONST_VAL {0} CONFIG.CONST_WIDTH {1}] [get_bd_cells xlconstant_0]

# -------------------------------------------------------
# Add custom RISC-V wrapper module
# -------------------------------------------------------
create_bd_cell -type module -reference riscv_wrapper riscv_wrapper_0

# -------------------------------------------------------
# BRAM connections
# -------------------------------------------------------
# AXI BRAM Controller → BRAM Port A (PS access)
connect_bd_intf_net [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTA]
# RISC-V wrapper → BRAM Port B (CPU access)
connect_bd_intf_net [get_bd_intf_pins riscv_wrapper_0/BRAM_PORTB] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTB]

# -------------------------------------------------------
# GPIO 0 connections — reset + tie-off
# -------------------------------------------------------
connect_bd_net [get_bd_pins axi_gpio_0/gpio_io_o]  [get_bd_pins riscv_wrapper_0/reset]
connect_bd_net [get_bd_pins xlconstant_0/dout]      [get_bd_pins axi_gpio_0/gpio2_io_i]

# -------------------------------------------------------
# GPIO 1 connections — debug step/mux
# -------------------------------------------------------
connect_bd_net [get_bd_pins axi_gpio_1/gpio_io_o]     [get_bd_pins riscv_wrapper_0/debug_ctrl]
connect_bd_net [get_bd_pins riscv_wrapper_0/debug_out] [get_bd_pins axi_gpio_1/gpio2_io_i]

# -------------------------------------------------------
# Clock and reset connections
# -------------------------------------------------------
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_bram_ctrl_0/s_axi_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_gpio_0/s_axi_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_gpio_1/s_axi_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins riscv_wrapper_0/clk]

connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins axi_gpio_0/s_axi_aresetn]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins axi_gpio_1/s_axi_aresetn]

# -------------------------------------------------------
# AXI interconnect automation
# -------------------------------------------------------
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_bram_ctrl_0/S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_gpio_0/S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins axi_gpio_0/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_gpio_1/S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins axi_gpio_1/S_AXI]

# Assign addresses
assign_bd_address [get_bd_addr_segs axi_gpio_1/S_AXI/Reg]

# -------------------------------------------------------
# Validate and save
# -------------------------------------------------------
validate_bd_design
save_bd_design

# Setup the wrapper for implementation
make_wrapper -files [get_files "${proj_path}/riscv_debug.srcs/sources_1/bd/design_1/design_1.bd"] -top
add_files -norecurse "${proj_path}/riscv_debug.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v"
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
write_hw_platform -fixed -force -include_bit -file [get_property DIRECTORY [current_project]]/export/riscv_debug_overlay.xsa

puts "Done creating RISC-V debug overlay"
puts "Overlay file: [get_property DIRECTORY [current_project]]/export/riscv_debug_overlay.xsa"