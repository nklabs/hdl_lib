// Copyright 2020 NK Labs, LLC

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

module an_tx
  (
  input clk,
  input reset_l,
  input pcs_rst,

  input [7:0] framed_tx_data,
  input framed_tx_k,

  input [15:0] tx_config, // Config word to send
  input tx_mode, // 0 = send idles, 1 = send config word
  input an_done,

  output reg [7:0] txdata,
  output reg tx_k,
  output reg tx_disp_correct
  );

// AN Transmitter

parameter
  TX_RESET = 0,
  TX_IDLE = 1,
  TX_C1 = 2,
  TX_C1LOW = 3,
  TX_C1HIGH = 4,
  TX_C2K = 5,
  TX_C2 = 6,
  TX_C2LOW = 7,
  TX_C2HIGH = 8,
  DATA = 9;


reg [3:0] tx_state;

reg [7:0] idle_cnt;
reg an_done;
reg tx_mode; // 0 = send idles, 1 = send config word
reg [15:0] tx_config; // Config word to send

always @(posedge clk)
  if (!reset_l || pcs_rst)
    begin
      txdata <= 8'hbc;
      tx_k <= 1;
      tx_disp_correct <= 0;
      idle_cnt <= 0;
      tx_state <= TX_RESET;
    end
  else
    begin
      case (tx_state)
        TX_RESET:
          begin
            txdata <= 8'hbc;
            tx_k <= 1;
            if (an_done)
              begin
                txdata <= framed_tx_data;
                tx_k <= framed_tx_k;
              end
            else if (tx_mode == 0)
              tx_state <= TX_IDLE;
            else if (tx_mode == 1)
              tx_state <= TX_C1;
          end
        TX_IDLE:
          begin
            tx_state <= TX_RESET;
            txdata <= 8'h50;
            tx_k <= 1;
            if (idle_cnt == 8'hff)
              begin
                idle_cnt <= 0;
                tx_disp_correct <= 1;
              end
            else
              begin
                idle_cnt <= idle_cnt + 1'd1;
                tx_disp_correct <= 0;
              end
          end
        TX_C1:
          begin
            txdata <= 8'hB5;
            tx_k <= 0;
            tx_state <= TX_C1LOW;
          end
        TX_C1LOW:
          begin
            txdata <= tx_config[7:0];
            tx_k <= 0;
            tx_state <= TX_C1HIGH;
          end
        TX_C1HIGH:
          begin
            txdata <= tx_config[15:8];
            tx_k <= 0;
            tx_state <= TX_C2K;
          end
        TX_C2K:
          begin
            txdata <= 8'hbc;
            tx_k <= 1;
            tx_state <= TX_C2;
          end
        TX_C2:
          begin
            txdata <= 8'h42;
            tx_k <= 0;
            tx_state <= TX_C2LOW;
          end
        TX_C2LOW:
          begin
            txdata <= tx_config[7:0];
            tx_k <= 0;
            tx_state <= TX_C2HIGH;
          end
        TX_C2HIGH:
          begin
            txdata <= tx_config[15:8];
            tx_k <= 0;
            tx_state <= TX_RESET;
          end
      endcase
    end

endmodule
