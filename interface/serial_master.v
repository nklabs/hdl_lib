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

module serial_master
  (
  input clk,
  input reset_l,

  output pwm_out_a,
  output pwm_out_b,
  output pwm_out_c,
  input pwm_in_a,
  input pwm_in_b,
  input pwm_in_c,

  input [15:0] bus_addr,
  input [7:0] bus_wr_data,
  output reg [7:0] bus_rd_data,
  input bus_we,
  input bus_re,
  output reg bus_ack,

  output [2:0] sensor_status
  );

parameter ADDR = 0;

wire pwm_out;
wire pwm_out_a = pwm_out;
wire pwm_out_b = pwm_out;
wire pwm_out_c = pwm_out;

wire pwm_in = (pwm_in_a | pwm_in_b | pwm_in_c);

// Serializer

wire [8:0] tx_fifo_rd_data;
wire tx_fifo_re;
wire tx_fifo_ne;

serial_tx serial_tx
  (
  .clk (clk),
  .reset_l (reset_l),

  .pwm_out (pwm_out),
  .tx_out (),

  .rd_data (tx_fifo_rd_data),
  .ne (tx_fifo_ne),
  .re (tx_fifo_re)
  );

// Transmit FIFO

reg [8:0] tx_fifo_wr_data;
reg tx_fifo_we;

fifo_sync_late #(.DATAWIDTH(9), .ADDRWIDTH(4)) tx_fifo
  (
  .clk (clk),
  .reset_l (reset_l),

  .wr_data (tx_fifo_wr_data),
  .we (tx_fifo_we),

  .rd_data (tx_fifo_rd_data),
  .re (tx_fifo_re),
  .ne (tx_fifo_ne)
  );

// De-serializer

wire [7:0] rx_data;
wire rx_valid;
wire rx_idle;

serial_rx serial_rx
  (
  .clk (clk),
  .reset_l (reset_l),

  .rx_in (pwm_in),
  .data (rx_data),
  .valid (rx_valid),
  .idle (rx_idle)
  );

// Watch received data: ignore stuff not for me
// Also strip address

reg [7:0] watch_data;
reg watch_valid;

reg [1:0] watch_state;

parameter
  WATCH_IDLE = 0,
  WATCH_DATA = 1,
  WATCH_SKIP = 2;

