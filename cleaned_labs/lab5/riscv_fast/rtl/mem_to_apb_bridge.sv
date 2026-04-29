// mem_to_apb_bridge.sv
// Bridge from the RV32I memory interface to a simple APB master.
//
// Teaching focus:
// - The CPU presents a request on the memory side.
// - This bridge turns that request into a two-phase APB transaction.
// - The request is first captured in SETUP, then completed in ACCESS.
// - The bridge keeps the CPU stalled by asserting busy until APB returns ready.

`timescale 1ns/1ps

module mem_to_apb_bridge(
    // ---- System signals ----
    input  logic        clk,      // Clock signal, shared by everything
    input  logic        reset,    // Reset signal, shared by everything

    // ---- CPU side (signals between CPU and bridge) ----
    input  logic        req_valid,   // CPU says "I have a request for you"
    input  logic [31:0] req_addr,    // CPU says "this is the address I want to access"
    input  logic [31:0] req_wdata,   // CPU says "this is the data I want to write"
    input  logic [3:0]  req_wmask,   // CPU says "these are the bytes I want to write" (0000 = read)

    output logic        busy,        // Bridge tells CPU "wait, I'm handling a request"
    output logic        resp_valid,  // Bridge tells CPU "here's your response, I'm done"
    output logic [31:0] resp_rdata,  // Bridge gives CPU the data it read from peripheral

    // ---- Peripheral side (APB signals between bridge and peripherals) ----
    output logic [31:0] paddr,       // Bridge tells peripheral "this is the address"
    output logic [31:0] pwdata,      // Bridge tells peripheral "this is the write data"
    output logic        pwrite,      // Bridge tells peripheral "this is a write" (1=write, 0=read)
    output logic        psel,        // Bridge tells peripheral "you are selected"
    output logic        penable,     // Bridge tells peripheral "we're in access phase"
    input  logic [31:0] prdata,      // Peripheral gives bridge the read data
    input  logic        pready,      // Peripheral tells bridge "I'm done, you can finish"
    input  logic        pslverr      // Peripheral tells bridge "something went wrong" (unused here)
);

    // Simple APB controller state machine.
    // IDLE_SETUP: wait for a new request and present the setup phase.
    // ACCESS: hold the request stable until the APB slave asserts ready.
    typedef enum logic {IDLE_SETUP = 1'b0, ACCESS = 1'b1} state_t;

    state_t       state;
    // Latched request fields.
    // These hold the CPU request stable across the APB ACCESS phase.
    logic [31:0]  addr_q;
    logic [31:0]  wdata_q;
    logic [3:0]   wmask_q;
    logic         pwrite_q;

    // Derived control signals.
    // accept_request gates new CPU requests so we only capture one when idle.
    // request_is_write follows the latched mask so the bridge knows whether
    // to return read data when ACCESS completes.
    logic         accept_request;
    logic         request_is_write;

    assign accept_request   = req_valid && (state == IDLE_SETUP);
    assign request_is_write = (wmask_q != 4'b0000);

    // Sequential FSM and response handling.
    // byte-lane checking, or additional response conditions.
    // NOTE: Many of the outptus are registered to hold them stable during the APB ACCESS phase, 
    // but the APB signals themselves are driven combinationally from the latched request fields.
    always_ff @(posedge clk) begin
        if (!reset) begin
            // Reset returns the bridge to a known idle state.
            state      <= IDLE_SETUP;
            addr_q     <= 32'h0000_0000;
            wdata_q    <= 32'h0000_0000;
            wmask_q    <= 4'b0000;
            pwrite_q   <= 1'b0;
            busy       <= 1'b0;
            resp_valid <= 1'b0;
            resp_rdata <= 32'h0000_0000;
        end else begin
            // resp_valid is a one-cycle pulse when an APB access completes.
            resp_valid <= 1'b0; // default to 0; set to 1 when we have a valid response to return.
            // TODO: Implement the FSM transitions and response handling logic.
            case (state)
                IDLE_SETUP: begin
                    // In the idle/setup state the bridge is ready to accept one
                    // CPU request and capture it to use during ACCESS and wait states.
                    if (accept_request) begin
                        addr_q <= req_addr;                 // Captures the CPU addy it wants to access
                        wdata_q <= req_wdata;               // Captures the CPU data it wants to write
                        wmask_q <= req_wmask;               // Captures the CPU bytes it wants to write
                        pwrite_q <= req_wmask != 4'b0000;   // If there is no mask, then it is a read
                        busy <= 1'b1;                       // Stall CPU

                        state <= ACCESS;
                    end
                end

                ACCESS: begin
                    // Keep the APB signals stable until the slave is ready.
                        // Reads copy the APB return data into resp_rdata.
                        // Writes just complete with a valid response pulse.
                    if (pready) begin
                        resp_rdata <= prdata;
                        resp_valid <= 1'b1;
                        busy <= 1'b0;

                        state <= IDLE_SETUP; 
                    end
                end

                default: begin
                    // Any unexpected state falls back to idle.
                    state      <= IDLE_SETUP;
                    busy       <= 1'b0;
                    resp_valid <= 1'b0;
                end
            endcase
        end
    end

    // Combinational APB drive logic.
    // The bridge presents SETUP (psel=1, penable=0) while idle and ACCESS
    // (psel=1, penable=1) while the transaction is in flight.
    // TODO: 
    always_comb begin
        if (state == ACCESS) begin
            paddr   = addr_q;
            pwdata  = wdata_q;
            pwrite  = pwrite_q;
            psel    = 1'b1;
            penable = 1'b1;
        end else begin
            // In SETUP, the request is still driven from the CPU side.
            paddr   = req_addr;
            pwdata  = req_wdata;
            pwrite  = req_wmask != 4'b0000;
            psel    = 1'b1;
            penable = 1'b0;
        end
    end

endmodule
