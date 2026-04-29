`timescale 1ns / 1ps

/**
 * Pipelined 64-Tap FIR Filter with 4-Stage Pipeline
 * Pipeline: Multiply → Tree1 (64→32) → Tree2 (32→16) → Tree3 (16→1) + Output
 * Optimized for timing with deeper adder tree
 */

module fir_filter_parallel (
    input  logic        aclk,
    input  logic        aresetn,
    input  logic [0:0]  stream_load_coeff_en,

    // AXI-Stream Slave (Input)
    output logic        s_axis_tready,
    input  logic [31:0] s_axis_tdata,
    input  logic        s_axis_tvalid,
    input  logic        s_axis_tlast,

    // AXI-Stream Master (Output)
    input  logic        m_axis_tready,
    output logic [31:0] m_axis_tdata,
    output logic        m_axis_tvalid,
    output logic        m_axis_tlast
);

    localparam int TAPS = 64;
    localparam int DATA_WIDTH = 16;
    localparam int COEFF_WIDTH = 16;

    // ========================================================================
    // FSM State Definitions
    // ========================================================================
    typedef enum logic [1:0] {
        IDLE       = 2'b00,
        COEFF_LOAD = 2'b01,
        DATA_FILL  = 2'b10,
        DATA_PROC  = 2'b11
    } state_t;

    state_t current_state, next_state;

    // ========================================================================
    // Shift Registers and Control
    // ========================================================================
    logic signed [DATA_WIDTH-1:0]  data_shreg [0:TAPS-1];
    logic signed [COEFF_WIDTH-1:0] coeff_shreg [0:TAPS-1];
    logic [$clog2(TAPS+1):0]       sample_count;

    logic coeff_shift_en;
    logic data_shift_en;

    wire s_axis_fire = s_axis_tvalid && s_axis_tready;
    wire m_axis_fire = m_axis_tvalid && m_axis_tready;

    // ========================================================================
    // Pipeline Stages
    // ========================================================================
    
    // Stage 0: Input control
    logic stage0_valid, stage0_last, stage0_load_coeff;
    
    // Stage 1: Multiply (64 products)
    logic signed [DATA_WIDTH+COEFF_WIDTH-1:0] stage1_products [0:TAPS-1];
    logic stage1_valid, stage1_last, stage1_load_coeff;
    
    // Stage 2: Sum tree level 1 (64→32 sums)
    logic signed [DATA_WIDTH+COEFF_WIDTH:0] stage2_sums [0:31];
    logic stage2_valid, stage2_last, stage2_load_coeff;
    
    // Stage 3: Sum tree level 2 (32→16 sums)
    logic signed [DATA_WIDTH+COEFF_WIDTH+2:0] stage3_sums [0:15];
    logic stage3_valid, stage3_last, stage3_load_coeff;
    
    // Stage 4: Final sum (16→1) and output
    logic signed [DATA_WIDTH+COEFF_WIDTH+7:0] stage4_sum;
    logic stage4_valid, stage4_last, stage4_load_coeff;

    // Pipeline ready signals
    wire pipe_stall = m_axis_tvalid && !m_axis_tready;
    wire stage4_ready = !pipe_stall;
    wire stage3_ready = stage4_ready;
    wire stage2_ready = stage3_ready;
    wire stage1_ready = stage2_ready;

    // ========================================================================
    // FSM State Register
    // ========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // ========================================================================
    // FSM Combinational Logic
    // ========================================================================
    always_comb begin
        next_state = current_state;
        s_axis_tready = 1'b0;
        coeff_shift_en = 1'b0;
        data_shift_en = 1'b0;

        case (current_state)
            IDLE: begin
                s_axis_tready = (stream_load_coeff_en) ? stage1_ready : 1'b1;

                if (s_axis_fire) begin
                    if (stream_load_coeff_en) begin
                        next_state = COEFF_LOAD;
                        coeff_shift_en = 1'b1;
                    end else begin
                        next_state = DATA_FILL;
                        data_shift_en = 1'b1;
                    end
                end
            end

            COEFF_LOAD: begin
                s_axis_tready = stage1_ready;
                coeff_shift_en = s_axis_fire;

                if (s_axis_fire && s_axis_tlast)
                    next_state = IDLE;
            end

            DATA_FILL: begin
                s_axis_tready = 1'b1;
                data_shift_en = s_axis_fire;

                if (s_axis_fire && sample_count >= TAPS - 1)
                    next_state = DATA_PROC;
            end

            DATA_PROC: begin
                s_axis_tready = stage1_ready;
                data_shift_en = s_axis_fire;

                if (m_axis_fire && m_axis_tlast)
                    next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // ========================================================================
    // Shift Registers
    // ========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            for (int i = 0; i < TAPS; i++) begin
                data_shreg[i] <= '0;
                coeff_shreg[i] <= '0;
            end
            sample_count <= '0;
        end else begin
            // Coefficient shift register
            if (coeff_shift_en) begin
                coeff_shreg[0] <= s_axis_tdata[COEFF_WIDTH-1:0];
                for (int i = 1; i < TAPS; i++)
                    coeff_shreg[i] <= coeff_shreg[i-1];
            end

            // Data shift register
            if (data_shift_en) begin
                data_shreg[0] <= s_axis_tdata[DATA_WIDTH-1:0];
                for (int i = 1; i < TAPS; i++)
                    data_shreg[i] <= data_shreg[i-1];
                if (sample_count < TAPS)
                    sample_count <= sample_count + 1;
            end

            // Reset sample count
            if (m_axis_fire && m_axis_tlast && !stream_load_coeff_en)
                sample_count <= '0;
        end
    end

    // ========================================================================
    // Stage 0: Input Control
    // ========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            stage0_valid <= 1'b0;
            stage0_last <= 1'b0;
            stage0_load_coeff <= 1'b0;
        end else if (stage1_ready) begin
            if (s_axis_fire || current_state == IDLE) begin
                stage0_valid <= (stream_load_coeff_en || next_state == DATA_PROC) ? s_axis_fire : 1'b0;
                stage0_last <= (current_state == IDLE) ? 1'b0 : s_axis_tlast;
            end else begin
                stage0_valid <= 1'b0;
                stage0_last <= 1'b0;
            end
            stage0_load_coeff <= stream_load_coeff_en;
        end
    end

    // ========================================================================
    // Pipeline Stage 1: Multiply (All 64 in parallel)
    // ========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            for (int i = 0; i < TAPS; i++)
                stage1_products[i] <= '0;
            stage1_valid <= 1'b0;
            stage1_last <= 1'b0;
            stage1_load_coeff <= 1'b0;
        end else if (stage2_ready) begin
            for (int i = 0; i < TAPS; i++)
                stage1_products[i] <= data_shreg[i] * coeff_shreg[i];
            
            stage1_valid <= stage0_valid;
            stage1_last <= stage0_last;
            stage1_load_coeff <= stage0_load_coeff;
        end
    end

    // ========================================================================
    // Pipeline Stage 2: Sum Tree Level 1 (64→32, only 2 adds deep)
    // ========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            for (int i = 0; i < 32; i++)
                stage2_sums[i] <= '0;
            stage2_valid <= 1'b0;
            stage2_last <= 1'b0;
            stage2_load_coeff <= 1'b0;
        end else if (stage3_ready) begin
            for (int i = 0; i < 32; i++)
                stage2_sums[i] <= stage1_products[2*i] + stage1_products[2*i + 1];
            
            stage2_valid <= stage1_valid;
            stage2_last <= stage1_last;
            stage2_load_coeff <= stage1_load_coeff;
        end
    end

    // ========================================================================
    // Pipeline Stage 3: Sum Tree Level 2 (32→16, only 2 adds deep)
    // ========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            for (int i = 0; i < 16; i++)
                stage3_sums[i] <= '0;
            stage3_valid <= 1'b0;
            stage3_last <= 1'b0;
            stage3_load_coeff <= 1'b0;
        end else if (stage4_ready) begin
            for (int i = 0; i < 16; i++)
                stage3_sums[i] <= stage2_sums[2*i] + stage2_sums[2*i + 1];
            
            stage3_valid <= stage2_valid;
            stage3_last <= stage2_last;
            stage3_load_coeff <= stage2_load_coeff;
        end
    end

    // ========================================================================
    // Pipeline Stage 4: Final Sum (16→1, only 4 adds deep) + Output
    // ========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            stage4_sum <= '0;
            stage4_valid <= 1'b0;
            stage4_last <= 1'b0;
            stage4_load_coeff <= 1'b0;
            m_axis_tdata  <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end else if (!pipe_stall) begin
            // Sum 16 values with binary tree (4 adds deep)
            stage4_sum = '0;
            for (int i = 0; i < 16; i++)
                stage4_sum = stage4_sum + stage3_sums[i];
            
            stage4_valid <= stage3_valid;
            stage4_last <= stage3_last;
            stage4_load_coeff <= stage3_load_coeff;
            
            // Output
            if (stage3_load_coeff)
                m_axis_tdata <= {{16'd0}, coeff_shreg[TAPS-1]};
            else
                m_axis_tdata <= {{16{stage4_sum[30]}}, stage4_sum[30:15]};

            m_axis_tvalid <= stage3_valid;
            m_axis_tlast  <= stage3_last;
        end
    end

endmodule