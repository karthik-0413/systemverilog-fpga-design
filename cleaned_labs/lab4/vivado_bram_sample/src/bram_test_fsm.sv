// bram_test_fsm.sv
// FSM to test BRAM by reading bottom 4 locations and storing sum at top
// Uses RISC-V-style interface like existing bram.sv

`timescale 1ns/1ps

module bram_test_fsm(
    input  logic        clk,
    input  logic        reset,    // Active-high reset (from GPIO ch1). Deassert to start.
    
    // BRAM Port B interface
    output logic [31:0] addr,
    output logic [31:0] wdata,
    output logic [3:0]  wmask,
    output logic        we,
    input  logic [31:0] rdata,
    
    // Status output
    output logic        done
);

    // FSM states
    typedef enum logic [3:0] {
        IDLE,
        READ_ADDR0,
        READ_ADDR1,
        READ_ADDR2,
        READ_ADDR3,
        CALC_SUM,
        WRITE_RESULT,
        DONE
    } state_t;
    
    state_t state, next_state;
    
    // Registers
    logic [31:0] read_data [0:3];
    
    // State register with async reset
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            for (int i = 0; i < 4; i++) begin
                read_data[i] <= 32'b0;
            end
        end else begin
            state <= next_state;
            case (state)
                READ_ADDR1: read_data[0] <= rdata;  // data[addr=0] ready 1 cycle after presented
                READ_ADDR2: read_data[1] <= rdata;  // data[addr=4] ready
                READ_ADDR3: read_data[2] <= rdata;  // data[addr=8] ready
                CALC_SUM:   read_data[3] <= rdata;  // data[addr=12] ready
                default: ;
            endcase
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE:         next_state = READ_ADDR0;  // auto-start when reset deasserted
            READ_ADDR0:   next_state = READ_ADDR1;
            READ_ADDR1:   next_state = READ_ADDR2;
            READ_ADDR2:   next_state = READ_ADDR3;
            READ_ADDR3:   next_state = CALC_SUM;
            CALC_SUM:     next_state = WRITE_RESULT;
            WRITE_RESULT: next_state = DONE;
            DONE:         next_state = DONE;  // stay here until reset
        endcase
    end
    
    // Output logic
    always_comb begin
        // Default values
        addr  = 32'b0;
        wdata = 32'b0;
        wmask = 4'b0000;
        we    = 1'b0;
        done  = 1'b0;
        
        case (state)
            IDLE: begin end
            
            READ_ADDR0: addr = 32'd0;    // Byte address 0  (word 0)
            READ_ADDR1: addr = 32'd4;    // Byte address 4  (word 1)
            READ_ADDR2: addr = 32'd8;    // Byte address 8  (word 2)
            READ_ADDR3: addr = 32'd12;   // Byte address 12 (word 3)
            CALC_SUM:   begin end        // wait for last read data
            
            WRITE_RESULT: begin
                addr  = 32'd4092;  // Byte address 4092 (word 1023, top)
                wdata = read_data[0] + read_data[1] + read_data[2] + read_data[3];
                wmask = 4'b1111;
                we    = 1'b1;
            end
            
            DONE: done = 1'b1;  // stay here until reset
        endcase
    end
    
endmodule
