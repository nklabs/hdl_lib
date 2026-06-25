// Ethernet transmit framer

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

// You need to provide:
//   DA, SA, LEN/TYPE and body

// This framer appends padding bytes (if needed) and FCS

// Assert data_fifo_last along with last byte written.
// Transmission does not start until last byte has been written, so writer can be slow.

module eth_tx
  (
  input clk,
  input reset_l,

  // Data to transmit
  input [7:0] data_fifo_wr_data,
  input data_fifo_wr_last, // High along with last byte
  input data_fifo_we,
  output wire data_fifo_af,

  // Video to transmit
  input [7:0] vid_fifo_wr_data,
  input vid_fifo_wr_last, // High along with last byte
  input vid_fifo_we,
  output wire vid_fifo_af,

  // Data out to PCS
  output wire [7:0] txdata,
  output reg tx_k,
  );

reg [7:0] outreg;

// Transmit FIFO

wire [7:0] fifo_rd_data;
wire fifo_rd_last;
reg fifo_re;
wire fifo_ne;

frame_fifo #(.DATAWIDTH(9), .ADDRWIDTH(12)) tx_fifo
  (
  .clk (clk),
  .reset_l (reset_l),

  .wr_data ({ data_fifo_wr_last, data_fifo_wr_data }),
  .we (data_fifo_we),
  .af (data_fifo_af),
  .commit (data_fifo_we && data_fifo_wr_last),
  .rollback (1'b0),

  .ns_rd_data ({ fifo_rd_last, fifo_rd_data }),
  .re (fifo_re),
  .ns_ne (fifo_ne)
  );

// Video transmit FIFO

wire [7:0] vid_rd_data;
wire vid_rd_last;
reg vid_re;
wire vid_ne;

frame_fifo #(.DATAWIDTH(9), .ADDRWIDTH(12)) vid_tx_fifo
  (
  .clk (clk),
  .reset_l (reset_l),

  .wr_data ({ vid_fifo_wr_last, vid_fifo_wr_data }),
  .we (vid_fifo_we),
  .af (vid_fifo_af),
  .commit (vid_fifo_we && vid_fifo_wr_last),
  .rollback (1'b0),

  .ns_rd_data ({ vid_rd_last, vid_rd_data }),
  .re (vid_re),
  .ns_ne (vid_ne)
  );

// CRC generator

reg crc_clear;
reg crc_shift;
reg crc_valid;
wire [7:0] crc_out;

eth_crc eth_crc
  (
  .clk (clk),
  .reset_l (reset_l),
  .data (outreg),
  .valid (crc_valid),
  .clear (crc_clear),
  .shift (crc_shift),
  .out (crc_out),
  .good ()
  );

// Insert FCS
assign txdata = crc_shift ? crc_out : outreg;

// Transmit state machine

reg [3:0] state;
reg [3:0] count;
reg [11:0] len;

parameter
  RESET = 0,
  IDLE = 1,
  START = 2,
  PREAMBLE = 3,
  DATA = 4,
  PAD = 5,
  FCS = 6,
  IFG = 7,
  IFG_EXTRA = 8;

reg sel;

always @(posedge clk)
  if (!reset_l)
    begin
      outreg <= 0;
      tx_k <= 0;
      state <= IDLE;
      crc_clear <= 0;
      crc_shift <= 0;
      crc_valid <= 0;
      count <= 0;
      len <= 0;
      fifo_re <= 0;
      vid_re <= 0;
      sel <= 0;
    end
  else
    begin
      crc_clear <= 0;
      crc_shift <= 0;
      crc_valid <= 0;
      fifo_re <= 0;
      vid_re <= 0;
      tx_k <= 0;
      if (count)
        count <= count - 1;
      case (state)
        RESET:
          begin
            outreg <= 8'hbc; // K28.5
            tx_k <= 1;
            state <= IDLE;
          end
        IDLE:
          begin
            outreg <= 8'h50;
            if ((vid_ne || fifo_ne) && !count) // We have a packet and IFG is done
              begin
                sel <= vid_ne; // Priority to vid_fifo
                state <= START;
              end
            else
              state <= RESET;
          end
        START:
          begin
            outreg <= 8'hfb; // K27.7 aka /S/
            tx_k <= 1;
            count <= 6;
            state <= PREAMBLE;
            len <= 0;
          end
        PREAMBLE:
          if (count)
            begin
              outreg <= 8'h55; // Preamble
            end
          else
            begin
              outreg <= 8'hD5; // SFD
              state <= DATA;
              crc_clear <= 1;
            end
        DATA:
          begin
            len <= len + 1'd1;
            if (sel)
              begin
                outreg <= vid_rd_data;
                vid_re <= 1;
                if (vid_rd_last)
                  state <= PAD;
              end
            else
              begin
                outreg <= fifo_rd_data;
                fifo_re <= 1;
                if (fifo_rd_last)
                  state <= PAD;
              end
            crc_valid <= 1;
          end
        PAD:
          if (len < 12'd60) // Insert zero until we have minimum length
            begin
              len <= len + 1'd1;
              outreg <= 8'h00;
              crc_valid <= 1;
            end
          else
            begin // Insert FCS
              count <= 3;
              outreg <= crc_out;
              crc_shift <= 1;
              state <= FCS;
            end
        FCS: // Reset of FCS
          if (count)
            begin
              outreg <= crc_out;
              crc_shift <= 1;
            end
          else
            begin // End of packet marker
              outreg <= 8'hfd; // K29.7 aka /T/
              tx_k <= 1;
              state <= IFG;
            end
        IFG:
          begin
            outreg <= 8'hf7; // F23.7 aka /R/
            tx_k <= 1;
            count <= 12;
            if (len[0])
              state <= IFG_EXTRA;
            else
              state <= RESET;
          end
        IFG_EXTRA:
          begin
            outreg <= 8'hf7; // F23.7 aka /R/
            tx_k <= 1;
            count <= 12;
            state <= RESET;
          end
      endcase
    end

endmodule
