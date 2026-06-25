// AXI streaming pipeline stage.. to help with timing

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

module axi_stage
 #(
  parameter DATAWIDTH = 24
) (
  input clk,
  input reset_l,

  // Data in
  input s_tuser,
  input s_tlast,
  input [DATAWIDTH-1:0] s_tdata,
  input s_tvalid,
  output reg s_tready,

  // Data out
  output reg m_tuser,
  output reg m_tlast,
  output reg [DATAWIDTH-1:0] m_tdata,
  output reg m_tvalid,
  input m_tready
  );

reg ns_tuser;
reg ns_tlast;
reg [DATAWIDTH-1:0] ns_tdata;
reg ns_tvalid;

always @(posedge clk)
  if (!reset_l)
    begin
      m_tuser <= 0;
      m_tlast <= 0;
      m_tdata <= 0;
      m_tvalid <= 0;
    end
  else
    begin
      m_tuser <= ns_tuser;
      m_tlast <= ns_tlast;
      m_tdata <= ns_tdata;
      m_tvalid <= ns_tvalid;
    end

always @*
  begin
    ns_tuser = m_tuser;
    ns_tlast = m_tlast;
    ns_tdata = m_tdata;
    ns_tvalid = m_tvalid;
    s_tready = 0;

    if (!m_tvalid || (m_tvalid && m_tready))
      begin
        // We don't have data, or it's getting taken this cycle
        // Basically we are ready for data now..
        s_tready = 1;
        if (s_tvalid)
          begin
            // We have data, take it..
            ns_tuser = s_tuser;
            ns_tlast = s_tlast;
            ns_tdata = s_tdata;
            ns_tvalid = 1;
          end
        else
          begin
            // No data, oh well..
            ns_tvalid = 0;
          end
      end
  end

endmodule
