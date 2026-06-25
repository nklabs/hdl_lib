// Measure AXI video

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

module vidwatch
  (
  input clk,
  input reset_l,

  output reg [15:0] pixel_rec, // Pixels per line
  output reg [15:0] pixel_count,
  output reg [15:0] line_rec, // Lines per frame
  output reg [15:0] line_count,
  output reg [15:0] frame_count, // Frame counter

  output reg [15:0] line_clks, // Clocks per line
  output reg [23:0] frame_clks, // Clocks per frame

  input valid,
  input ready,
  input last,
  input user
  );

reg [15:0] line_clks_count;
reg [23:0] frame_clks_count;

always @(posedge clk)
  if (!reset_l)
    begin
      pixel_count <= 0;
      pixel_rec <= 0;
      line_count <= 0;
      line_rec <= 0;
      frame_count <= 0;
      frame_clks <= 0;
      frame_clks_count <= 0;
      line_clks <= 0;
      line_clks_count <= 0;
    end
  else
    begin
      frame_clks_count <= frame_clks_count + 1'd1;
      line_clks_count <= line_clks_count + 1'd1;
      if (ready && valid)
        if (last)
          begin
            pixel_count <= 0;
            pixel_rec <= pixel_count + 1'd1;
            line_count <= line_count + 1'd1;
            line_clks <= line_clks_count + 1'd1;
            line_clks_count <= 0;
          end
        else
          begin
            pixel_count <= pixel_count + 1'd1;
            if (user)
              begin
                line_rec <= line_count;
                line_count <= 0;
                frame_count <= frame_count + 1'd1;

                frame_clks <= frame_clks_count + 1'd1;
                frame_clks_count <= 0;
              end
          end
    end

endmodule
