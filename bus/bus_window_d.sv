// Addressing window with one pipeline delay

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

// Create a new sub-bus which is focused on a particular address range.
// Address bits not needed for the range are set to constants which reduces
// the size of address decoders on the sub-bus.

// Registers on the sub-bus should use the full register address, not an
// offset relative to the window's address.

module bus_window_d
import bus::*;
#(
  parameter BUS_ADDR = 0, // Base address, must be a multiple of (1 << ADDRWIDTH)
  parameter ADDRWIDTH = 8 // Size (1<<ADDRWIDTH) bytes
) (
  input bus_in_s bus_in,
  output bus_out_s bus_out,

  output bus_in_s sub_bus_in,
  input bus_out_s sub_bus_out
  );

// Outputs

bus_out_s sub_bus_out_d;

assign bus_out = sub_bus_out_d;

always @(posedge bus_in.clk)
  if(!bus_in.reset_l)
    sub_bus_out_d <= 0;
  else
    sub_bus_out_d <= sub_bus_out;

// Inputs

assign sub_bus_in.reset_l = bus_in.reset_l;
assign sub_bus_in.clk = bus_in.clk;

// Decode if upper bits match
wire wr_decode = (bus_in.wr_addr & ~((1 << ADDRWIDTH) - 1)) == (BUS_ADDR & ~((1 << ADDRWIDTH) - 1));
wire rd_decode = (bus_in.rd_addr & ~((1 << ADDRWIDTH) - 1)) == (BUS_ADDR & ~((1 << ADDRWIDTH) - 1));

reg bus_rd_req_d;
reg bus_wr_req_d;
reg [3:0] bus_be_d;
reg [BUS_DATA_WIDTH-1:0] bus_wr_data_d;
reg [ADDRWIDTH-1:0] bus_wr_addr_d;
reg [ADDRWIDTH-1:0] bus_rd_addr_d;

wire [BUS_ADDR_WIDTH-1:0] upper = BUS_ADDR;

always @(posedge bus_in.clk)
  if(!bus_in.reset_l)
    begin
      bus_rd_req_d <= 0;
      bus_wr_req_d <= 0;
      bus_wr_data_d <= 0;
      bus_wr_addr_d <= 0;
      bus_rd_addr_d <= 0;
      bus_be_d <= 0;
    end
  else
    begin
      bus_rd_req_d <= bus_in.re && rd_decode;
      bus_wr_req_d <= bus_in.we && wr_decode;
      bus_wr_data_d <= bus_in.wr_data;
      bus_wr_addr_d <= bus_in.wr_addr[ADDRWIDTH-1:0];
      bus_rd_addr_d <= bus_in.rd_addr[ADDRWIDTH-1:0];
      bus_be_d <= bus_in.be;
    end

assign sub_bus_in.re = bus_rd_req_d;
assign sub_bus_in.we = bus_wr_req_d;
assign sub_bus_in.wr_data = bus_wr_data_d;
assign sub_bus_in.wr_addr = { upper[BUS_ADDR_WIDTH-1:ADDRWIDTH], bus_wr_addr_d[ADDRWIDTH-1:2], 2'd0 };
assign sub_bus_in.rd_addr = { upper[BUS_ADDR_WIDTH-1:ADDRWIDTH], bus_rd_addr_d[ADDRWIDTH-1:2], 2'd0 };
assign sub_bus_in.be = bus_be_d;

endmodule
