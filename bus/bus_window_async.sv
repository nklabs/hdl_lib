// Addressing window which crosses clock domains

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

module bus_window_async
import bus::*;
#(
  parameter BUS_ADDR = 0,	// Base address
  parameter ADDRWIDTH = 8	// Size (1<<ADDRWIDTH) bytes
) (
  input sub_clk,		// Clock for sub bus
  input sub_reset_l,		// Reset for sub bus
  
  input bus_in_s bus_in,
  output bus_out_s bus_out,

  output bus_in_s sub_bus_in,
  input bus_out_s sub_bus_out
  );

// Return

wire sub_irq;
wire sub_wr_ack;
wire sub_rd_ack;
reg [BUS_DATA_WIDTH-1:0] sub_rd_data;

assign bus_out.irq = sub_irq;
assign bus_out.wr_ack = sub_wr_ack;
assign bus_out.rd_ack = sub_rd_ack;
assign bus_out.rd_data = sub_rd_ack ? sub_rd_data : { BUS_DATA_WIDTH { 1'd0 } };

// Forward

// Decode if upper bits match
wire wr_decode = (bus_in.wr_addr & ~((1 << ADDRWIDTH) - 1)) == (BUS_ADDR & ~((1 << ADDRWIDTH) - 1));
wire rd_decode = (bus_in.rd_addr & ~((1 << ADDRWIDTH) - 1)) == (BUS_ADDR & ~((1 << ADDRWIDTH) - 1));

wire sub_rd_req;
wire sub_wr_req;
reg [BUS_DATA_WIDTH-1:0] sub_wr_data;
reg [BUS_ADDR_WIDTH-1:0] sub_wr_addr;
reg [BUS_ADDR_WIDTH-1:0] sub_rd_addr;
reg [3:0] sub_be;

assign sub_bus_in.reset_l = sub_reset_l;
assign sub_bus_in.clk = sub_clk;
assign sub_bus_in.re = sub_rd_req;
assign sub_bus_in.we = sub_wr_req;
assign sub_bus_in.wr_data = sub_wr_data;
assign sub_bus_in.wr_addr = sub_wr_addr;
assign sub_bus_in.rd_addr = sub_rd_addr;
assign sub_bus_in.be = sub_be;

// Main side of bus

wire rd_req = bus_in.re;
wire wr_req = bus_in.we;

// Drive slave bus

always @(posedge bus_in.clk)
  if (!bus_in.reset_l)
    begin
      sub_wr_data <= 0;
      sub_wr_addr <= 0;
      sub_rd_addr <= 0;
      sub_be <= 0;
    end
  else if (rd_req || wr_req)
    begin
      sub_wr_addr <= (BUS_ADDR & ~((32'd1 << ADDRWIDTH) - 1)) | (bus_in.wr_addr & ((1 << ADDRWIDTH) - 1));
      sub_rd_addr <= (BUS_ADDR & ~((32'd1 << ADDRWIDTH) - 1)) | (bus_in.rd_addr & ((1 << ADDRWIDTH) - 1));
      sub_be <= bus_in.be;
      sub_wr_data <= bus_in.wr_data;
    end

// Master bus to slave bus

pulse_sync rd_pulse_sync
  (
  .i_clk (bus_in.clk),
  .i_reset_l (bus_in.reset_l),
  .i (rd_req && rd_decode),

  .o_clk (sub_clk),
  .o_reset_l (sub_reset_l),
  .o (sub_rd_req)
  );

pulse_sync wr_pulse_sync
  (
  .i_clk (bus_in.clk),
  .i_reset_l (bus_in.reset_l),
  .i (wr_req && wr_decode),

  .o_clk (sub_clk),
  .o_reset_l (sub_reset_l),
  .o (sub_wr_req)
  );

// slave bus back to master bus

pulse_sync wr_ack_pulse_sync
  (
  .i_clk (sub_clk),
  .i_reset_l (sub_reset_l),
  .i (sub_bus_out.wr_ack),

  .o_clk (bus_in.clk),
  .o_reset_l (bus_in.reset_l),
  .o (sub_wr_ack)
  );

pulse_sync rd_ack_pulse_sync
  (
  .i_clk (sub_clk),
  .i_reset_l (sub_reset_l),
  .i (sub_bus_out.rd_ack),

  .o_clk (bus_in.clk),
  .o_reset_l (bus_in.reset_l),
  .o (sub_rd_ack)
  );

simple_sync sub_irq_syncer
  (
  .reset_l (bus_in.reset_l),
  .clk (bus_in.clk),
  .i (sub_bus_out.irq),
  .o (sub_irq)
  );

// Register return data

reg [31:0] sub_rd_data_hold;

always @(posedge sub_clk)
  if(!sub_reset_l)
    sub_rd_data_hold <= 0;
  else if(sub_bus_out.rd_ack)
    sub_rd_data_hold <= sub_bus_out.rd_data;

always @(posedge bus_in.clk)
  if (!bus_in.reset_l)
    sub_rd_data <= 0;
  else
    sub_rd_data <= sub_rd_data_hold;

endmodule
