// PWM receiver

// First bit after idle will be zero.  Bit 7 of first byte after idle will be a zero.

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

module serial_rx
  (
  input clk,
  input reset_l,

  input rx_in, // Serial input
  output reg [7:0] data, // parallel output
  output reg valid, // A pulse for each valid word
  output reg idle // Set if idle is detected
  );

reg rx_in_reg;
reg rx_1;
reg rx_2;

reg [6:0] sample_count; // Sample counter

reg [7:0] shift_reg; // Receive shift register

reg [2:0] bit_count; // Receive bit counter

reg sample;
reg bit_rx;

always @(posedge clk or negedge reset_l)
  if (!reset_l)
    begin
      data <= 0;
      valid <= 0;
      rx_in_reg <= 0;
      rx_1 <= 0;
      rx_2 <= 0;
      sample_count <= 7'd63; // Assume idle at start
      idle <= 1; // Assume idle at start
      shift_reg <= 0;
      bit_count <= 0;
      sample <= 0;
      bit_rx <= 0;
    end
  else
    begin
      rx_in_reg <= rx_in;
      rx_1 <= rx_in_reg;
      rx_2 <= rx_1;
      valid <= 0;
      sample <= 0;

      if (rx_2 && !rx_1) // Restart on falling edge
        sample_count <= 1;
      else if (rx_1) // High input
        begin
          if (sample_count != 7'd64)
            sample_count <= sample_count - 1'd1;
        end
      else // Low input
        begin
          if (sample_count != 7'd63)
            sample_count <= sample_count + 1'd1;
        end

      if (rx_2 && !rx_1)
        begin
          sample <= 1;
          bit_rx <= sample_count[6];
          // Shift input bit into shift register
          shift_reg <= { shift_reg[6:0], sample_count[6] };
        end

      // Always low means line is idle
      if (sample_count == 7'd63)
        idle <= 1;

      // We have a bit
      if (sample)
        if (idle) // Ignore first bit after idle
          begin
            idle <= 0;
            bit_count <= 0;
          end
        else
          begin
            if (bit_count == 7)
              begin
                bit_count <= 0;
                data <= shift_reg;
                valid <= 1;
              end
            bit_count <= bit_count + 1'd1;
          end
    end

endmodule
