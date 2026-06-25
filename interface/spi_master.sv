// SPI bus bridge

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

// This maps a part of the bus address space to a SPI bus.

module spi_master
import bus::*;
#(
  parameter ADDR = 16'h0400,
  parameter SPEED = 32 // Half spi clock is bus_clk divided by SPEED

) (
  input bus_in_s bus_in,
  output bus_out_s bus_out,

  output reg spi_clk,
  input spi_miso,
  output reg spi_mosi,
  output reg spi_cs_l
  );

localparam LOGSIZE = 10; // Log2 of memory size: must be less than or equal to 8*ADDR_BYTES
localparam SPI_ADDR_BYTES = 2; // Number of address bytes in SPI transaction
localparam SPI_DATA_BYTES = 4; // Number of data bytes in SPI transaction

localparam SIZE = (1 << LOGSIZE);
localparam ADDRMASK = (SIZE - 1);

reg spi_miso_reg;

reg reg_rd_ack;
reg reg_wr_ack;

reg [BUS_DATA_WIDTH-1:0] out;

assign bus_out.rd_data = reg_rd_ack ? out : { BUS_DATA_WIDTH { 1'd0 } };
assign bus_out.rd_ack = reg_rd_ack;
assign bus_out.wr_ack = reg_wr_ack;
assign bus_out.irq = 0;

reg [2:0] state;
reg [5:0] count; // Bit ocunter
reg [BUS_DATA_WIDTH-1:0] spi_shift_reg; // Shift register
reg [7:0] delay; // Delay: loaded with (SPEED - 1) or (SPEED*2 - 1)
reg data_phase; // Set if we're in the data phase of the transfer
reg write_trans; // Set if this is a write transaction

localparam
  IDLE = 0,
  LOW = 1,
  HIGH = 2,
  DONE = 3,
  HOLD = 4;

always @(posedge bus_in.clk)
  if (!bus_in.reset_l)
    begin
      out <= 0;
      spi_cs_l <= 1;
      spi_mosi <= 0;
      spi_clk <= 1;
      spi_miso_reg <= 0;
      state <= IDLE;
      count <= 0;
      spi_shift_reg <= 0;
      delay <= 0;
      write_trans <= 0;
      data_phase <= 0;
      reg_wr_ack <= 0;
      reg_rd_ack <= 0;
    end
  else
    begin
      reg_wr_ack <= 0;
      reg_rd_ack <= 0;
      if (delay)
        delay <= delay - 1'd1;
      spi_miso_reg <= spi_miso;
      case (state)
        IDLE: // Wait for start of transaction
          if (bus_in.we && (bus_in.wr_addr & ~ADDRMASK) == ADDR)
            begin
              spi_cs_l <= 0;
              spi_shift_reg <= { { ((8 * SPI_ADDR_BYTES) - LOGSIZE)  { 1'd0 } }, bus_in.wr_addr[LOGSIZE-1:2], 1'd1, 1'd0, { (BUS_DATA_WIDTH - (8 * SPI_ADDR_BYTES)) { 1'd0 } } };
              count <= 7;
              count <= ((8 * SPI_ADDR_BYTES) - 1);
              delay <= (SPEED - 1);
              state <= LOW;
              data_phase <= 0; // Address phase
              write_trans <= 1; // Write
            end
          else if (bus_in.re && (bus_in.rd_addr & ~ADDRMASK) == ADDR)
            begin
              spi_cs_l <= 0;
              spi_shift_reg <= { { ((8 * SPI_ADDR_BYTES) - LOGSIZE)  { 1'd0 } }, bus_in.rd_addr[LOGSIZE-1:2], 1'd0, 1'd0, { (BUS_DATA_WIDTH - (8 * SPI_ADDR_BYTES)) { 1'd0 } } };
              count <= ((8 * SPI_ADDR_BYTES) - 1);
              delay <= (SPEED - 1);
              state <= LOW;
              data_phase <= 0; // Address phase
              write_trans <= 0; // Read
            end

        LOW: // Launch falling edge
          if (!delay)
            begin
              spi_clk <= 0;
              // Send data to slave on this edge
              if (!data_phase || write_trans)
                begin
                  spi_mosi <= spi_shift_reg[BUS_DATA_WIDTH - 1];
                  spi_shift_reg <= { spi_shift_reg[BUS_DATA_WIDTH - 2:0], 1'd0 };
                end
              delay <= (SPEED - 1);
              state <= HIGH;
            end

        HIGH: // Launch rising edge
          if (!delay)
            begin
              spi_clk <= 1;
              delay <= (SPEED - 1);
              count <= count - 1'd1;
              // Capture data from slave this edge
              if (data_phase && !write_trans)
                spi_shift_reg <= { spi_shift_reg[BUS_DATA_WIDTH - 2:0], spi_miso_reg };
              if (count == 0)
                if (write_trans)
                  if (data_phase)
                    state <= DONE;
                  else
                    begin
                      data_phase <= 1; // Write data phase
                      spi_shift_reg <= { bus_in.wr_data[(8 * SPI_DATA_BYTES) - 1:0], { (BUS_DATA_WIDTH - (8 * SPI_DATA_BYTES)) { 1'd0 } } };
                      state <= LOW;
                      count <= ((8 * SPI_DATA_BYTES) - 1);
                    end
                else
                  if (data_phase)
                    state <= DONE;
                  else
                    begin
                      data_phase <= 1; // Read data phase
                      state <= LOW;
                      count <= ((8 * SPI_DATA_BYTES) - 1);
                    end
              else
                state <= LOW;
            end

        DONE: // Release chip select
          if (!delay)
            begin
              state <= HOLD;
              spi_cs_l <= 1;
              delay <= ((SPEED * 2) - 1);
            end

        HOLD: // Delay before we allow next transaction
          if (!delay)
            begin
              state <= IDLE;
              if (write_trans)
                reg_wr_ack <= 1;
              else
                begin
                  reg_rd_ack <= 1;
                  out <= spi_shift_reg;
                end
            end
      endcase
    end

endmodule
