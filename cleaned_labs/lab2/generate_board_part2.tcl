
create_project -force fir_proj fir_proj -part xc7z020clg400-1
set_property board_part www.digilentinc.com:pynq-z1:part0:1.0 [current_project]

add_files -norecurse {fir_golden_model/fir_filter_parallel_wrapper.v fir_golden_model/fir_filter_parallel.sv}

import_files -force -norecurse
update_compile_order -fileset sources_1
create_bd_design "fir_proj"
update_compile_order -fileset sources_1

source fir_proj_block_design.tcl

make_wrapper -files [get_files fir_proj/fir_proj.srcs/sources_1/bd/fir_proj/fir_proj.bd] -top
add_files -norecurse fir_proj/fir_proj.gen/sources_1/bd/fir_proj/hdl/fir_proj_wrapper.v
update_compile_order -fileset sources_1
set_property top fir_proj_wrapper [current_fileset]
update_compile_order -fileset sources_1

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

file mkdir fir_proj/export
write_hw_platform -fixed -include_bit -force -file fir_proj/export/fir_proj_wrapper.xsa
