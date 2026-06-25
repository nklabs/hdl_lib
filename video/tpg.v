// Simple test patten generator
// This can be used for both AXI video and standard parallel video

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

module tpg
#(
  parameter DATAWIDTH = 24,
  parameter SINGLE_CYCLE = 1, // Single cycle pulse for vsync and hsync
  parameter PATTERN = 0, // 0 = sequence, 1 = blocks with fade

  parameter HTOTAL = 320,
  parameter HACTIVE = 256,
  parameter HSYNC_START = 272,
  parameter HSYNC_END = 204,

  parameter VTOTAL = 108,
  parameter VACTIVE = 96,
  parameter VSYNC_START = 100,
  parameter VSYNC_END = 104
) (
  input clk,
  input reset_l,
  input video_in_tready,
  output reg video_in_hsync,
  output reg video_in_vsync,
  output reg video_in_de,
  output reg video_in_tvalid,
  output reg video_in_tfirst,
  output reg video_in_tlast,
  output reg [11:0] video_in_trow,
  output reg video_in_tuser,
  output reg [DATAWIDTH-1:0] video_in_tdata
  );

reg [11:0] row;
reg [11:0] col;
reg [11:0] frame;

reg [15:0] pixel;

always @(posedge clk)
  if (!reset_l)
    begin
      row <= 0;
      col <= 0;
      frame <= 0;
      video_in_tvalid <= 0;
      video_in_tlast <= 0;
      video_in_tuser <= 1;
      video_in_tdata <= 0;
      video_in_vsync <= 0;
      video_in_hsync <= 0;
      video_in_de <= 0;
      video_in_trow <= 0;
      video_in_tfirst <= 0;
      pixel <= 0;
    end
  else if (video_in_tready || !video_in_tvalid) // We pause if (!video_in_ready && video_in_tvalid)
    begin
      video_in_tvalid <= 0;
      video_in_hsync <= 0;
      video_in_tuser <= 0;
      video_in_tlast <= 0;
      video_in_tfirst <= 0;
      video_in_trow <= 0;
      video_in_de <= 0;

      if (col == HTOTAL - 1)
        begin
          col <= 0;
          if (row == VTOTAL - 1)
            begin
              row <= 0;
              frame <= frame + 1'd1;
            end
          else
            begin
              if (frame == 1 && row == 3)
                row <= row + 2'd2; // Missing frame for testing
              else
                row <= row + 1'd1;
            end
        end
      else
        begin
          col <= col + 1'd1;
        end

      if (SINGLE_CYCLE)
        begin
          video_in_vsync <= 0;
          if (col == HSYNC_START) // One cycle pulse
            begin
//              video_in_tvalid <= 1;
              video_in_hsync <= 1;
            end
          if (col == HSYNC_START && row == VSYNC_START)
            begin
//              video_in_tvalid <= 1;
              video_in_vsync <= 1;
            end
        end
      else
        begin
          if (col >= HSYNC_START && col < HSYNC_END)
            video_in_hsync <= 1;
          if (col == HSYNC_START && row == VSYNC_START)
            begin
//              video_in_tvalid <= 1;
              video_in_vsync <= 1;
            end
          else if (col == HSYNC_END-1 && row == VSYNC_END-1)
            begin
              video_in_vsync <= 0;
            end
        end


      if (col >= 0 && col < HACTIVE && row >= 0 && row < VACTIVE)
        begin
          video_in_de <= 1;
          video_in_tvalid <= 1;
          video_in_trow <= row;
          if (col == 0)
            video_in_tfirst <= 1;
          if (row == 0 && col == 0)
            video_in_tuser <= 1;
          if (col == HACTIVE - 1)
            video_in_tlast <= 1;
          if (row == 0 && col == 0)
            begin
              video_in_tdata <= 24'h55AA55; // Indicate start of frame inline..
              //video_in_tdata <= 16'haa55;
              pixel <= 1;
            end
          else
            begin
              if (PATTERN == 1)
                begin
                  // Rectangles with fade to prove video is live
                  if (row[4])
                    video_in_tdata <= { (col[7] ? frame[7:0] : 8'h00), (col[6] ? 8'hff : 8'h00), (col[5] ? 8'hff : 8'h00) };
                  else
                    video_in_tdata <= { (col[7] ? 8'h00 : 8'hFF), (col[6] ? 8'h00 : 8'hFF), (col[5] ? 8'h00 : 8'hFF) };
                end
              else
                begin
                  // Or just counting..
                  video_in_tdata <= pixel;
                end
              pixel <= pixel + 1'd1;
            end
        end
    end

endmodule
