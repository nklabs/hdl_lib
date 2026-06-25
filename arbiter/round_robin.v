// Simple round-robin arbiter

// Copyright 2010 Joe Allen

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

module round_robin
#(
  parameter WIDTH = 11
) (
  input [WIDTH-1:0] req,
  input [WIDTH-1:0] prev,
  output [WIDTH-1:0] gnt,
  output any
  );

wire [WIDTH-1:0] gnt0 = req & -req;

wire [WIDTH-1:0] req1 = req & ~((prev - 1'd1) | prev);

wire [WIDTH-1:0] gnt1 = req1 & -req1;

assign gnt = |req1 ? gnt1 : gnt0;

assign any = |req;

endmodule
