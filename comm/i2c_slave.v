// I2C slave interface

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

module i2c_slave
#(
  parameter I2C_ADDR = 8'h84,
  parameter SINGLE = 0 // Set for single byte register address
) (
  input clk,
  input reset_l,

  // I2C interface pins
  input scl_in,
  input sda_in,
  output reg scl_out,
  output reg sda_out,

  // Ignore I2C if disabled
  input i2c_enable,

  // CSR bus
  output reg [15:0] addr, // register address
  output reg we, // write enable pulse
  output reg re, // read enable pulse
  input ack, // set along with returned read data
  output reg [7:0] data_out, // write data
  input [7:0] data_in // read data
  );

reg bus_timeout;

// Synchronize and de-glitch I2C inputs

reg scl_1;
reg scl_2;
reg scl_3;
reg scl_4;
reg scl;
reg scl_old;

reg sda_1;
reg sda_2;
reg sda_3;
reg sda_4;
reg sda;
reg sda_old;

always @(posedge clk)
  if (!reset_l)
    begin
      scl_1 <= 1;
      scl_2 <= 1;
      scl_3 <= 1;
      scl_4 <= 1;
      scl <= 1;
      scl_old <= 1;

      sda_1 <= 1;
      sda_2 <= 1;
      sda_3 <= 1;
      sda_4 <= 1;
      sda <= 1;
      sda_old <= 1;
    end
  else
    begin
      scl_1 <= scl_in;
      scl_2 <= scl_1;
      scl_3 <= scl_2;
      scl_4 <= scl_3;

      // scl is high if at least 2 bits out of 3 are high
      scl <= !i2c_enable || ((scl_4 && scl_3) || (scl_3 && scl_2) || (scl_4 && scl_2));
      scl_old <= scl;

      sda_1 <= sda_in;
      sda_2 <= sda_1;
      sda_3 <= sda_2;
      sda_4 <= sda_3;

      // sda is high if at least 2 bits out of 3 are high
      sda <= !i2c_enable || ((sda_4 && sda_3) || (sda_3 && sda_2) || (sda_4 && sda_2));
      sda_old <= sda;
    end

// Falling clock edge
wire falling = (scl == 0 && scl_old == 1);

// Start condition
wire start = (sda == 0 && sda_old == 1 && scl == 1);

// Stop condition
wire stop = (sda == 1 && sda_old == 0 && scl == 1);

reg [3:0] state;
reg [2:0] count; // Bit counter
reg [7:0] shift_reg;

parameter
  IDLE = 0,
  WAIT_IDLE = 1,
  GET_DEV_ADDR = 2,
  DEV_ACK = 3,
  READ_FIRST = 4,
  READ = 5,
  READ_ACK = 6,
  GET_REG_ADDR = 7,
  REG_ACK = 8,
  GET_DATA = 9,
  DATA_ACK = 10,
  GET_REG_ADDR_LOW = 11,
  REG_LOW_ACK = 12
  ;

reg [21:0] timeout;

reg wait_ack;

reg release_scl_1;
reg release_scl_2;

