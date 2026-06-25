// Hold PLL in reset for a while after async reset goes high
//   This should not be needed, but there is a bug in CrossLink ES parts...
//   Also PLL reset pulse must be at least 1 ms!

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

module pll_reset
#(
  parameter DELAY = 20'd250000
) (
  input clk,
  input reset_l_in,
  output reg pll_reset_l
  );

reg [19:0] pll_reset_count;
reg pll_rst_2;
reg pll_rst_1;
reg pll_rst;

always @(posedge clk or negedge reset_l_in)
  if (!reset_l_in)
    begin
      pll_reset_l <= 0;
      pll_reset_count <= DELAY;
      pll_rst <= 0;
      pll_rst_1 <= 0;
      pll_rst_2 <= 0;
    end
  else
    begin
      pll_rst_2 <= 1;
      pll_rst_1 <= pll_rst_2;
      pll_rst <= pll_rst_1;
      if (!pll_rst)
        begin
          pll_reset_l <= 0;
          pll_reset_count <= DELAY;
        end
      else
        begin
          if (pll_reset_count)
            pll_reset_count <= pll_reset_count - 1'd1;
          else
            pll_reset_l <= 1;
        end
    end

endmodule
