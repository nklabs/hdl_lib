// Parameterized two-clock inferred RAM

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

module ram_dc
#(
  parameter
    DATAWIDTH = 18,
    ADDRWIDTH = 5
) (
  input [ADDRWIDTH-1:0] wr_addr,
  input [ADDRWIDTH-1:0] rd_addr,
  input wr_clk,
  input rd_clk,
  input [DATAWIDTH-1:0] wr_data,
  input we,
  output reg [DATAWIDTH-1:0] rd_data
  );

(* ram_style = "block" *) reg [DATAWIDTH-1:0] ram[((1 << ADDRWIDTH) - 1) : 0];

always @(posedge wr_clk)
  if (we)
    ram[wr_addr] <= wr_data;

always @(posedge rd_clk)
  rd_data <= ram[rd_addr];

endmodule