always @(posedge clk or negedge reset_l)
  if (!reset_l)
    begin
      watch_data <= 0;
      watch_valid <= 0;
      watch_state <= WATCH_IDLE;
    end
  else
    begin
      watch_valid <= 0;
      watch_data <= rx_data;

      case (watch_state)
        WATCH_IDLE:
          if (rx_valid)
            if (rx_data == 8'h00) // For master data
              watch_state <= WATCH_DATA;
            else
              watch_state <= WATCH_SKIP;

        WATCH_DATA:
          if (rx_idle)
            watch_state <= WATCH_IDLE;
          else if (rx_valid)
            watch_valid <= 1;

        WATCH_SKIP:
          if (rx_idle)
            watch_state <= WATCH_IDLE;
      endcase
    end

reg [3:0] state;
reg [11:0] count;
reg [3:0] byte_count;

parameter
  IDLE = 0,
  WRITE_ADDR = 1,
  WRITE_DATA = 2,
  READ_ADDR = 3,
  READ_WAIT = 4,
  BURST_READ_ADDR = 5,
  BURST_READ_LENGTH = 6,
  BURST_READ_WAIT = 7,
  BURST_READ_NEXT = 8,
  OLD_BURST_RD = 9;

// Read burst buffer

reg [7:0] burst_wr_data;
reg [3:0] burst_wr_addr;
reg burst_we;

wire [7:0] burst_rd_data;

ram_blk_dp #(.DATAWIDTH(8), .ADDRWIDTH(4)) burst_ram
  (
  .clk (clk),
  .wr_data (burst_wr_data),
  .wr_addr (burst_wr_addr),
  .we (burst_we),
  .rd_data (burst_rd_data),
  .rd_addr (bus_addr[3:0])
  );

reg [2:0] sensor_status;

always @(posedge clk or negedge reset_l)
  if (!reset_l)
    begin
      state <= IDLE;
      count <= 0;
      tx_fifo_wr_data <= 0;
      tx_fifo_we <= 0;
      bus_ack <= 0;
      bus_rd_data <= 0;
      burst_wr_addr <= 0;
      burst_wr_data <= 0;
      burst_we <= 0;
      sensor_status <= 0;
    end
  else
    begin
      burst_we <= 0;
      tx_fifo_we <= 0;
      bus_rd_data <= 0;
      bus_ack <= 0;
      if (count)
        count <= count - 1'd1;

      if (pwm_in_a)
        sensor_status[0] <= 1;

      if (pwm_in_b)
        sensor_status[1] <= 1;

      if (pwm_in_c)
        sensor_status[2] <= 1;

      case (state)
        IDLE:
          if (bus_addr >= 16'h0020)
            if ((bus_addr[4:0] >= 5'd1) && (bus_addr[4:0] < 5'd12) && bus_re) // Read from previous burst
              begin
                state <= OLD_BURST_RD;
              end
            else if (bus_addr[4:0] == 5'd0 && bus_re) // Initiate a burst read from a sensor
              begin
                // Station address
                tx_fifo_wr_data <= { 1'd0, bus_addr[12:5] };
                tx_fifo_we <= 1;
                state <= BURST_READ_ADDR;
                sensor_status <= 0;
              end
            else if (bus_re || bus_we) // Byte access
              begin
                // Station address
                tx_fifo_wr_data <= { 1'd0, bus_addr[12:5] };
                tx_fifo_we <= 1;
                sensor_status <= 0;
                if (bus_we)
                  state <= WRITE_ADDR;
                else
                  state <= READ_ADDR;
              end

        BURST_READ_ADDR:
          begin
            // Starting register number
            tx_fifo_wr_data <= { 1'd0, 3'b100, bus_addr[4:0] };
            tx_fifo_we <= 1;
            state <= BURST_READ_LENGTH;
          end

        BURST_READ_LENGTH:
          begin
            // Burst length
            burst_wr_addr <= 0;
            tx_fifo_wr_data <= { 1'd1, 8'd12 };
            tx_fifo_we <= 1;
            state <= BURST_READ_WAIT;
            count <= 4000;
          end

        BURST_READ_WAIT:
          if (!count)
            begin
              // Timeout
              state <= IDLE;
              bus_ack <= 1;
            end
          else if (watch_valid)
            begin
              state <= BURST_READ_NEXT;
              burst_wr_data <= watch_data;
              burst_we <= 1;
              count <= 4000;
            end

        BURST_READ_NEXT:
          begin
            burst_wr_addr <= burst_wr_addr + 1'd1;
            if (burst_wr_addr == 11)
              state <= OLD_BURST_RD;
            else
              state <= BURST_READ_WAIT;
          end

        OLD_BURST_RD:
          begin
            state <= IDLE;
            bus_ack <= 1;
            bus_rd_data <= burst_rd_data;
            // Clear old data as we read it
            burst_wr_addr <= bus_addr[3:0];
            burst_wr_data <= 0;
            burst_we <= 1;
          end

        WRITE_ADDR:
          begin
            tx_fifo_wr_data <= { 1'd0, 3'b000, bus_addr[4:0] };
            tx_fifo_we <= 1;
            state <= WRITE_DATA;
          end

        WRITE_DATA:
          begin
            tx_fifo_wr_data <= { 1'd1, bus_wr_data };
            tx_fifo_we <= 1;
            bus_ack <= 1;
            state <= IDLE;
          end

        READ_ADDR:
          begin
            tx_fifo_wr_data <= { 1'd1, 3'b100, bus_addr[4:0] };
            tx_fifo_we <= 1;
            state <= READ_WAIT;
            count <= 4000;
          end

        READ_WAIT:
          if (!count)
            begin
              // Timeout
              state <= IDLE;
              bus_ack <= 1;
            end
          else if (watch_valid)
            begin
              state <= IDLE;
              bus_rd_data <= watch_data;
              bus_ack <= 1;
            end
      endcase
    end

endmodule
