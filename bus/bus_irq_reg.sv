// Interrupt register
// Write 1 to invert

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

module bus_irq_reg
import bus::*;
#(
  parameter ADDR=0,
  parameter OFFSET=0,
  parameter DATAWIDTH=32,
  parameter REG=0,
  parameter LEVEL=0
) (
  // Internal bus
  input bus_in_s bus_in,
  output bus_out_s bus_out,

  input [DATAWIDTH-1:0] enable,	// Interrupt enable bits
  input [DATAWIDTH-1:0] trig, // Interrupt requests
  output logic irq // Interrupt request
  );

// Bus driver

logic [DATAWIDTH-1:0] cur;
logic [DATAWIDTH-1:0] out;

wire rd_ack = ((bus_in.rd_addr == ADDR) && bus_in.re);
wire wr_ack = ((bus_in.wr_addr == ADDR) && bus_in.we);
reg reg_rd_ack;
reg reg_wr_ack;

assign bus_out.rd_data = reg_rd_ack ? (out << OFFSET) : { BUS_DATA_WIDTH { 1'd0 } };
assign bus_out.rd_ack = reg_rd_ack;
assign bus_out.wr_ack = reg_wr_ack;
assign bus_out.irq = irq;

logic [3:0] count;

always @(posedge bus_in.clk)
  if(!bus_in.reset_l)
    begin
      cur <= 0;
      out <= 0;
      count <= 0;
      irq <= 0;
      reg_rd_ack <= 0;
      reg_wr_ack <= 0;
    end
  else
    begin
      reg_rd_ack <= rd_ack;
      reg_wr_ack <= wr_ack;

      if (count)
        count <= count - 1;

      irq <= (count == 0) && |(out & enable);

      out <= (cur & ~LEVEL) | (trig & LEVEL);

      if (cur & ~out)
        count <= 15; // New interrupt detected

      if(wr_ack)
        cur <= (cur ^ (bus_in.wr_data >> OFFSET)) | trig;
      else
        cur <= cur | trig;
    end

endmodule
