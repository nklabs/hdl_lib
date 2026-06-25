// Simple bus register

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

module bus_reg
import bus::*;
#(
  parameter DATAWIDTH = 32, // No. bits (1..32)
  parameter OFFSET = 0, // Bit position (0..31)
  parameter IZ = 0, // Initial value
  parameter ADDR = 0, // Address
  parameter REG = 0 // Flag that this is a register
) (
  input bus_in_s bus_in,
  output bus_out_s bus_out,

  output logic [DATAWIDTH-1:0] out,
  output logic wr_pulse
  );

wire rd_ack = ((bus_in.rd_addr == ADDR) && bus_in.re);
wire wr_ack = ((bus_in.wr_addr == ADDR) && bus_in.we);
reg reg_rd_ack;
reg reg_wr_ack;

wire [BUS_DATA_WIDTH-1:0] padded_out = { { BUS_DATA_WIDTH - DATAWIDTH { 1'd0 } }, out };

assign bus_out.rd_data = reg_rd_ack ? padded_out << OFFSET : { BUS_DATA_WIDTH { 1'd0 } };
assign bus_out.rd_ack = reg_rd_ack;
assign bus_out.wr_ack = reg_wr_ack;
assign bus_out.irq = 0;

always @(posedge bus_in.clk)
  if (!bus_in.reset_l)
    begin
      out <= IZ;
      wr_pulse <= 0;
      reg_rd_ack <= 0;
      reg_wr_ack <= 0;
    end
  else
    begin
      wr_pulse <= 0;
      reg_rd_ack <= rd_ack;
      reg_wr_ack <= wr_ack;
      if (wr_ack)
        begin
          out <= bus_in.wr_data[OFFSET+DATAWIDTH-1:OFFSET];
          wr_pulse <= 1;
        end
    end

endmodule
