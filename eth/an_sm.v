// Autonegotiation state machine

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

module an_sm
  (
  input clk,
  input reset_l,

  output reg an_start,

  output reg an_done,
  output reg tx_mode,
  output reg [15:0] tx_config,

  // PCS signals

  input comma_sync,
  output reg pwrup,
  output reg serdes_rst,
  output reg rx_serdes_rst,
  output reg pcs_rst
  );

// AN state machine

parameter
  AN_RESET = 0,
  AN_FIRST = 1,
  AN_WAIT = 2,
  AN_WAIT_ACK = 3,
  AN_DONE = 4,
  AN_ZERO = 5,
  AN_A = 6,
  AN_GO = 7,
  AN_CHECK = 8,
  AN_B = 9,
  AN_C = 10,
  AN_D = 11;

reg [3:0] an_state;

reg [26:0] an_timer;

reg comma_sync_1;
reg comma_sync_2;

always @(posedge clk)
  if (!reset_l)
    begin
      an_state <= AN_RESET;
      tx_mode <= 0;
      tx_config <= 0;
      an_done <= 0;

      an_start <= 0;
      an_timer <= 0;
      comma_sync_1 <= 0;
      comma_sync_2 <= 0;

      pwrup <= 1;
      serdes_rst <= 1;
      rx_serdes_rst <= 1;
      pcs_rst <= 1;
    end
  else
    begin
      if (an_timer)
        an_timer <= an_timer - 1'd1;

      comma_sync_2 <= comma_sync_1;
      comma_sync_1 <= comma_sync;

      case (an_state)
        AN_RESET:
          begin
            an_state <= AN_A;
          end

        AN_A:
          begin
            an_timer <= 125000;
            pwrup <= 0; // Supposedly powers down everything including TXPLL
            serdes_rst <= 1;
            pcs_rst <= 1;
            an_state <= AN_B;
          end

        AN_B:
          if (!an_timer)
            begin
              pwrup <= 1;
              an_timer <= 125000;
              an_state <= AN_C;
            end

        AN_C:
          if (!an_timer)
            begin
              serdes_rst <= 0; // Allows TxPLL to run...
              an_timer <= 125000;
              an_state <= AN_D;
            end

        AN_D:
          if (!an_timer)
            begin
              rx_serdes_rst <= 0; // Release after TxPLL locks..
              an_timer <= 125000;
              an_state <= AN_GO;
            end

        AN_GO:
          if (!an_timer)
            begin
              pcs_rst <= 0;
              tx_mode <= 0; // Send idles for a while..
              an_timer <= 125000;
              an_state <= AN_ZERO;
            end

        AN_ZERO:
          if (!an_timer)
            begin
              an_timer <= 125000;
              tx_mode <= 1; // Send reconfig request
              tx_config <= 0;
              an_state <= AN_FIRST;
              an_start <= 0;
            end

        AN_FIRST:
          if (!an_timer)
            begin
              tx_config <= 16'b0000_0000_0110_0000; // Send our capabilities
              an_state <= AN_WAIT;
              an_timer <= 125000000;
            end

        AN_WAIT: // Waiting here most of the time..
          begin
            if (!an_timer)
              an_state <= AN_RESET;
            if (rx_valid && rx_old_config) // Wait for non-zero configs
              begin
                an_start <= 1;
                tx_config <= 16'b0100_0000_0110_0000; // Send ACK
                an_state <= AN_WAIT_ACK;
                an_timer <= 3200000;
              end
          end

        AN_WAIT_ACK:
          begin
            if (!an_timer)
              an_state <= AN_RESET;
            if (/* rx_valid && */ rx_old_config[14]) // Wait for received ACK
              begin
                an_state <= AN_DONE;
                an_timer <= 3200000;
              end
          end

        AN_DONE: // We're done! (when should we reset?)
          begin
            if (!an_timer)
              begin
                an_done <= 1;
                an_state <= AN_CHECK;
              end
          end

        AN_CHECK:
          begin
            if (!comma_sync_2 && !an_timer)
              begin
                an_timer <= 3200000;
              end
            else if (rx_valid && rx_old_config == 0) // Restart if we get config request
              begin
                tx_mode <= 0; // Send idles for a while..
                an_timer <= 3200000;
                an_state <= AN_ZERO;
                an_done <= 0;
              end
            else if (an_timer == 1 && !comma_sync_2) // Reset if we lost sync for a long time
              begin
                // We should also restart if we get reconfig request
                an_state <= AN_RESET;
                an_done <= 0;
              end
          end

      endcase
    end

endmodule
