// Parameterized true dual-port RAM
// 'true' means it has two write ports

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

module ram_true_dp #(parameter DATAWIDTH = 8, ADDRWIDTH = 9)
  (
  input clk,

  input [DATAWIDTH-1:0] wr_data_1,
  input [ADDRWIDTH-1:0] addr_1,
  input we_1,
  output reg [DATAWIDTH-1:0] rd_data_1,

  input [DATAWIDTH-1:0] wr_data_2,
  input [ADDRWIDTH-1:0] addr_2,
  input we_2,
  output reg [DATAWIDTH-1:0] rd_data_2
  );

reg [DATAWIDTH-1:0] ram[((1 << ADDRWIDTH) - 1) : 0];

always @(posedge clk)
  begin
    if (we_1)
      ram[addr_1] <= wr_data_1;
    if (we_2)
      ram[addr_2] <= wr_data_2;
    rd_data_1 <= ram[addr_1];
    rd_data_2 <= ram[addr_2];
  end

endmodule
