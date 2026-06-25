// Detect good video

// video_ok falls if vidclk_reset_l is asserted or if vsync is not seen after VSYNC_TIMEOUT cycles of vidclk

// video_ok rises STARTUP_DELAY cycles of vidclk after first vsync

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

module video_det
  (
  input vidclk,
  input vidclk_reset_l,
  input vsync,
  output reg video_ok
  );

`ifdef SYNTHESIS
parameter STARTUP_DELAY = 6250000;
`else
parameter STARTUP_DELAY = 10;
`endif
parameter VSYNC_TIMEOUT = 1200000; // 27 MHz / 30 Hz (interlaced)

reg [23:0] startup_delay;
reg [19:0] vsync_timeout;

always @(posedge vidclk or negedge vidclk_reset_l)
  if (!vidclk_reset_l)
    begin
      video_ok <= 0;
      startup_delay <= 0;
      vsync_timeout <= 0;
    end
  else
    begin
      // Startup delay
      if (startup_delay && startup_delay != STARTUP_DELAY)
        startup_delay <= startup_delay + 1'd1;

      // Startup once there is no timeout
      if (vsync)
        if (startup_delay == STARTUP_DELAY)
          video_ok <= 1; // First vsync after STARTUP_DELAY, video is good now
        else if (!startup_delay)
          startup_delay <= 1; // Enable STARTUP_DELAY timer

      // Vertical sync timeout
      if (vsync)
        vsync_timeout <= 0; // Reset timeout
      else if (vsync_timeout != VSYNC_TIMEOUT)
        vsync_timeout <= vsync_timeout + 1'd1;
      else
        begin
          // Timeout occurred, video is no good
          video_ok <= 0;
          startup_delay <= 0;
        end
    end

endmodule
