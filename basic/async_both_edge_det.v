// Generate a pulse for an async rising or falling edge detected on input

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

module async_both_edge_det
#(
  parameter DATAWIDTH=1
) (
  input reset_l,
  input clk,
  input [DATAWIDTH-1:0] i,
  output wire [DATAWIDTH-1:0] o
  );

wire [DATAWIDTH-1:0] synced;

simple_sync #(.DATAWIDTH(DATAWIDTH)) syncer
  (
  .reset_l (reset_l),
  .clk (clk),
  .i (i),
  .o (synced)
  );

reg [DATAWIDTH-1:0] old;

always @(posedge clk)
  if(!reset_l)
    old <= 0;
  else
    old <= synced;

assign o = old ^ synced;

endmodule
