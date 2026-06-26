// Author: Karl Peterson


// Copyright 2026 NK Labs, LLC

// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to permit
// persons to whom the Software is furnished to do so, subject to the
// following conditions:

// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT
// OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
// THE USE OR OTHER DEALINGS IN THE SOFTWARE.


// Tx shift register and state machine 

module uart_tx #(parameter CLKS_PER_BIT = 977) ( //112.5 MMHz
  output [7:0] debug_state, 

  input clk, 
  input reset_l,

  output reg tx, 

  output reg busy, 

  input [7:0] data_in, 
  input tx_en
  );

//parameter CLKS_PER_BIT = 1085; //125MHz sample clk, 115200 baud
///parameter CLKS_PER_BIT = 286; //33MHz sample clk, 115200 baud

reg [7:0] shift_reg; 
reg [11:0] clk_cnt = 0; 
reg [3:0] bit_cnt = 0; 

enum {
  IDLE = 0,
  START_BIT = 1,
  SHIFT_OUT = 2, 
  COUNT = 3, 
  STOP_BIT = 4
} state;

assign debug_state = state[7:0]; 


always @(posedge clk)
  if (!reset_l) begin
    state <= IDLE; 
    bit_cnt <= 0; 
    clk_cnt <= 0; 
    tx <= 1;
    busy <= 0; 
  end 
  else begin 
    case (state) 
      IDLE: begin 
        bit_cnt <= 0; 
        clk_cnt <= 0; 
        tx <= 1; 
        busy <= 0;
        if (tx_en) begin 
          shift_reg <= data_in; 
          busy <= 1; 
          state <= START_BIT; 
        end 
      end 

      START_BIT: begin 
        tx <= 0; 
        clk_cnt <= clk_cnt + 1; 
        if (clk_cnt == CLKS_PER_BIT - 1) begin 
          clk_cnt <= 0;
          state <= SHIFT_OUT; 
        end
      end 

      SHIFT_OUT: begin
        tx <= shift_reg[0]; 
        shift_reg <= {1'b0, shift_reg[7:1]};
        clk_cnt <= clk_cnt + 1; 
        bit_cnt <= bit_cnt + 1; 
        state <= COUNT; 
      end

      COUNT: begin 
        clk_cnt <= clk_cnt + 1; 
        if (clk_cnt == CLKS_PER_BIT - 1) begin 
          clk_cnt <= 0; 
          if (bit_cnt == 8) begin
            bit_cnt <= 0;
            state <= STOP_BIT; 
          end
          else
            state <= SHIFT_OUT; 
        end 
      end 

      STOP_BIT: begin
        tx <= 1; 
        clk_cnt <= clk_cnt + 1; 
        if (clk_cnt == (CLKS_PER_BIT<<1) - 1) begin //adding a slight delay to separte messages a little more 
          clk_cnt <= 0;
          //busy <= 0; 
          state <= IDLE; 
        end
      end 

    endcase
  end 

endmodule 