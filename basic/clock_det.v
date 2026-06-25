// Running clock detector
// 'stopped' goes high if var_clk stops running

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

module clock_det
#(
  // Number of cycles of const_clk we wait before declaring clock stopped
  // Must be at least 3 to account for synchronizer delay
  parameter DELAY = 4
) (
  input const_clk,
  input const_clk_reset_l,
  input var_clk,
  output reg clk_ok
  );

reg rtn = 0;
reg rtn_1;
reg rtn_2;
reg fwd;

reg [2:0] cnt;

always @(posedge const_clk)
  if (!const_clk_reset_l)
    begin
      rtn_1 <= 0;
      rtn_2 <= 0;
      cnt <= DELAY;
      clk_ok <= 0;
      fwd <= 0;
    end
  else
    begin
      // Synchronize
      rtn_1 <= rtn;
      rtn_2 <= rtn_1;
      // Invert
      fwd <= !rtn_2;

      // Reset stop detector when we get back inverted value
      if (fwd == rtn_2)
        begin
          cnt <= 0;
          clk_ok <= 1;
        end
      else if (cnt != DELAY)
        begin
          cnt <= cnt + 1'd1;
        end
      else
        begin
          clk_ok <= 0;
        end
    end

always @(posedge var_clk)
  rtn <= fwd;

endmodule
