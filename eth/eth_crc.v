// Ethernet byte at a time CRC generator / checker

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

module eth_crc
  (
  input clk,
  input reset_l,

  input [7:0] data, // Data in
  input valid, // High if data is valid
  input clear, // High to reset CRC accumulator
  input shift, // High to shift CRC output to next byte

  output wire [7:0] out, // CRC to transmit, byte at a time
  output wire good // High if CRC is good
  );

reg [31:0] crc;

always @(posedge clk)
  if (!reset_l)
    begin
      crc <= 32'hffff_ffff;
    end
  else
    begin
      if (valid)
        begin
          crc[0] <= crc[24]^crc[30]^data[1]^data[7];
          crc[1] <= crc[25]^crc[31]^data[0]^data[6]^crc[24]^crc[30]^data[1]^data[7];
          crc[2] <= crc[26]^data[5]^crc[25]^crc[31]^data[0]^data[6]^crc[24]^crc[30]^data[1]^data[7];
          crc[3] <= crc[27]^data[4]^crc[26]^data[5]^crc[25]^crc[31]^data[0]^data[6];
          crc[4] <= crc[28]^data[3]^crc[27]^data[4]^crc[26]^data[5]^crc[24]^crc[30]^data[1]^data[7];
          crc[5] <= crc[29]^data[2]^crc[28]^data[3]^crc[27]^data[4]^crc[25]^crc[31]^data[0]^data[6]^crc[24]^crc[30]^data[1]^data[7];
          crc[6] <= crc[30]^data[1]^crc[29]^data[2]^crc[28]^data[3]^crc[26]^data[5]^crc[25]^crc[31]^data[0]^data[6];
          crc[7] <= crc[31]^data[0]^crc[29]^data[2]^crc[27]^data[4]^crc[26]^data[5]^crc[24]^data[7];
          crc[8] <= crc[0]^crc[28]^data[3]^crc[27]^data[4]^crc[25]^data[6]^crc[24]^data[7];
          crc[9] <= crc[1]^crc[29]^data[2]^crc[28]^data[3]^crc[26]^data[5]^crc[25]^data[6];
          crc[10] <= crc[2]^crc[29]^data[2]^crc[27]^data[4]^crc[26]^data[5]^crc[24]^data[7];
          crc[11] <= crc[3]^crc[28]^data[3]^crc[27]^data[4]^crc[25]^data[6]^crc[24]^data[7];
          crc[12] <= crc[4]^crc[29]^data[2]^crc[28]^data[3]^crc[26]^data[5]^crc[25]^data[6]^crc[24]^crc[30]^data[1]^data[7];
          crc[13] <= crc[5]^crc[30]^data[1]^crc[29]^data[2]^crc[27]^data[4]^crc[26]^data[5]^crc[25]^crc[31]^data[0]^data[6];
          crc[14] <= crc[6]^crc[31]^data[0]^crc[30]^data[1]^crc[28]^data[3]^crc[27]^data[4]^crc[26]^data[5];
          crc[15] <= crc[7]^crc[31]^data[0]^crc[29]^data[2]^crc[28]^data[3]^crc[27]^data[4];
          crc[16] <= crc[8]^crc[29]^data[2]^crc[28]^data[3]^crc[24]^data[7];
          crc[17] <= crc[9]^crc[30]^data[1]^crc[29]^data[2]^crc[25]^data[6];
          crc[18] <= crc[10]^crc[31]^data[0]^crc[30]^data[1]^crc[26]^data[5];
          crc[19] <= crc[11]^crc[31]^data[0]^crc[27]^data[4];
          crc[20] <= crc[12]^crc[28]^data[3];
          crc[21] <= crc[13]^crc[29]^data[2];
          crc[22] <= crc[14]^crc[24]^data[7];
          crc[23] <= crc[15]^crc[25]^data[6]^crc[24]^crc[30]^data[1]^data[7];
          crc[24] <= crc[16]^crc[26]^data[5]^crc[25]^crc[31]^data[0]^data[6];
          crc[25] <= crc[17]^crc[27]^data[4]^crc[26]^data[5];
          crc[26] <= crc[18]^crc[28]^data[3]^crc[27]^data[4]^crc[24]^crc[30]^data[1]^data[7];
          crc[27] <= crc[19]^crc[29]^data[2]^crc[28]^data[3]^crc[25]^crc[31]^data[0]^data[6];
          crc[28] <= crc[20]^crc[30]^data[1]^crc[29]^data[2]^crc[26]^data[5];
          crc[29] <= crc[21]^crc[31]^data[0]^crc[30]^data[1]^crc[27]^data[4];
          crc[30] <= crc[22]^crc[31]^data[0]^crc[28]^data[3];
          crc[31] <= crc[23]^crc[29]^data[2];
        end
      else if (shift)
        begin
          crc <= { crc[23:0], 8'hff };
        end
      else if (clear)
        begin
          crc <= 32'hffff_ffff;
        end
    end

assign out = ~{ crc[24], crc[25], crc[26], crc[27], crc[28], crc[29], crc[30], crc[31] };

assign good = (crc == 32'hc704_dd7b);

endmodule
