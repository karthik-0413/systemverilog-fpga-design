// apb_timer.sv
// APB timer peripheral with counter, limit, and split control/status registers.
//
// TEACHING NOTES FOR STUDENTS:
// =============================
// This timer is intentionally simple so you can focus on the core concepts:
// - The timer is controlled via software writes and polling (no interrupts).
// - Two separate transactions: CONTROL (write-only) and STATUS (read-only).
// - Counter auto-resets after reaching the limit; software must check STATUS
//   to detect completion and can then re-enable the timer.
// - The control bits (Reset / Enable) are cleared in the subsequent cycle 
//   after reseting the regeisters / starting the timer
//
// UNDERSTANDING THE STATE MACHINE:
// - IDLE state: running=0, done=0. Timer is off.
// - RUNNING state: running=1, done=0. Counter increments every clock.
// - DONE state: running=0, done=1. Counter stopped; awaiting software reset.
//
// REGISTER MAP (byte offsets from peripheral base):
// ===================================================
// Address  | Name    | Type      | Bits | Description
// ----------+---------+-----------+------+----------------------------------------
// 0x00     | reserved| ---       | ---  | Do not use.
// 0x04     | counter | read/write| 31:0 | Current counter value. Software can
//          |         |           |      | preload this before enabling timer.
// 0x08     | limit   | read/write| 31:0 | Limit value. When counter reaches
//          |         |           |      | this, timer stops and sets done=1.
// 0x0C     | control | write-only| 31:0 | Command register:
//          |         |           |      |   bit[0]=1: Reset (clear counter,
//          |         |           |      |             status, and control regs)
//          |         |           |      |   bit[1]=1: Enable (start counting)
// 0x10     | status  | read-only | 31:0 | Status register:
//          |         |           |      |   bit[0]: running (1=counting, 0=stopped)
//          |         |           |      |   bit[1]: done (1=limit reached, 0=not)"

`timescale 1ns/1ps

module apb_timer(
    input  logic        clk,
    input  logic        reset,

    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr,

    output logic [31:0] timer_count,
    output logic        timer_running,
    output logic        timer_done
);

    logic [31:0] counter_reg;
    logic [31:0] limit_reg;
    logic [31:0] control_write_reg;
    logic [31:0] status_reg;
    logic [31:0] next_count;

    logic [2:0]  reg_sel;
    logic        write_hit;

    //------------------------------------------------------------------------
    // APB ADDRESS DECODING
    //------------------------------------------------------------------------
    // Extract the word offset (byte address / 4) from the three lower bits:
    //   paddr[4:2] gives us values 0-7, selecting between the registers.
    // This mapping lets you trace address bits 0x04, 0x08, 0x0C, 0x10
    // directly to reg_sel values 0b001, 0b010, 0b011, 0b100.
    assign reg_sel = paddr[4:2];

    // A write occurs when:
    //   - psel = 1 (slave selected)
    //   - penable = 1 (APB access phase—not setup phase)
    //   - pwrite = 1 (this is a write, not a read)
    // In this peripheral, pready is always 1 (no wait states) as execution
    // of timer does not wait on any external signal.
    assign write_hit = psel && penable && pwrite;

    //------------------------------------------------------------------------
    // OUTPUT ASSIGNMENTS
    //------------------------------------------------------------------------
    // Expose the timer state to the top-level module (for debugging/test).
    assign timer_count = counter_reg;
    assign timer_running = status_reg[0];
    assign timer_done = status_reg[1];

    // APB interface signals (required for compliance).
    assign pready = 1'b1;  // No wait states; always ready.
    assign pslverr = 1'b0; // No error responses in this lab.

    // Coutner increment logic
    always_comb begin
        next_count = counter_reg + 32'd1;
    end

    //------------------------------------------------------------------------
    // SEQUENTIAL LOGIC: Timer State and Register Updates
    //------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!reset) begin
            // On reset, clear all registers and return the timer to IDLE.
            counter_reg        <= 32'h0000_0000;
            limit_reg          <= 32'h0000_0000;
            control_write_reg  <= 32'h0000_0000;  
            status_reg         <= 32'h0000_0000;  // running=0, done=0
        end else begin
            //------------------------------------------------------------
            // STEP 1: Handle APB writes (register updates from CPU)
            //------------------------------------------------------------
            if (write_hit) begin
                case (reg_sel)
                    3'b001: counter_reg <= pwdata;         // @0x04: preload counter
                    3'b010: limit_reg <= pwdata;           // @0x08: set limit
                    3'b011: control_write_reg <= pwdata;   // @0x0C: latch command
                    default: begin
                        // Reserved or status register (no write effect).
                    end
                endcase
            end

            //------------------------------------------------------------
            // STEP 2: Process control commands and update status
            //------------------------------------------------------------
            // The control register acts as a single-cycle strobe: software
            // writes a command (Reset / Enable), and we execute it 
            // immediately, then clear the register in the next cycle.
            //
            // command bits from control_write_reg:
            //   - bit[0] = RESET command (clear all registers to defaults)
            //   - bit[1] = ENABLE command (start counting)
            //
            // current state of timer is indicarted in the status_reg:
            //   - bit[0] = running (1 = timer is counting, 0 = stopped)
            //   - bit[1] = done (1 = limit reached, 0 = not reached)
            //
            // Implement the following timer logic:
            //
            // RESET has the highest priority
            // ENABLE command:
            //    - start the timer & write to status reg accordingly
            //    - Clear enable bit (consume the command)
            // When timer is running
            //    - Check if counter has reached the limit
            //      if YES stop the timer, set done=1, and clear counter for next round
            //
            // TIMER LOGIC IMPLEMENTATION:
            // TODO: 
            if (control_write_reg[0] == 1'b1) begin
                counter_reg        <= 32'h0000_0000;
                limit_reg          <= pwdata;
                control_write_reg  <= 32'h0000_0000;  
                status_reg         <= 32'h0000_0000;
            end else if (control_write_reg[1] == 1'b1) begin    // Enable bit set
                status_reg[0] <= 1'b1;  // Running
                control_write_reg[1] <= 1'b0;   // Clear enable bit
            end else if (status_reg[0] == 1'b1) begin   // Running
                if (next_count == limit_reg) begin
                    status_reg[1] <= 1'b1;  // Done
                    status_reg[0] <= 1'b0;  // Not Running
                end
                counter_reg <= next_count;  // Increment counter
            end
        end
    end

    //------------------------------------------------------------------------
    // COMBINATORIAL READ LOGIC: APB Readback Multiplexer
    //------------------------------------------------------------------------
    always_comb begin
        // APB readback is selected by the same register offset used for writes.
        // This case statement must match the write addresses in the sequential
        // block so that reads and writes use the same addressing scheme.
        case (reg_sel)
            3'b000: prdata = 32'h0000_0000;           // @0x00: reserved                    // Byte to Word Addressing (*2) for all addys
            3'b001: prdata = counter_reg;             // @0x04: counter read
            3'b010: prdata = limit_reg;               // @0x08: limit read
            3'b011: prdata = control_write_reg;       // @0x0C: control read (for debug)
            3'b100: prdata = status_reg;              // @0x10: status read
            default: prdata = 32'h0000_0000;
        endcase
    end

endmodule