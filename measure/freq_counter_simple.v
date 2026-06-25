// The counter is in the pxclk domain.  pxclk_reset_l must assert if the clock stops, otherwise counter retains the last value
// hz is in pxclk domain
// onehz is an external one Hz clock or pulse

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

module freq_counter_simple
#(
  parameter WIDTH = 28
) (
  input pxclk,
  input pxclk_reset_l,
  input onehz,
  output [WIDTH-1:0] hz
  );

reg onehz_1;
reg onehz_0;
reg onehz_old;
reg [WIDTH-1:0] hzcount;
reg [WIDTH-1:0] hz;

always @(posedge pxclk)
  if (!pxclk_reset_l)
    begin
      hzcount <= 0;
      hz <= 0;
      onehz_1 <= 0;
      onehz_0 <= 0;
      onehz_old <= 0;
    end
  else
    begin
      // Measure frequency using 1 Hz reference
      onehz_1 <= onehz;
      onehz_0 <= onehz_1;
      onehz_old <= onehz_0;

      if (onehz_0 && !onehz_old)
        begin
          hz <= hzcount + 1'd1;
          hzcount <= 0;
        end
      else
        hzcount <= hzcount + 1'd1;
    end

endmodule
