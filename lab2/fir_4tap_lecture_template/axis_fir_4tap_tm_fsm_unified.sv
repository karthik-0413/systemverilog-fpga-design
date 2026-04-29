`timescale 1ns / 1ps

/**
 * Parallel 4-Tap FIR Filter with Unified FSM Control
 *
 * Implements: y[n] = h0·x[n] + h1·x[n-1] + h2·x[n-2] + h3·x[n-3]
 *
 * Key Design Principles:
 * - Fully parallel datapath
 * - 4-tap shift register for data (no direct compute on incoming data)
 * - 2-cycle latency from input acceptance to output valid
 * - Unified FSM: each state handles next state, outputs, and pipeline control
 * - Stall-based pipeline: all stages freeze when downstream is not ready
 */

module axis_fir_4tap_tm_fsm_unified (
    input  logic        aclk,
    input  logic        aresetn,
    input  logic        stream_load_coeff_en,

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

    localparam int TAPS = 4;
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
    // Internal Registers and Signals
    // ========================================================================
    logic signed [DATA_WIDTH-1:0]  data_shreg [0:TAPS-1];
    logic signed [COEFF_WIDTH-1:0] coeff_shreg [0:TAPS-1];
    logic [$clog2(TAPS+1):0]       sample_count;

    logic signed [DATA_WIDTH+COEFF_WIDTH-1:0] products [0:TAPS-1];
    logic signed [DATA_WIDTH+COEFF_WIDTH+3:0] comb_sum;

    // Pipeline control signals: track valid and last through computation stages
    // Current: 2-stage pipeline (v_pipe, l_pipe are single registers)
    // To extend: convert to shift registers [0:N-1] for N-stage pipeline
    // Stall-based design: all stages stall together when pipe_stall is asserted
    logic v_pipe, l_pipe;

    // Shift register enables
    logic coeff_shift_en;
    logic data_shift_en;

    // Handshake signals
    // s_axis_fire: Input transaction accepted this cycle
    // m_axis_fire: Output transaction accepted this cycle
    // pipe_stall: Stall the entire pipeline if downstream is not ready and output is valid
    wire s_axis_fire = s_axis_tvalid && s_axis_tready;
    wire m_axis_fire = m_axis_tvalid && m_axis_tready;
    wire pipe_stall  = m_axis_tvalid && !m_axis_tready;

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
    // Datapath: Combinational Sum
    // ========================================================================
    always_comb begin
        // Compute products in parallel
        for (int i = 0; i < TAPS; i++) begin
            products[i] = data_shreg[i] * coeff_shreg[i];
        end
        // Sum the products
        comb_sum = 0;
        for (int i = 0; i < TAPS; i++) begin
            comb_sum = comb_sum + products[i];
        end
    end

    // ========================================================================
    // Combinational FSM Logic: Next State and Outputs 
    // ========================================================================
    always_comb begin
        // Default values
        next_state = current_state;
        s_axis_tready = 1'b0;
        coeff_shift_en = 1'b0;
        data_shift_en = 1'b0;

        case (current_state)
            IDLE: begin
                // Output control: ready based on mode
                s_axis_tready = (stream_load_coeff_en) ? !pipe_stall : 1'b1;

                // Next state logic and shift enable outputs
                if (s_axis_fire) begin
                    if (stream_load_coeff_en) begin
                        next_state = COEFF_LOAD;
                        coeff_shift_en = 1'b1;  // Shift when entering COEFF_LOAD (1st co-efficient read)
                    end else begin
                        next_state = DATA_FILL;
                        data_shift_en = 1'b1;   // Shift when entering DATA_FILL (1st input token read)
                    end
                end
            end

            COEFF_LOAD: begin
                // Output control: respect backpressure
                s_axis_tready = !pipe_stall;
                coeff_shift_en = s_axis_fire;  // Shift while inptus arrive

                // Next state logic
                if (s_axis_fire && s_axis_tlast)
                    next_state = IDLE;
            end

            DATA_FILL: begin
                // Output control: always ready (no backpressure needed as no outputs are generated)
                s_axis_tready = 1'b1;
                data_shift_en = s_axis_fire;   // Shift when data arrives

                // Next state logic
                if (s_axis_fire && sample_count >= TAPS - 1)
                    next_state = DATA_PROC;
            end

            DATA_PROC: begin
                // Output control: respect backpressure
                s_axis_tready = !pipe_stall;
                data_shift_en = s_axis_fire;   // Shift while data arrives

                // Next state logic
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
                coeff_shreg[TAPS-1] <= s_axis_tdata[COEFF_WIDTH-1:0];
                for (int i = 0; i < TAPS-1; i++)
                    coeff_shreg[i] <= coeff_shreg[i+1];
            end

            // Data shift register
            if (data_shift_en) begin
                data_shreg[0] <= s_axis_tdata[DATA_WIDTH-1:0];
                for (int i = 1; i < TAPS; i++)
                    data_shreg[i] <= data_shreg[i-1];
                // Increment sample count to keep track on when shift register fills up
                if (sample_count < TAPS)
                    sample_count <= sample_count + 1;
            end

            // Reset sample count on completion
            if (m_axis_fire && m_axis_tlast && !stream_load_coeff_en) begin
                sample_count <= '0;
            end
        end
    end

    // ========================================================================
    // Sequential Logic to handel AXI handhsake: Pipeline Handshake Control
    // ========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            // Reset all registered outputs
            m_axis_tdata  <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            v_pipe        <= 1'b0;
            l_pipe        <= 1'b0;
        end else begin
            // Pipeline stage 1: Capture valid/last from input
            if (!pipe_stall) begin
                if (s_axis_fire || current_state == IDLE) begin
                    v_pipe <= (stream_load_coeff_en || next_state == DATA_PROC) ? s_axis_fire : 1'b0;
                    l_pipe <= (current_state == IDLE) ? 1'b0 : s_axis_tlast;
                end else begin
                    v_pipe <= 1'b0;
                    l_pipe <= 1'b0;
                end
            end
            // else: pipe_stall holds v_pipe and l_pipe values

            // Pipeline stage 2: Move data and control to output
            if (!pipe_stall) begin
                // Select data source based on mode
                if (stream_load_coeff_en)
                    m_axis_tdata <= {{16'd0}, coeff_shreg[TAPS-1]};  // Coefficient echo from register (1-cycle delay. same as data)
                else
                    m_axis_tdata <= {{16{comb_sum[15]}}, comb_sum[15:0]};  // FIR output (registered)

                m_axis_tvalid <= v_pipe;
                m_axis_tlast  <= l_pipe;
            end
            // else: pipe_stall holds output register values
        end
    end

endmodule
