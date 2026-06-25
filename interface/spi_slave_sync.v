// SPI slave interface

//   - Generates internal chip bus
// This version uses the SPI clock for the bus clock

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

module spi_slave_sync
 #(
  parameter DATAWIDTH = 32,
  parameter ADDRWIDTH = 16 // Min. is 3 bits, low two bits always 0
) (
  input reset_l,

  input spi_reset, // spi chip select
  input spi_clk,
  input spi_din,
  output reg spi_dout,

  output bus_clk,
  output reg [ADDRWIDTH-1:0] bus_addr,
  output reg [DATAWIDTH-1:0] bus_wr_data,
  input [DATAWIDTH-1:0] bus_rd_data,
  output reg bus_we,
  output reg bus_re
  );

reg [DATAWIDTH-1:0] spi_shift_reg;

reg [DATAWIDTH-1:0] spi_out_reg;

// Use inverted clock
wire bus_clk = ~spi_clk;

parameter
  IDLE = 0,
  READ = 1,
  WRITE = 2,
  READ_REST = 3,
  WRITE_REST = 4;

reg [2:0] state;

always @(negedge spi_clk)
  if (!reset_l)
    spi_dout <= 0;
  else
    spi_dout <= spi_out_reg[DATAWIDTH-1];

always @(posedge spi_clk or posedge spi_reset)
  if (!reset_l || spi_reset)
    begin
      spi_shift_reg <= 1;
      spi_out_reg <= 0;
      state <= IDLE;
      bus_addr <= 0;
      bus_wr_data <= 0;
      bus_re <= 0;
      bus_we <= 0;
    end
  else
    begin
      bus_re <= 0;
      bus_we <= 0;
      spi_shift_reg <= { spi_shift_reg[DATAWIDTH-2:0], spi_din };
      spi_out_reg <= { spi_out_reg[DATAWIDTH-2:0], 1'd0 };
      case (state)
        IDLE:
          if (spi_shift_reg[ADDRWIDTH-2]) // Start bit...  addr bit 1 is on spi_din at this time
            begin
              bus_addr <= { spi_shift_reg[ADDRWIDTH-3:0], 2'd0 };
              if (spi_din)
                begin // Write
                  state <= WRITE;
                end
              else
                begin // Read
                  bus_re <= 1;
                  state <= READ;
                end
            end

        WRITE: // Addr bit 0 is on spi_din at this time
          begin
            spi_shift_reg <= 1;
            state <= WRITE_REST;
          end

        READ: // Addr bit 0 is on spi_din at this time
          begin
            spi_shift_reg <= 1;
            spi_out_reg <= bus_rd_data;
            state <= READ_REST;
          end

        WRITE_REST:
          if (spi_shift_reg[DATAWIDTH-1])
            begin // Data bit 0 is on spi_din at this time
              bus_we <= 1;
              bus_wr_data <= { spi_shift_reg[DATAWIDTH-2:0], spi_din };
              spi_shift_reg <= 1'd1; // Clear it so we don't think a data bit is a start bit
              state <= IDLE;
            end

        READ_REST:
          begin
            if (spi_shift_reg[DATAWIDTH-1])
              begin
                spi_shift_reg <= 1'd1;
                state <= IDLE;
              end
          end

      endcase
    end

endmodule
