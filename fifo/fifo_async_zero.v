// Zero-width Async FIFO (basically a counter)

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

module fifo_async_zero
#(
  parameter ADDRWIDTH = 5,
  parameter SLOPBITS = 3 // Log2(SLOP)
) (
  input wr_clk,
  input wr_reset_l,
  input we,
  output full,
  output ovf,

  input rd_clk,
  input rd_reset_l,
  input re,
  output reg ne,
  output unf
  );

// Convert binary to gray code

function [ADDRWIDTH-1:0] bin_to_gray;
input [ADDRWIDTH-1:0] i;
integer x;
  begin
    bin_to_gray[ADDRWIDTH-1] = i[ADDRWIDTH-1];
    for (x = 0; x != ADDRWIDTH - 1; x = x + 1)
      bin_to_gray[x] = i[x]^i[x+1];
  end
endfunction

// Convert gray code to binary

function [ADDRWIDTH-1:0] gray_to_bin;
input [ADDRWIDTH-1:0] i;
integer x;
  begin
    gray_to_bin = i;
    for (x = 1; x != ADDRWIDTH; x = x + 1)
      gray_to_bin = gray_to_bin ^ (i >> x);
  end
endfunction

// Write address
reg [ADDRWIDTH-1:0] wr_addr;

// Write address in gray code
wire [ADDRWIDTH-1:0] wr_addr_gray = bin_to_gray(wr_addr);

// Synchronizer to get write address in read domain
reg [ADDRWIDTH-1:0] wr_addr_gray_1;
reg [ADDRWIDTH-1:0] wr_addr_gray_2;

// Convert gray back to binary
wire [ADDRWIDTH-1:0] wr_addr_ungray = gray_to_bin(wr_addr_gray_2);

// Read address
reg [ADDRWIDTH-1:0] rd_addr, ns_rd_addr;

// Read address, gray coded
wire [ADDRWIDTH-1:0] rd_addr_gray = bin_to_gray(rd_addr);

// Synchonizer to get read address in write domain
reg [ADDRWIDTH-1:0] rd_addr_gray_1;
reg [ADDRWIDTH-1:0] rd_addr_gray_2;

// Convert back to binary
wire [ADDRWIDTH-1:0] rd_addr_ungray = gray_to_bin(rd_addr_gray_2);

// Write clock

reg ovf;

always @(posedge wr_clk)
  if (!wr_reset_l)
    begin
      wr_addr <= 0;
      rd_addr_gray_1 <= 0;
      rd_addr_gray_2 <= 0;
      ovf <= 0;
    end
  else
    begin
      if (we)
        wr_addr <= wr_addr + 1'd1;

      rd_addr_gray_1 <= rd_addr_gray;
      rd_addr_gray_2 <= rd_addr_gray_1;
      if (we && (wr_addr + 1'd1 == rd_addr_ungray))
        begin
          ovf <= 1;
          $display("%m FIFO overflow error");
          $finish;
        end
    end

// Full flag

wire full = (wr_addr[ADDRWIDTH-1:SLOPBITS] + 1'd1) == rd_addr_ungray[ADDRWIDTH-1:SLOPBITS];

// Read clock

reg unf;
reg ne_d;

always @(posedge rd_clk)
  if (!rd_reset_l)
    begin
      rd_addr <= 0;
      wr_addr_gray_1 <= 0;
      wr_addr_gray_2 <= 0;
      unf <= 0;
      ne_d <= 0;
    end
  else
    begin
      rd_addr <= ns_rd_addr;

      wr_addr_gray_1 <= wr_addr_gray;
      wr_addr_gray_2 <= wr_addr_gray_1;
      ne_d <= ne;
      if (re && !ne_d)
        begin
          unf <= 1;
          $display("%m FIFO underflow error");
          $finish;
        end
    end

always @*
  begin
    ns_rd_addr = rd_addr;
    if (re)
      ns_rd_addr = ns_rd_addr + 1'd1;
    ne = (ns_rd_addr != wr_addr_ungray); // Not empty flag
  end

endmodule
