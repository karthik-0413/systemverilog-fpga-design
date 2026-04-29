/**
 * AXI-Stream FIR Filter Wrapper for Vivado Block Diagram Integration
 *
 * This wrapper adapts the SystemVerilog module for use in Vivado
 * block designs with standard AXI-Stream interfaces.
 *
 * Interfaces:
 * - AXI-Stream Slave (input data/coefficients)
 * - AXI-Stream Master (filtered output)
 * - GPIO Control (stream_load_coeff_en for coefficient loading)
 */

(* IP_DEFINITION_SOURCE = "Module RTL" *)
module axis_fir_4tap_tm_wrapper #(
    parameter integer C_AXIS_TDATA_WIDTH = 32
) (
    // Clock and Reset
    input  wire        aclk,
    input  wire        aresetn,

    // GPIO Control Signal (from AXI GPIO)
    input  wire        stream_load_coeff_en,

    // AXI-Stream Slave Interface (Input)
    output wire        s_axis_tready,
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    input  wire        s_axis_tlast,

    // AXI-Stream Master Interface (Output)
    input  wire        m_axis_tready,
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    output wire        m_axis_tlast
);

    // Instantiate the core FIR filter module
    axis_fir_4tap_tm_fsm_unified fir_inst (
        .aclk               (aclk),
        .aresetn            (aresetn),
        .stream_load_coeff_en(stream_load_coeff_en),
        .s_axis_tready      (s_axis_tready),
        .s_axis_tdata       (s_axis_tdata),
        .s_axis_tvalid      (s_axis_tvalid),
        .s_axis_tlast       (s_axis_tlast),
        .m_axis_tready      (m_axis_tready),
        .m_axis_tdata       (m_axis_tdata),
        .m_axis_tvalid      (m_axis_tvalid),
        .m_axis_tlast       (m_axis_tlast)
    );

endmodule : axis_fir_4tap_tm_wrapper
