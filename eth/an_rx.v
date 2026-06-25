// Autonegotiation receiver

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

module an_rx
  (
  input clk,
  input reset_l,
  input pcs_rst,

  input rx_k,
  input [7:0] rxdata,
  input rx_cv_err,

  output reg rx_valid,
  output reg [15:0] rx_old_config
  );

// AN receiver

parameter
  RX_RESET = 0,
  RX_GOT_COMMA = 1,
  RX_GOT_C12 = 2,
  RX_GOT_LOW = 3
  ;

reg [3:0] rx_state;
reg [7:0] rx_new_config;
reg [1:0] rx_same_count;

always @(posedge clk)
  if (!reset_l || pcs_rst)
    begin
      rx_state <= RX_RESET;
      rx_new_config <= 0;
      rx_old_config <= 0;
      rx_same_count <= 0;
      rx_valid <= 0;
    end
  else
    begin
      rx_valid <= 0;
      case (rx_state)
        RX_RESET:
          begin
            if (rx_k == 1 && rxdata == 8'hBC && !rx_cv_err)
              rx_state <= RX_GOT_COMMA;
          end

        RX_GOT_COMMA:
          begin
            if (rx_k == 1 && rxdata == 8'hBC && !rx_cv_err)
              rx_state <= RX_GOT_COMMA;
            else if (rx_k == 0 && rxdata == 8'hB5 && !rx_cv_err)
              rx_state <= RX_GOT_C12;
            else if (rx_k == 0 && rxdata == 8'h42 && !rx_cv_err)
              rx_state <= RX_GOT_C12;
            else
              rx_state <= RX_RESET;
          end

        RX_GOT_C12:
          begin
            if (rx_k == 1 && rxdata == 8'hBC && !rx_cv_err)
              rx_state <= RX_GOT_COMMA;
            else if (rx_k == 0 && !rx_cv_err)
              begin
                rx_new_config <= rxdata;
                rx_state <= RX_GOT_LOW;
              end
            else
              rx_state <= RX_RESET;
          end

        RX_GOT_LOW:
          begin
            if (rx_k == 1 && rxdata == 8'hBC && !rx_cv_err)
              rx_state <= RX_GOT_COMMA;
            else if (rx_k == 0 && !rx_cv_err)
              begin
                rx_old_config[15:8] <= rxdata;
                rx_old_config[7:0] <= rx_new_config;
                if (rx_old_config == { rxdata, rx_new_config })
                  begin
                    if (rx_same_count == 2)
                      rx_valid <= 1;
                    else
                      rx_same_count <= rx_same_count + 1'd1;
                  end
                else
                  rx_same_count <= 0;
              end
            else
              rx_state <= RX_RESET;
          end
      endcase
    end

endmodule
