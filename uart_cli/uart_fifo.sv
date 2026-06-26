// Author: Karl Peterson

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



//simple reg-based fifo for uart 

module uart_fifo 
  (
  output [7:0] debug_cnt,


  input clk, 
  input reset_l, 

  // write side 
  input wr_en, 
  input [7:0] wr_data, 
  output reg full, 

  // read side 
  input rd_en, 
  output reg [7:0] rd_data, 
  output reg empty
  );

parameter DEPTH = 128;
parameter WIDTH = 8;


reg [7:0] fifo_cnt = 0; 
reg [7:0] wr_index = 0; 
reg [7:0] rd_index = 0; 

(* syn_ramstyle = "rw_check" *) reg [7:0] fifo_data [0:127];

reg full_r;
reg empty_r; 

assign debug_cnt = fifo_cnt; 


always @(posedge clk) begin
  if (!reset_l) begin 
    fifo_cnt <= 0; 
    wr_index <= 0; 
    rd_index <= 0;
  end 
  else begin  
    // track number of words in the fifo 
    if (wr_en && !rd_en)  
      fifo_cnt <= fifo_cnt + 1; 
    else if (!wr_en && rd_en) 
      fifo_cnt <= fifo_cnt - 1; 
      
    // track write index 
    if (wr_en && !full_r) begin 
      if (wr_index == DEPTH - 1)
        wr_index <= 0;
      else 
        wr_index <= wr_index + 1;
    end 

    // track read index
    if (rd_en && !empty_r) begin 
      if (rd_index == DEPTH - 1)
        rd_index <= 0;
      else 
        rd_index <= rd_index + 1; 
    end 

    // write data
    if (wr_en)
      fifo_data[wr_index] <= wr_data; 
  end 
end 

assign rd_data = fifo_data[rd_index]; 

assign full_r = (fifo_cnt == DEPTH)? 1'b1 : 1'b0;  
assign empty_r = (fifo_cnt == 0)? 1'b1 : 1'b0;  

assign full = full_r; 
assign empty = empty_r;

endmodule