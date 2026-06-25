// Pass a pulse between clock domains

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

module pulse_sync
  (
  input i,
  input i_clk,
  input i_reset_l,
  output wire o,
  input o_clk,
  input o_reset_l
  );

// Convert pulse to edge

reg inv;

always @(posedge i_clk)
  if (!i_reset_l)
    inv <= 0;
  else if (i)
    inv <= !inv;

// Detect edge

reg sync_2;
reg sync_1;
reg sync_0;

always @(posedge o_clk)
  if (!o_reset_l)
    begin
      sync_2 <= 0;
      sync_1 <= 0;
      sync_0 <= 0;
    end
  else
    begin
      sync_2 <= inv;
      sync_1 <= sync_2;
      sync_0 <= sync_1;
    end

assign o = (sync_0 != sync_1);

endmodule
