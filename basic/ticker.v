// Simple periodic pulse and square wave generator

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

module ticker
#(
  parameter CLK_FREQ = 25000000, // Frequency of clk
  parameter FREQ = 1, // Desired pulse frequency
  parameter WIDTH = 20 // Width enough for (CLK_FREQ / FREQ) - 1
) (
  input clk,
  input reset_l,
  output reg square,
  output reg tick
  );

localparam COUNTS = (CLK_FREQ / FREQ);

reg [WIDTH-1:0] tick_count;

always @(posedge clk)
  if (!reset_l)
    begin
      tick_count <= 0;
      tick <= 0;
      square <= 0;
    end
  else
    begin
      tick <= 0;
      tick_count <= tick_count + 1'd1;
      if (tick_count == COUNTS - 1)
        begin
          tick_count <= 0;
          tick <= 1;
          square <= 1;
        end
      else if (tick_count == (COUNTS / 2) - 1)
        begin
          square <= 0;
        end
    end

endmodule
