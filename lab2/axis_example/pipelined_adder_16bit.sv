`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: pipelined_adder_16bit
// Description: 2-stage pipelined 16-bit adder with AXI Stream interface
//              Pipeline: Input FF → add c1 → FF → add c2 → FF output
//              Uses 16 LSB bits of 32-bit AXI Stream data bus
//////////////////////////////////////////////////////////////////////////////////

module pipelined_adder_16bit (
    input  logic        aclk,
    input  logic        aresetn,
    // *** Control inputs ***
    input  logic [15:0] c1,  // Constant added in stage 1
    input  logic [15:0] c2,  // Constant added in stage 2
    // *** AXIS slave port ***
    output logic        s_axis_tready,
    input  logic [31:0] s_axis_tdata,
    input  logic        s_axis_tvalid,
    input  logic        s_axis_tlast,
    // *** AXIS master port ***
    input  logic        m_axis_tready,
    output logic [31:0] m_axis_tdata,
    output logic        m_axis_tvalid,
    output logic        m_axis_tlast
);

    //==========================================================================
    // Internal Signals
    //==========================================================================
    
    // Stage 0: Input registers
    logic [15:0] stage0_data;
    logic        stage0_valid;
    logic        stage0_last;
    
    // Stage 1: After first addition (add c1)
    logic [15:0] stage1_data;
    logic        stage1_valid;
    logic        stage1_last;
    
    // Stage 2: After second addition (add c2) - Output stage
    logic [15:0] stage2_data;
    logic        stage2_valid;
    logic        stage2_last;
    
    // Ready signals for each stage
    logic stage0_ready;
    logic stage1_ready;
    logic stage2_ready;
    
    // Pipeline done signal - set when TLAST has been output
    logic pipeline_done;
    
    //==========================================================================
    // AXI Stream Ready Logic
    //==========================================================================
    
    // Slave ready: ready to accept new data when stage 0 is ready AND pipeline not done
    assign s_axis_tready = stage0_ready && !pipeline_done;
    
    // Stage 0 ready: can accept new data when stage 1 is ready
    assign stage0_ready = stage1_ready;
    
    // Stage 1 ready: can accept data when stage 2 is ready
    assign stage1_ready = stage2_ready;
    
    // Stage 2 ready: can accept data when master is ready
    assign stage2_ready = m_axis_tready;
    
    //==========================================================================
    // Stage 0: Input Registers
    //==========================================================================
    
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            // Reset only control signals, not data
            stage0_valid <= 1'b0;
            stage0_last  <= 1'b0;
        end else if (stage0_ready) begin
            stage0_data  <= s_axis_tdata[15:0];  // Use 16 LSB bits
            stage0_valid <= s_axis_tvalid;
            stage0_last  <= s_axis_tlast;
        end
    end
    
    //==========================================================================
    // Stage 1: First Addition (add c1)
    //==========================================================================
    
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            // Reset only control signals, not data
            stage1_valid <= 1'b0;
            stage1_last  <= 1'b0;
        end else if (stage1_ready) begin
            // Add constant c1 to the data
            stage1_data  <= stage0_data + c1;
            stage1_valid <= stage0_valid;
            stage1_last  <= stage0_last;
        end
    end
    
    //==========================================================================
    // Stage 2: Second Addition (add c2) - Output Stage
    //==========================================================================
    
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            // Reset only control signals, not data
            stage2_valid <= 1'b0;
            stage2_last  <= 1'b0;
        end else if (stage2_ready) begin
            // Add constant c2 to the data
            stage2_data  <= stage1_data + c2;
            stage2_valid <= stage1_valid;
            stage2_last  <= stage1_last;
        end
    end
    
    //==========================================================================
    // Pipeline Done Logic
    //==========================================================================
    
    // Set pipeline_done when TLAST is output
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            pipeline_done <= 1'b0;
        end else begin
            // Set done when we output the last sample
            if (stage2_valid && stage2_last && m_axis_tready) begin
                pipeline_done <= 1'b1;
            end
        end
    end
    
    //==========================================================================
    // AXI Stream Master Output
    //==========================================================================
    
    // Output data: sign-extend 16-bit result to 32 bits
    assign m_axis_tdata  = {{16{stage2_data[15]}}, stage2_data};
    assign m_axis_tvalid = stage2_valid;
    assign m_axis_tlast  = stage2_last;

endmodule
