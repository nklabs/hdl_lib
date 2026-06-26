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


// Rx shift register and state machine 

module uart_rx #(parameter CLKS_PER_BIT = 977) ( //112.5 MMHz
  output reg [7:0] debug_state,

  input clk,
  input reset_l, 

  input rx,
  
  output reg [7:0] data_out,
  output reg rx_pulse,

  output reg msg_fifo_we, 
  output reg [7:0] msg_fifo_data,
  output reg new_msg_pulse = 0
  
  );


//parameter CLKS_PER_BIT = 1085; //125MHz sample clk, 115200 baud
//parameter CLKS_PER_BIT = 286; //33MHz sample clk, 115200 baud

reg [11:0] clk_cnt = 0; 
reg [3:0] bit_cnt = 0; 


reg [7:0] shift_reg = 0; 

enum {
  IDLE = 0,
  OFFSET = 1,
  COUNT = 2,
  SHIFT_IN = 3,
  DELAY = 4,
  SEND_BYTE = 5,
  NEW_LINE = 6,
  SPACE = 7, 
  BACKSPACE = 8,
  PASS_MSG = 9
} state;

assign debug_state = state[7:0]; 


// memory for storing/builidng messages in, supports backspace 
(* syn_ramstyle = "rw_check" *) reg [7:0] msg_lifo [0:127]; 
reg [7:0] msg_byte_cnt = 0;
reg msg_rdy = 0; 

reg [7:0] msg_len = 0; 


reg has_cmd = 0; // if user hits enter and there is no message 



always @(posedge clk)
  if (!reset_l) begin
    state <= IDLE; 
    bit_cnt <= 0; 
    clk_cnt <= 0; 
    rx_pulse <= 0; 
    msg_byte_cnt <= 0; //hmmm
    msg_fifo_we <= 0;
    has_cmd <= 0; 
  end 
  else begin 

    case (state) 
      IDLE: begin 
        bit_cnt <= 0; 
        clk_cnt <= 0; 
        rx_pulse <= 0; 
        new_msg_pulse <= 0; 
        msg_fifo_we <= 0;
        has_cmd <= 0; 

        if (!rx) begin //start bit 
          state <= OFFSET;
        end  
      end 

      OFFSET: begin 
        // Adding half-bit delay so that when we sample, we're sampling furthest from the edge 
        clk_cnt <= clk_cnt + 1; 
        if (clk_cnt == CLKS_PER_BIT >> 1) begin 
          clk_cnt <= 0; 
          state <= COUNT;
        end 
      end 

      COUNT: begin
        clk_cnt <= clk_cnt + 1; 
        if (clk_cnt == CLKS_PER_BIT - 2) begin 
          clk_cnt <= 0;
          state <= SHIFT_IN; 
        end 
      end 

      SHIFT_IN: begin 
        shift_reg <= {rx, shift_reg[7:1]};
        bit_cnt <= bit_cnt + 1;
        if (bit_cnt == 7) begin
          clk_cnt <= 0; 
          state <= DELAY; 
        end
        else
          state <= COUNT; 
      end

      DELAY: begin 
        // wait for the stop bit 
        clk_cnt <= clk_cnt + 1; 
        if (clk_cnt == CLKS_PER_BIT << 1) begin //2 bit-widths because why not lol 
          clk_cnt <= 0; 
          state <= SEND_BYTE;  
        end      
      end 

      SEND_BYTE: begin
        if (msg_byte_cnt < 128) begin // don't overflow please!
          if (shift_reg == 8'h7f) begin
            data_out <= 8'h08; // BS first
            msg_lifo[msg_byte_cnt-1] <= 0;
            msg_byte_cnt <= msg_byte_cnt - 1;
          end
          else begin 
            data_out <= shift_reg; 
            msg_lifo[msg_byte_cnt] <= shift_reg;
            msg_byte_cnt <= msg_byte_cnt + 1;
          end
        end 

        rx_pulse <= 1; 

        if (shift_reg == 8'h0d) //CR then LF
          state <= NEW_LINE; 
        else if (shift_reg == 8'h7f)
          state <= SPACE; 
        else
          state <= IDLE; 
          shift_reg <= 0; 
      end

      NEW_LINE: begin 
        data_out <= 8'h0a; //new line LF
        msg_len <= msg_byte_cnt; 
        if (msg_byte_cnt > 1) 
          has_cmd <= 1;
        state <= PASS_MSG; 
      end 

      SPACE: begin 
        data_out <= 8'h20; // SPACE
        state <= BACKSPACE; 
      end 

      BACKSPACE: begin 
        data_out <= 8'h08; // BACKSPACE
        state <= IDLE; 
      end 

      PASS_MSG: begin 
        rx_pulse <= 0; 
        shift_reg <= 0;
        msg_fifo_we <= 1; 
        msg_byte_cnt <= msg_byte_cnt - 1; 
        if (msg_byte_cnt) begin
          msg_fifo_data <= msg_lifo[msg_len - msg_byte_cnt]; 
          msg_lifo[msg_len - msg_byte_cnt] <= 0; 
        end
        else begin 
          msg_fifo_we <= 0; 
          msg_byte_cnt <= 0; 
          new_msg_pulse <= 1;
          // if (has_cmd) begin 
          //   new_msg_pulse <= 1;
          // end  
          state <= IDLE;
        end 
      end


    endcase
  end 


endmodule