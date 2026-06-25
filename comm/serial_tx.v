// PWM transmitter

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

module serial_tx
  (
  input clk,
  input reset_l,

  output reg pwm_out,	// PWM modulated serial output
  output reg [1:0] tx_out,	// Serial output

  input [8:0] rd_data,	// Read data from FIFO: bit 8 set along with last byte of each packet
  input ne,		// True if FIFO not empty
  output reg re		// Read enable to FIFO
  );

reg [5:0] bit_clk_count; // Divide 50 MHz to bit clock
reg bit_clk;

reg [2:0] enc_count; // Encoder counter: 8 bits per symbol

reg [7:0] cur_data;

reg [7:0] shift_reg;

reg [1:0] state;

parameter
  IDLE = 0,
  BURST = 1,
  DONE = 2,
  PAUSE = 3;

reg srprepare;
reg srload;
reg srdone;

reg pwm_prepare;
reg pwm_off;
reg pwm_on;

always @(posedge clk or negedge reset_l)
  if (!reset_l)
    begin
      state <= IDLE;
      bit_clk_count <= 0;
      bit_clk <= 0;
      cur_data <= 0;
      re <= 0;

      srprepare <= 0;
      srload <= 0;
      srdone <= 0;

      shift_reg <= 0;
      tx_out <= 0;
      enc_count <= 0;
      pwm_out <= 0;

      pwm_prepare <= 0;
      pwm_on <= 0;
      pwm_off <= 0;
    end
  else
    begin
      re <= 0;

      // Bit clock generator
      if (bit_clk_count == 53) // 1 Mbps with 53 MHz clock
        bit_clk_count <= 0;
      else
        bit_clk_count <= bit_clk_count + 1'd1;
      bit_clk <= (bit_clk_count == 52);

      // PWM output
      if (tx_out == 3) // Transmit a 1
        pwm_out <= (bit_clk_count > 18);
      else if (tx_out == 2) // Transmit a 0
        pwm_out <= (bit_clk_count > 35);
      else if  (tx_out == 1)
        pwm_out <= 1;
      else // Transmit idle
        pwm_out <= 0;

      if (bit_clk)
        begin
          // Feed pwm
          if (pwm_prepare)
            begin
              tx_out <= 1;
              pwm_prepare <= 0;
            end
          if (pwm_off)
            begin
              tx_out <= 0;
              pwm_on <= 0;
              pwm_off <= 0;
            end
          else if (pwm_on)
            begin
              tx_out <= { 1'd1, shift_reg[7] };
            end

          // Load shift register
          if (srprepare) // Prepare start of burst
            begin
              pwm_prepare <= 1;
              srprepare <= 0;
            end
          else if (srdone)
            begin
              pwm_off <= 1;
              srdone <= 0;
            end
          else if (srload) // Load encoded data, start
            begin
              shift_reg <= cur_data;
              pwm_on <= 1;
              srload <= 0;
            end
          else // Shift existing data
            begin
              shift_reg <= { shift_reg[6:0], 1'd0 };
            end

          // Bit counter
          enc_count <= enc_count + 1'd1;
        end

      case (state)
        IDLE: // Drive dif-n when we are not bursting
          begin
            if (ne && bit_clk)
              begin
                state <= BURST;
                srprepare <= 1;
                enc_count <= 7;
              end
          end

        BURST:
          begin
            if (bit_clk && enc_count == 7)
              begin
                // Get next data
                if (ne)
                  begin
                    cur_data <= rd_data[7:0];
                    srload <= 1;
                    re <= 1;
                    if (rd_data[8])
                      state <= DONE;
                  end
                else
                  begin // Underflow error
                    srdone <= 1;
                    state <= PAUSE;
                  end
              end
          end

        DONE:
          if (bit_clk && enc_count == 7)
            begin
              srdone <= 1;
              state <= PAUSE;
            end

        PAUSE:
          if (bit_clk)
            begin
              srdone <= 1;
              state <= IDLE;
            end
      endcase

    end

endmodule
