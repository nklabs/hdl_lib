package bus;

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

localparam BUS_DATA_WIDTH = 32;
localparam BUS_ADDR_WIDTH = 32;

typedef struct packed
{
  logic reset_l;
  logic clk;
  logic [BUS_DATA_WIDTH-1:0] wr_data;
  logic [BUS_ADDR_WIDTH-1:0] wr_addr; // Byte address
  logic [BUS_ADDR_WIDTH-1:0] rd_addr; // Byte address
  logic [3:0] be; // Byte enables
  logic we; // Asserted for one cycle
  logic re; // Asserted for one cycle
} bus_in_s;

typedef struct packed
{
  logic irq;
  logic wr_ack; // Asserted for one cycle
  logic rd_ack; // Asserted for one cycle
  logic [BUS_DATA_WIDTH-1:0] rd_data;
} bus_out_s;

endpackage
