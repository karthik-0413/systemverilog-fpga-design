
create_project -force axis_proj axis_proj -part xc7z020clg400-1
set_property board_part www.digilentinc.com:pynq-z1:part0:1.0 [current_project]

add_files -norecurse {axis_example/pipelined_adder_16bit_wrapper.v axis_example/pipelined_adder_16bit.sv}

import_files -force -norecurse
update_compile_order -fileset sources_1
create_bd_design "axis_proj"
update_compile_order -fileset sources_1

source axis_proj_block_design.tcl

make_wrapper -files [get_files axis_proj/axis_proj.srcs/sources_1/bd/axis_proj/axis_proj.bd] -top
add_files -norecurse axis_proj/axis_proj.gen/sources_1/bd/axis_proj/hdl/axis_proj_wrapper.v
update_compile_order -fileset sources_1
set_property top axis_proj_wrapper [current_fileset]
update_compile_order -fileset sources_1

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

file mkdir axis_proj/export
write_hw_platform -fixed -include_bit -force -file axis_proj/export/axis_proj_wrapper.xsa