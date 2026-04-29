`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: fir_filter_parallel.v
// Description: Verilog wrapper for fir_filter_parallel.sv
//////////////////////////////////////////////////////////////////////////////////

module fir_filter_parallel_wrapper (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire [0:0]  stream_load_coeff_en,
    
    // AXI-Stream Slave
    output wire        s_axis_tready,
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    input  wire        s_axis_tlast,
    
    // AXI-Stream Master
    input  wire        m_axis_tready,
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    output wire        m_axis_tlast
);

    fir_filter_parallel fir_inst (
        .aclk(aclk),
        .aresetn(aresetn),
        .stream_load_coeff_en(stream_load_coeff_en),
        .s_axis_tready(s_axis_tready),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tready(m_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast(m_axis_tlast)
    );

endmodule