always @(posedge clk)
  if (!reset_l)
    begin
      state <= IDLE;
      count <= 0;
      shift_reg <= 0;
      addr <= 0;
      we <= 0;
      re <= 0;
      data_out <= 0;
      scl_out <= 1;
      sda_out <= 1;
      timeout <= 0;
      wait_ack <= 0;
      release_scl_1 <= 0;
      release_scl_2 <= 0;
    end
  else
    begin
      we <= 0;
      re <= 0;
      release_scl_1 <= 0;

      if (ack || bus_timeout)
        begin
          release_scl_1 <= 1;
          wait_ack <= 0;
        end

      release_scl_2 <= release_scl_1;

      if (release_scl_2)
        scl_out <= 1;

      case (state)
        IDLE: // Wait for start
          begin
            scl_out <= 1;
            sda_out <= 1;
          end

        WAIT_IDLE: // Wait for low clock
          if (scl == 0)
            begin
              state <= GET_DEV_ADDR;
              count <= 7;
            end

        GET_DEV_ADDR: // Shift in device address
          if (falling)
            begin
              shift_reg <= { shift_reg[6:0], sda_old };
              count <= count - 1'd1;
              if (count == 0)
                begin
                  if ({ shift_reg[6:0], 1'b0 } == I2C_ADDR)
                    begin
                      sda_out <= 0;
                      state <= DEV_ACK;
                    end
                  else
                      state <= IDLE;
                end
            end

        DEV_ACK: // ACK since address matches
          if (falling)
            begin
              sda_out <= 1;
              if (shift_reg[0] == 0)
                begin
                  // It's a write
                  state <= GET_REG_ADDR;
                  count <= 7;
                end
              else
                begin
                  // It's a read
                  re <= 1;
                  state <= READ_FIRST;
                end
            end

        READ_FIRST: // Wait for data from bus
          if (ack || bus_timeout)
            begin
              shift_reg <= data_in;
              sda_out <= data_in[7];
              count <= 7;
              state <= READ;
            end
          else
            begin
              // Stretch clock until data is available
              scl_out <= 0;
            end

        READ: // Shift out read data
          if (falling)
            begin
              count <= count - 1'd1;
              shift_reg <= { shift_reg[6:0], 1'd0 };
              sda_out <= shift_reg[6];
              if (count == 0)
                begin
                  sda_out <= 1;
                  state <= READ_ACK;
                end
            end

        READ_ACK: // One extra cycle after read
          if (falling)
            begin
              addr <= addr + 1'd1;
              if (sda)
                state <= IDLE;
              else
                begin // Read next byte...
                  re <= 1;
                  state <= READ_FIRST;
                end
            end

        GET_REG_ADDR: // Shift in register/bus address
          if (falling)
            begin
              shift_reg <= { shift_reg[6:0], sda_old };
              count <= count - 1'd1;
              if (count == 0)
                begin
                  sda_out <= 0;
                  state <= REG_ACK;
                  addr <= { 8'd0, shift_reg[6:0], sda_old };
                end
            end

        REG_ACK: // Ack register address
          if (falling)
            begin
              sda_out <= 1;
              if (SINGLE != 0)
                state <= GET_DATA; // For single byte address
              else
                state <= GET_REG_ADDR_LOW;
              count <= 7;
            end

        GET_REG_ADDR_LOW: // Shift in register/bus address
          if (falling)
            begin
              shift_reg <= { shift_reg[6:0], sda_old };
              count <= count - 1'd1;
              if (count == 0)
                begin
                  sda_out <= 0;
                  state <= REG_LOW_ACK;
                  addr[15:8] <= addr[7:0];
                  addr[7:0] <= { shift_reg[6:0], sda_old };
                end
            end

        REG_LOW_ACK: // Ack register address
          if (falling)
            begin
              sda_out <= 1;
              state <= GET_DATA; // For single byte address
              count <= 7;
            end

        GET_DATA: // Shift in bus write data
          begin
            if (wait_ack) // Still waiting for ack? Stretch clock...
              scl_out <= 0;
            if (falling)
              begin
                shift_reg <= { shift_reg[6:0], sda_old };
                count <= count - 1'd1;
                if (count == 0)
                  begin
                    sda_out <= 0;
                    state <= DATA_ACK;
                    data_out <= { shift_reg[6:0], sda_old };
                    we <= 1; // Generate write pulse
                    wait_ack <= 1; // Waiting for ack..
                  end
              end
          end

        DATA_ACK: // Ack data
          if (falling)
            begin
              sda_out <= 1;
              addr <= addr + 1'd1;
              count <= 7;
              state <= GET_DATA;
            end

      endcase

      // Restart state machine if we ever get start, stop or timeout
      if (stop || timeout[21])
        state <= IDLE;

      if (start)
        begin
          state <= WAIT_IDLE;
          sda_out <= 1;
        end

      // Prevent stuck sda
      if (sda_out == 0)
        timeout <= timeout + 1'd1;
      else
        timeout <= 0;
    end

// Bus timeout

reg [13:0] bus_count;

always @(posedge clk)
  if (!reset_l)
    begin
      bus_count <= 0;
      bus_timeout <= 0;
    end
  else
    begin
      bus_timeout <= 0;
      if (bus_count)
        bus_count <= bus_count - 1'd1;
      if (bus_count == 1)
        bus_timeout <= 1;
      if (we || re)
        bus_count <= 16383; // .308 ms
    end

endmodule
