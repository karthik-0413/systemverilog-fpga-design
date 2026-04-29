open_component -reset component_fir -flow_target vivado

add_files fir.cpp
add_files -tb fir_test.cpp
add_files -tb input.txt
add_files -tb golden.txt

set_top fir
set_part {xc7z020-clg400-1}
create_clock -period 10.0

set hls_export_ip 1

csim_design
csynth_design

if {$hls_export_ip == 1} {
    cosim_design
    export_design -format ip_catalog
}
