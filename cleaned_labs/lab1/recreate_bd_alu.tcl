

# Script to recreate the Vivado block design for Lab 1

# Set project path
set proj_path "./proj3"

# Create Vivado project
create_project proj3 proj3 -part xc7z020clg400-1 -force
set_property board_part www.digilentinc.com:pynq-z1:part0:1.0 [current_project]

# Add RTL source files
add_files -norecurse {rtl/alu_16bit.sv rtl/alu_16bit_wrapper.v}
import_files -force -norecurse
update_compile_order -fileset sources_1
# Create block design
create_bd_design "design_1"
update_compile_order -fileset sources_1

# Add Processing System 7 IP
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

# Add AXI GPIO IPs for inputs and outputs
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_1
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_2

# Configure GPIO properties (location commented out)
#set_property location {1 -203 -335} [get_bd_cells axi_gpio_0]
# Configure GPIO 0 as input

set_property -dict [list \
  CONFIG.C_ALL_OUTPUTS {1} \
  CONFIG.C_ALL_OUTPUTS_2 {1} \
  CONFIG.C_GPIO2_WIDTH {5} \
  CONFIG.C_GPIO_WIDTH {3} \
  CONFIG.C_IS_DUAL {1} \
] [get_bd_cells axi_gpio_2]

set_property -dict [list \
  CONFIG.C_ALL_OUTPUTS {1} \
  CONFIG.C_ALL_OUTPUTS_2 {1} \
  CONFIG.C_GPIO2_WIDTH {16} \
  CONFIG.C_GPIO_WIDTH {16} \
  CONFIG.C_IS_DUAL {1} \
] [get_bd_cells axi_gpio_1]

set_property -dict [list \
  CONFIG.C_ALL_INPUTS {1} \
  CONFIG.C_GPIO_WIDTH {32} \
] [get_bd_cells axi_gpio_0]


# Add adder wrapper module
create_bd_cell -type module -reference alu_16bit_wrapper alu_16bit_wrapper
#set_property location {3 250 -459} [get_bd_cells adder_16bit_wrapper_0]
# Connect adder outputs to GPIO inputs
connect_bd_net [get_bd_pins alu_16bit_wrapper/result] [get_bd_pins axi_gpio_0/gpio_io_i]
connect_bd_net [get_bd_pins axi_gpio_1/gpio_io_o] [get_bd_pins alu_16bit_wrapper/a]
connect_bd_net [get_bd_pins axi_gpio_1/gpio2_io_o] [get_bd_pins alu_16bit_wrapper/b]
connect_bd_net [get_bd_pins axi_gpio_2/gpio_io_o] [get_bd_pins alu_16bit_wrapper/control]
connect_bd_net [get_bd_pins axi_gpio_2/gpio2_io_o] [get_bd_pins alu_16bit_wrapper/shift_amount]


# Apply automation for PS7 external connections
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_gpio_0/S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins axi_gpio_0/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_gpio_1/S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins axi_gpio_1/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_gpio_2/S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins axi_gpio_2/S_AXI]

validate_bd_design
save_bd_design


# Setup the wrapper for implementation
make_wrapper -files [get_files "${proj_path}/proj3.srcs/sources_1/bd/design_1/design_1.bd"] -top
add_files -norecurse "${proj_path}/proj3.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v"
update_compile_order -fileset sources_1
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1


# Run Synthesis
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# Run Implementation
launch_runs impl_1 -jobs 8
wait_on_run impl_1

# Generate Bitstream (Required for the .xsa to include the bit file)
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1


# Export Overlay
write_hw_platform -fixed -force -include_bit -file [get_property DIRECTORY [current_project]]/export/my_overlay.xsa


puts "Done creating overlay. Copy to board"
puts ""