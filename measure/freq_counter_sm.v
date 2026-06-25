// This one uses a reference clock 'clk' of frequency CLK_FREQ
// hz is in 'clk' domain

// It uses a state machine to repeatedly measure the frequency with clear
// and gate signals.  The gate is off when the frequency is read to avoid
// clock domain crossing issues.  The gate requires two pxclk clocks for
// synchronization, so there can be problems with very slow pxclk.

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

module freq_counter_sm
#(
  parameter CLK_FREQ = 33333333,
  parameter WIDTH = 28
) (
  input pxclk,

  input clk,
  input reset_l,
  output reg [WIDTH-1:0] hz
  );

// Reset for counter

reg clear_l;

// Gate for counter

reg gate;

// Counter

reg [WIDTH-1:0] counter;
reg gate_synced_1;
reg gate_synced;

always @(posedge pxclk or negedge clear_l)
  if (!clear_l)
    begin
      counter <= 0;
      gate_synced_1 <= 0;
      gate_synced <= 0;
    end
  else
    begin
      gate_synced_1 <= gate;
      gate_synced <= gate_synced_1;
      if (gate_synced)
        counter <= counter + 1'd1;
    end

// State machine

parameter
  IDLE = 0,
  START = 1,
  STOP = 2,
  SAMPLE = 3,
  NEXT = 4;

reg [2:0] state;

reg [WIDTH-1:0] cnt;

always @(posedge clk)
  if (!reset_l)
    begin
      hz <= 0;
      state <= IDLE;
      clear_l <= 0;
      gate <= 0;
      cnt <= 7;
    end
  else
    begin
      if (cnt)
        cnt <= cnt - 1'd1;

      case (state)
        IDLE:
          if (!cnt)
            begin
              clear_l <= 1;
              cnt <= 7;
              state <= START;
            end

        START:
          if (!cnt)
            begin
              cnt <= CLK_FREQ - 1;
              gate <= 1;
              state <= STOP;
            end

        STOP:
          if (!cnt)
            begin
              gate <= 0;
              state <= SAMPLE;
              cnt <= 7;
            end

        SAMPLE:
          if (!cnt)
            begin
              hz <= counter;
              state <= NEXT;
            end

        NEXT:
          begin
            clear_l <= 0;
            cnt <= 7;
            state <= IDLE;
          end
      endcase
    end

endmodule
