// WS2811 RGB LED ring interface
// ADDR + 0: set RAM address
// ADDR + 1: write to RAM and increment address
// ADDR + 2: transfer RAM to LED ring

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

module ws2811
  (
  input reset_l,
  input clk,

  input [15:0] bus_addr,
  input [7:0] bus_wr_data,
  input bus_we,
  output bus_ack,

  output reg pwm_out
  );

parameter ADDR = 0;

// Color RAM

reg [5:0] color_rd_addr;
wire [7:0] color_rd_data;

reg [7:0] color_wr_data;
reg [5:0] color_wr_addr;
reg color_we;

ram_blk_dp #(.DATAWIDTH(8), .ADDRWIDTH(6)) color_ram
  (
  .clk (clk),
  .wr_data (color_wr_data),
  .wr_addr (color_wr_addr),
  .we (color_we),
  .rd_addr (color_rd_addr),
  .rd_data (color_rd_data)
  );

// LED color registers

reg go;

wire bus_ack = bus_we && (bus_addr == (ADDR + 0) || bus_addr == (ADDR + 1) || bus_addr == (ADDR + 2));

always @(posedge clk or negedge reset_l)
  if (!reset_l)
    begin
      go <= 0;
      color_wr_data <= 0;
      color_wr_addr <= 0;
      color_we <= 0;
    end
  else
    begin
      color_we <= 0;
      if (bus_we)
        begin
          if (bus_addr == ADDR + 0)
            begin
              color_wr_addr <= bus_wr_data - 1'd1;
            end
          else if (bus_addr == ADDR + 1)
            begin
              color_we <= 1;
              color_wr_data <= bus_wr_data;
              color_wr_addr <= color_wr_addr + 1'd1;
            end
          else if (bus_addr == ADDR + 2)
            begin
              go <= !go;
            end
        end
    end

// WS2811 PWM driver

reg [7:0] shift_reg;
reg [3:0] bit_cnt;
reg [5:0] cnt;
reg [5:0] low_time;
reg [2:0] state;
reg go_2;
reg go_1;
reg go_old;
reg [5:0] rpt;

parameter
  IDLE = 0,
  RUN = 1,
  HIGH = 2,
  LOW = 3;

always @(posedge clk or negedge reset_l)
  if (!reset_l)
    begin
      state <= IDLE;
      go_2 <= 0;
      go_1 <= 0;
      go_old <= 0;
      bit_cnt <= 0;
      cnt <= 0;
      low_time <= 0;
      shift_reg <= 0;
      pwm_out <= 0;
      rpt <= 0;
      color_rd_addr <= 0;
    end
  else
    begin
      go_2 <= go;
      go_1 <= go_2;
      go_old <= go_1;
      if (cnt)
        cnt <= cnt - 1'd1;
      case (state)
        IDLE:
          if (go_1 != go_old)
            begin
              state <= RUN;
              shift_reg <= color_rd_data;
              color_rd_addr <= color_rd_addr + 1'd1;
              bit_cnt <= 8;
              rpt <= 36;
            end
          else
            begin
              color_rd_addr <= 0;
            end

        RUN:
          if (bit_cnt == 0)
            begin
              if (rpt)
                begin
                  rpt <= rpt - 1'd1;
                  shift_reg <= color_rd_data;
                  color_rd_addr <= color_rd_addr + 1'd1;
                  bit_cnt <= 8;
                end
              else
                state <= IDLE;
            end
          else
            begin
              shift_reg <= { shift_reg[6:0], 1'd0 };
              bit_cnt <= bit_cnt - 1'd1;
              if (shift_reg[7])
                begin
                  cnt <= 37;
                  low_time <= 32;
                end
              else
                begin
                  cnt <= 18;
                  low_time <= 42;
                end
              state <= HIGH;
              pwm_out <= 1;
            end

        HIGH:
          if (cnt == 0)
            begin
              cnt <= low_time;
              state <= LOW;
              pwm_out <= 0;
            end

        LOW:
          if (cnt == 0)
            begin
              state <= RUN;
            end
      endcase
    end

endmodule
