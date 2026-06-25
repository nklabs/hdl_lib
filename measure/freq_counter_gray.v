// This one uses a gray code to pass the counter value from one clock domain to the other.

// clk has frequency CLK_FREQ
// hz is in clk domain

// There are no control signals passed to the counter so no problems with very low clock frequencies.  But lots of logic for bin to gray and back conversions.

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

module freq_counter_gray
#(
  parameter CLK_FREQ = 33333333, // Frequency in Hz of clk
  parameter WIDTH = 28
) (
  input pxclk,

  input clk,
  input reset_l,
  output [WIDTH-1:0] hz
  );

// Convert binary to gray code

function [WIDTH-1:0] bin_to_gray;
input [WIDTH-1:0] i;
integer x;
  begin
    bin_to_gray[WIDTH-1] = i[WIDTH-1];
    for (x = 0; x != WIDTH - 1; x = x + 1)
      bin_to_gray[x] = i[x]^i[x+1];
  end
endfunction

// Convert gray code to binary

function [WIDTH-1:0] gray_to_bin;
input [WIDTH-1:0] i;
integer x;
  begin
    gray_to_bin = i;
    for (x = 1; x != WIDTH; x = x + 1)
      gray_to_bin = gray_to_bin ^ (i >> x);
  end
endfunction

// Main counter

reg [WIDTH-1:0] counter;
reg [WIDTH-1:0] counter_gray;

always @(posedge pxclk or negedge reset_l)
  if (!reset_l)
    begin
      counter <= 0;
      counter_gray <= 0;
    end
  else
    begin
      counter <= counter + 1'd1;
      counter_gray <= bin_to_gray(counter);
    end

// State machine

reg [WIDTH-1:0] cnt;
reg [WIDTH-1:0] old;
reg [WIDTH-1:0] hz;
reg [WIDTH-1:0] counter_gray_1;
reg [WIDTH-1:0] counter_gray_2;
reg [WIDTH-1:0] counter_ungray;

always @(posedge clk)
  if (!reset_l)
    begin
      cnt <= 0;
      old <= 0;
      hz <= 0;
      counter_gray_1 <= 0;
      counter_gray_2 <= 0;
      counter_ungray <= 0;
    end
  else
    begin
      counter_gray_1 <= counter_gray;
      counter_gray_2 <= counter_gray_1;
      counter_ungray <= gray_to_bin(counter_gray_2);

      if (cnt)
        cnt <= cnt - 1'd1;

      if (!cnt)
        begin
          cnt <= CLK_FREQ - 1;
          old <= counter_ungray;
          hz <= counter_ungray - old;
        end
    end

endmodule
