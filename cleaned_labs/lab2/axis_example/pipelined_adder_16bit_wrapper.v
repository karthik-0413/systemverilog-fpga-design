`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: pipelined_adder_16bit_wrapper
// Description: Verilog wrapper for pipelined_adder_16bit SystemVerilog module
//              for use in Vivado block diagram
//////////////////////////////////////////////////////////////////////////////////

module pipelined_adder_16bit_wrapper (
    input  wire         aclk,
    input  wire         aresetn,
    // *** Control inputs ***
    input  wire [15:0]  c1,  // Constant added in stage 1
    input  wire [15:0]  c2,  // Constant added in stage 2
    // *** AXIS slave port ***
    output wire         s_axis_tready,
    input  wire [31:0]  s_axis_tdata,
    input  wire         s_axis_tvalid,
    input  wire         s_axis_tlast,
    // *** AXIS master port ***
    input  wire         m_axis_tready,
    output wire [31:0]  m_axis_tdata,
    output wire         m_axis_tvalid,
    output wire         m_axis_tlast
);

    //==========================================================================
    // Instantiate the SystemVerilog pipelined adder module
    //==========================================================================
    
    pipelined_adder_16bit u_pipelined_adder (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .c1            (c1),
        .c2            (c2),
        .s_axis_tready (s_axis_tready),
        .s_axis_tdata  (s_axis_tdata),
        .s_axis_tvalid (s_axis_tvalid),
        .s_axis_tlast  (s_axis_tlast),
        .m_axis_tready (m_axis_tready),
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tlast  (m_axis_tlast)
    );

endmodule
