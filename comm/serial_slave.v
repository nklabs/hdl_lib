// Serial interface which generates a bus

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

// Packet format:
//
// Write:
//   <idle><station-address><register-address><data0><data1>...<dataN><idle>
//
//      <register-address> ranges over 0..7F
//
//      <station-address> may be 0xFF: write to all stations
//
// Read burst request:
//   <idle><station-address><register-address><length><idle>
//
//      <register-address> ranges over 80..FF
//      <length> is 1 - 0x80
//
// Read single byte request:
//   <idle><station-address><register-address><idle>
//
//      <register-address> ranges over 80..FF
//
// Read response:
//   <idle><staton-address><data0><data1>...<dataN><idle>
//
//      <station-address> will be 0.

module serial_slave
  (
  input clk,
  input reset_l,

  // Serial interface
  input serial_in,
  output serial_out,

  // Local bus
  output reg [15:0] addr,
  output reg we,
  output reg re,
  input ack,
  output reg [7:0] data_out,
  input [7:0] data_in,

  // This station's address
  input [7:0] station_addr
  );

// Serial receiver

wire [7:0] rx_data;
wire rx_valid;
wire rx_idle;

serial_rx serial_rx
  (
  .clk (clk),
  .reset_l (reset_l),

  .rx_in (serial_in),

  .data (rx_data),
  .valid (rx_valid),
  .idle (rx_idle)
  );

// Serial transmitter

wire [8:0] tx_fifo_rd_data;
wire tx_fifo_ne;
wire tx_fifo_re;

serial_tx serial_tx
  (
  .clk (clk),
  .reset_l (reset_l),

  .pwm_out (serial_out),
  .tx_out (),

  .rd_data (tx_fifo_rd_data),
  .ne (tx_fifo_ne),
  .re (tx_fifo_re)
  );

// Tx FIFO

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

// Main state machine

parameter
  IDLE = 0,
  ADDR = 1,
  WRITE = 2,
  WRITE_NEXT = 3,
  READ = 4,
  READ_WAIT = 5,
  READ_RETURN = 6,
  READ_GET = 7,
  READ_SEND = 8,
  IGNORE = 9;

reg [3:0] state;

reg [7:0] count; // Burst counter

reg [2:0] timeout; // Timeout

always @(posedge clk or negedge reset_l)
  if (!reset_l)
    begin
      state <= IDLE;

      tx_fifo_we <= 0;
      tx_fifo_wr_data <= 0;

      addr <= 0;
      we <= 0;
      re <= 0;
      data_out <= 0;

      count <= 0;

      timeout <= 0;
    end
  else
    begin
      we <= 0;
      re <= 0;
      tx_fifo_we <= 0;

      if (timeout)
        timeout <= timeout - 1'd1;

      case (state)
        IDLE: // Wait for a frame
          if (rx_valid)
            begin
              if (rx_data[7:0] == station_addr || rx_data[7:0] == 8'hFF)
                begin
                  state <= ADDR;
                end
              else
                begin // Not for us
                  state <= IGNORE;
                end
            end

        ADDR: // Capture register address
          if (rx_idle)
            state <= IDLE;
          else if (rx_valid)
            begin
              addr <= { 8'd0, 1'd0, rx_data[6:0] };
              if (rx_data[7])
                state <= READ;
              else
                state <= WRITE;
            end

        WRITE: // Write data
          if (rx_idle)
            state <= IDLE;
          else if (rx_valid)
            begin
              we <= 1;
              data_out <= rx_data[7:0];
              state <= WRITE_NEXT;
            end

        WRITE_NEXT: // Increment register address for write
          begin
            addr[6:0] <= addr[6:0] + 1'd1;
            state <= WRITE;
          end

        READ: // Capture read length
          if (rx_idle)
            begin
               count <= 1;
              state <= READ_RETURN;
            end
          else if (rx_valid)
            begin
              count <= rx_data[7:0];
              state <= READ_WAIT;
            end

        READ_WAIT: // Wait for line to become idle
          if (rx_idle)
            state <= READ_RETURN;

        READ_RETURN: // Respond with master's station address
          begin
            tx_fifo_wr_data <= 8'h00; // Station 0, master
            tx_fifo_we <= 1;
            state <= READ_GET;
          end

        READ_GET: // Get register value from bus
          if (count)
            begin
              count <= count - 1'd1;
              re <= 1;
              state <= READ_SEND;
              timeout <= 5; // All accesses are quick
            end
          else
            state <= IDLE;

        READ_SEND: // Send it to master
          if (ack || timeout == 1)
            begin
              state <= READ_GET;
              addr <= addr + 1'd1;
              if (count)
                tx_fifo_wr_data <= { 1'd0, data_in };
              else
                tx_fifo_wr_data <= { 1'd1, data_in }; // Last byte
              tx_fifo_we <= 1;
            end

        IGNORE: // Ignore this frame, it's not for us
          if (rx_idle)
            state <= IDLE;

      endcase

    end

endmodule
