// I2C master interface

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

module i2c_master
  (
  input clk,
  input reset_l,

  output reg scl_out,
  input scl_in,
  output reg sda_out,
  input sda_in,

  input [7:0] addr, // I2C address (LSB is ignored)
  input [7:0] reg_addr, // I2C register address
  input [7:0] wr_data, // I2C write data
  output reg [7:0] rd_data, // I2C read data
  input re, // Read request
  input we, // Write request
  input wdata, // Set if data along with write
  output reg ack // Pulsed when request complete
  );

// I2C subroutines

parameter
  I2C_IDLE = 0,
  I2C_SEND_BYTE = 1,
  I2C_STOP_PREPARE = 2,
  I2C_STOP_SCL = 3,
  I2C_START_SDA = 4,
  I2C_PULSE_SCL_HIGH = 5,
  I2C_PULSE_SCL_LOW = 6,
  I2C_DONE = 7;

reg [2:0] i2c_state;
reg [7:0] count;

reg [3:0] bit_count;
reg [7:0] shift_reg;

reg scl_1;
reg scl_2;

reg sda_1;
reg sda_2;

reg i2c_ack;

reg rtn_send;
reg rtn_recv;

// From main state machine

reg do_send_start;
reg do_send_stop;
reg do_send_byte;
reg do_send_ack;
reg do_send_nack;
reg do_recv_byte;
reg do_recv_ack;

reg [7:0] do_send_data;

parameter DELAY = 177; // 1/2 a period of 100 KHz

