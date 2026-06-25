// Reset syncronizer

// Copyright 2026 NK Labs, LLC

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

module reset_async
  (
  input clk,

  // Async locked signal: indicates clk is stable
  input locked,

  // Reset output
  output wire reset_l
  );

reg reset_l_0 = 0 /* syn_maxfan = 10 */;
reg reset_l_1 = 0 /* syn_maxfan = 10 */;
reg reset_l_2 = 0 /* syn_maxfan = 10 */;
reg reset_l_3 = 0;

assign reset_l = reset_l_0;

always @(posedge clk or negedge locked)
  if (!locked)
    begin
      reset_l_0 <= 0;
      reset_l_1 <= 0;
      reset_l_2 <= 0;
      reset_l_3 <= 0;
    end
  else
    begin
      reset_l_0 <= reset_l_1;
      reset_l_1 <= reset_l_2;
      reset_l_2 <= reset_l_3;
      reset_l_3 <= 1;
    end

endmodule