always @(posedge clk or negedge reset_l)
  if (!reset_l)
    begin
      i2c_state <= I2C_IDLE;
      scl_out <= 1;
      sda_out <= 1;
      sda_1 <= 1;
      sda_2 <= 1;
      scl_1 <= 1;
      scl_2 <= 1;
      i2c_ack <= 0;
      count <= 0;
      bit_count <= 0;
      rtn_send <= 0;
    end
  else
    begin
      sda_1 <= sda_in;
      sda_2 <= sda_1;

      scl_1 <= scl_in;
      scl_2 <= scl_1;

      i2c_ack <= 0;

      if (count)
        count <= count - 1'd1;

      case (i2c_state)
        I2C_IDLE:
          if (do_send_start)
            begin
              sda_out <= 0;
              count <= DELAY;
              i2c_state <= I2C_START_SDA;
            end
          else if (do_send_stop)
            begin
              sda_out <= 0;
              count <= DELAY;
              i2c_state <= I2C_STOP_PREPARE;
            end
          else if (do_send_ack)
            begin
              sda_out <= 0;
              count <= DELAY;
              i2c_state <= I2C_PULSE_SCL_HIGH;
            end
          else if (do_send_nack)
            begin
              sda_out <= 1;
              count <= DELAY;
              i2c_state <= I2C_PULSE_SCL_HIGH;
            end
          else if (do_send_byte)
            begin
              shift_reg <= do_send_data;
              rtn_send <= 1;
              bit_count <= 8;
              i2c_state <= I2C_SEND_BYTE;
            end
          else if (do_recv_byte)
            begin
              sda_out <= 1;
              rtn_recv <= 1;
              bit_count <= 7;
              i2c_state <= I2C_PULSE_SCL_HIGH;
              count <= DELAY;
            end
          else if (do_recv_ack)
            begin
              sda_out <= 1;
              rtn_recv <= 1;
              bit_count <= 0; // Receive just one bit
              i2c_state <= I2C_PULSE_SCL_HIGH;
              count <= DELAY;
            end

        I2C_SEND_BYTE:
          if (bit_count)
            begin
              bit_count <= bit_count - 1'd1;
              sda_out <= shift_reg[7];
              shift_reg <= { shift_reg[6:0], 1'd0 };
              count <= DELAY;
              i2c_state <= I2C_PULSE_SCL_HIGH;
            end
          else
            begin
              rtn_send <= 0;
              i2c_ack <= 1;
              i2c_state <= I2C_IDLE;
            end

        I2C_STOP_PREPARE:
          if (!count)
            begin
              i2c_state <= I2C_STOP_SCL;
              scl_out <= 1;
              count <= DELAY;
            end

        I2C_STOP_SCL:
          if (!count)
            begin
              i2c_state <= I2C_DONE;
              sda_out <= 1;
              count <= DELAY;
            end

        I2C_START_SDA:
          if (!count)
            begin
              i2c_state <= I2C_DONE;
              scl_out <= 0;
              count <= DELAY;
            end

        I2C_PULSE_SCL_HIGH:
          if (!count)
            begin
              scl_out <= 1;
              count <= DELAY;
              i2c_state <= I2C_PULSE_SCL_LOW;
            end

        I2C_PULSE_SCL_LOW:
          if (!count)
            begin
              scl_out <= 0;
              count <= DELAY;
              i2c_state <= I2C_DONE;
              if (rtn_recv)
                begin
                  shift_reg <= { shift_reg[6:0], sda_2 };
                end
            end

        I2C_DONE:
          if (!count)
            begin
              if (rtn_send)
                begin
                  if (bit_count)
                    begin
                      bit_count <= bit_count - 1'd1;
                      sda_out <= shift_reg[7];
                      shift_reg <= { shift_reg[6:0], 1'd0 };
                      count <= DELAY;
                      i2c_state <= I2C_PULSE_SCL_HIGH;
                    end
                  else
                    begin
                      rtn_send <= 0;
                      i2c_ack <= 1;
                      i2c_state <= I2C_IDLE;
                    end
                end
              else if (rtn_recv)
                begin
                  if (bit_count)
                    begin
                      bit_count <= bit_count - 1'd1;
                      i2c_state <= I2C_PULSE_SCL_HIGH;
                      count <= DELAY;
                    end
                  else
                    begin
                      rtn_recv <= 0;
                      i2c_ack <= 1;
                      i2c_state <= I2C_IDLE;
                    end
                end
              else
                begin
                  i2c_state <= I2C_IDLE;
                  i2c_ack <= 1;
                end
            end

      endcase
    end

// Main state machine

parameter
  IDLE = 0,
  WRITE_START = 1,
  WRITE_ADDR = 2,
  WRITE_ADDR_ACK = 3,
  WRITE_REG = 4,
  WRITE_REG_ACK = 5,
  WRITE_DATA = 6,
  WRITE_DATA_ACK = 7,
  FAIL = 8,
  WAIT_DONE = 9,
  READ_START = 10,
  READ_ADDR = 11,
  READ_ADDR_ACK = 12,
  READ_DATA = 13,
  READ_DATA_NACK = 14
  ;

reg [3:0] state;

always @(posedge clk or negedge reset_l)
  if (!reset_l)
    begin
      state <= IDLE;
      do_send_start <= 0;
      do_send_stop <= 0;
      do_send_byte <= 0;
      do_send_ack <= 0;
      do_send_nack <= 0;
      do_recv_byte <= 0;
      do_recv_ack <= 0;
      do_send_data <= 0;
    end
  else
    begin
      do_send_start <= 0;
      do_send_stop <= 0;
      do_send_byte <= 0;
      do_send_ack <= 0;
      do_send_nack <= 0;
      do_recv_byte <= 0;
      do_recv_ack <= 0;
      ack <= 0;

      case (state)
        IDLE:
          if (we)
            begin
              state <= WRITE_START;
              do_send_start <= 1;
            end
          else if (re)
            begin
              state <= READ_START;
              do_send_start <= 1;
            end

        WRITE_START:
          if (i2c_ack)
            begin
              do_send_data <= { addr[7:1], 1'd0 };
              do_send_byte <= 1;
              state <= WRITE_ADDR;
            end

        WRITE_ADDR:
          if (i2c_ack)
            begin
              do_recv_ack <= 1;
              state <= WRITE_ADDR_ACK;
            end

        WRITE_ADDR_ACK:
          if (i2c_ack)
            if (!shift_reg[0]) // Did we get ack?
              begin
                do_send_data <= reg_addr;
                do_send_byte <= 1;
                state <= WRITE_REG;
              end
            else
              state <= FAIL;

        WRITE_REG:
          if (i2c_ack)
            begin
              state <= WRITE_REG_ACK;
              do_recv_ack <= 1;
            end

        WRITE_REG_ACK:
          if (i2c_ack)
            if (!shift_reg[0])
              begin
                if (wdata) // Write some data
                  begin
                    do_send_data <= wr_data;
                    do_send_byte <= 1;
                    state <= WRITE_DATA;
                  end
                else // Just set address
                  begin
                    do_send_stop <= 1;
                    state <= WAIT_DONE;
                  end
              end
            else
              state <= FAIL;

        WRITE_DATA:
          if (i2c_ack)
            begin
              state <= WRITE_DATA_ACK;
              do_recv_ack <= 1;
            end

        WRITE_DATA_ACK:
          if (i2c_ack)
            if (!shift_reg[0])
              begin
                do_send_stop <= 1;
                state <= WAIT_DONE;
              end
            else
              state <= FAIL;

        FAIL:
          begin
            do_send_stop <= 1;
            state <= WAIT_DONE;
          end

        WAIT_DONE:
          if (i2c_ack)
            begin
              state <= IDLE;
              ack <= 1;
            end

        READ_START:
          if (i2c_ack)
            begin
              do_send_data <= { addr[7:1], 1'd1 };
              do_send_byte <= 1;
              state <= READ_ADDR;
            end

        READ_ADDR:
          if (i2c_ack)
            begin
              do_recv_ack <= 1;
              state <= READ_ADDR_ACK;
            end

        READ_ADDR_ACK:
          if (i2c_ack)
            if (!shift_reg[0]) // Did we get ack?
              begin
                do_recv_byte <= 1;
                state <= READ_DATA;
              end
            else
              state <= FAIL;

        READ_DATA:
          if (i2c_ack)
            begin
              rd_data <= shift_reg;
              do_send_nack <= 1;
              state <= READ_DATA_NACK;
            end

        READ_DATA_NACK:
          if (i2c_ack)
            begin
              do_send_stop <= 1;
              state <= WAIT_DONE;
            end

      endcase
    end

endmodule
