// Ethernet Rx framer

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

// DA, SA, LEN/type and payload end up in FIFO.
// FCS is stripped.

// Bad packets do not show up in the FIFO- they are discarded.  Counters indicate
// that this has happened.

// Define to have a packet FIFO: one word for each packet
// `define PACKET_FIFO 1

module eth_rx
  (
  input reset_l,
  input clk,

  input [7:0] rxdata,
  input rx_k,

  // Data FIFO: only body data is saved in it.
  input data_fifo_re,
  output wire [7:0] data_fifo_rd_data,
  output wire data_fifo_rd_last,
  output wire data_fifo_ne,

`ifdef PACKET_FIFO
  // Packet header FIFO: one entry per good packet
  input packet_fifo_re,
  output wire [11:0] packet_fifo_rd_len,
  output wire packet_fifo_rd_broadcast,
  output wire packet_fifo_rd_forme,
  output wire packet_fifo_rd_arp,
  output wire packet_fifo_rd_ip,
  output wire packet_fifo_ne,
`endif

  // Counters
  output reg [31:0] count_crc_error,
  output reg [31:0] count_full_discard,
  output reg [31:0] count_toomany_discard,
  output reg [31:0] count_toobig_discard,
  output reg [31:0] count_toosmall_discard,
  output reg [31:0] count_good,
  output reg [31:0] count_filtered,

  // My MAC address
  input [47:0] mac_addr
  );

reg data_fifo_we;
reg data_fifo_commit;
reg data_fifo_rollback;
reg [7:0] data_fifo_wr_data;
reg data_fifo_wr_last;
wire data_fifo_af;

reg packet_fifo_we;
reg [11:0] packet_fifo_wr_len;
reg packet_fifo_wr_broadcast;
reg packet_fifo_wr_forme;
reg packet_fifo_wr_arp;
reg packet_fifo_wr_ip;
wire packet_fifo_af;

// Data FIFO

frame_fifo_late #(.DATAWIDTH(9), .ADDRWIDTH(12), .SLOP(2048)) data_fifo
  (
  .clk (clk),
  .reset_l (reset_l),

  .wr_data ({ data_fifo_wr_last, data_fifo_wr_data }), // Write data
  .we (data_fifo_we), // Write enable
  .commit (data_fifo_commit),
  .rollback (data_fifo_rollback),
  .af (data_fifo_af), // Almost full registered
  .cf (),
  .ovf (), // Overflow

  .rd_data ({ data_fifo_rd_last, data_fifo_rd_data }),
  .re (data_fifo_re), // Read enable
  .ne (data_fifo_ne),
  .unf () // Underflow
  );

`ifdef PACKET_FIFO

// Packet FIFO

fifo_sync #(.DATAWIDTH(16), .ADDRWIDTH(5)) packet_fifo
  (
  .clk (clk),
  .reset_l (reset_l),

  .wr_data ({ packet_fifo_wr_ip, packet_fifo_wr_arp, packet_fifo_wr_forme, packet_fifo_wr_broadcast, packet_fifo_wr_len }), // Write data
  .we (packet_fifo_we), // Write enable
  .af (packet_fifo_af), // Almost full registered
  .cf (),
  .ovf (), // Overflow

  .ns_rd_data ({ packet_fifo_rd_ip, packet_fifo_rd_arp, packet_fifo_rd_forme, packet_fifo_rd_broadcast, packet_fifo_rd_len }),
  .rd_data (), // Read data registered
  .re (packet_fifo_re), // Read enable
  .ns_ne (packet_fifo_ne),
  .ne (), // Not empty registered
  .unf () // Underflow
  );

`else

assign packet_fifo_af = 0;

`endif

// State machine

reg [2:0] state;

parameter
  IDLE = 0,
  CAR = 1,
  DATA = 2,
  CHECK = 3,
  FILTER = 4
  ;

reg [11:0] len;

reg [7:0] pipe_data_0;
reg pipe_we_0;
reg pipe_rollback_0;
reg pipe_commit_0;
reg pipe_packet_fifo_we_0;

reg [7:0] pipe_data_1;
reg pipe_we_1;
reg pipe_rollback_1;
reg pipe_commit_1;
reg pipe_packet_fifo_we_1;

reg [7:0] pipe_data_2;
reg pipe_we_2;
reg pipe_rollback_2;
reg pipe_commit_2;
reg pipe_packet_fifo_we_2;

reg [7:0] pipe_data_3;
reg pipe_we_3;
reg pipe_rollback_3;
reg pipe_commit_3;
reg pipe_packet_fifo_we_3;

reg [7:0] pipe_data_4;
reg pipe_we_4;
reg pipe_rollback_4;
reg pipe_commit_4;
reg pipe_packet_fifo_we_4;

// CRC

reg crc_clear;
reg crc_we;
wire crc_good;

eth_crc eth_crc
  (
  .clk (clk),
  .reset_l (reset_l),

  .data (pipe_data_4),
  .valid (crc_we),
  .clear (crc_clear),
  .shift (1'd0),

  .out (),
  .good (crc_good)
  );

reg full_discard;
reg toobig_discard;

reg [111:0] eth_header;

always @(posedge clk)
  if (!reset_l)
    begin
      eth_header <= 0;

      state <= IDLE;
      data_fifo_wr_data <= 0;
      data_fifo_we <= 0;
      data_fifo_wr_last <= 0;
      data_fifo_commit <= 0;
      data_fifo_rollback <= 0;
      packet_fifo_we <= 0;
      packet_fifo_wr_len <= 0;
      len <= 0;

      pipe_data_0 <= 0;
      pipe_we_0 <= 0;
      pipe_rollback_0 <= 0;
      pipe_commit_0 <= 0;
      pipe_packet_fifo_we_0 <= 0;

      pipe_data_1 <= 0;
      pipe_we_1 <= 0;
      pipe_rollback_1 <= 0;
      pipe_commit_1 <= 0;
      pipe_packet_fifo_we_1 <= 0;

      pipe_data_2 <= 0;
      pipe_we_2 <= 0;
      pipe_rollback_2 <= 0;
      pipe_commit_2 <= 0;
      pipe_packet_fifo_we_2 <= 0;

      pipe_data_3 <= 0;
      pipe_we_3 <= 0;
      pipe_rollback_3<= 0;
      pipe_commit_3 <= 0;
      pipe_packet_fifo_we_3 <= 0;

      pipe_data_4 <= 0;
      pipe_we_4 <= 0;
      pipe_rollback_4 <= 0;
      pipe_commit_4 <= 0;
      pipe_packet_fifo_we_4 <= 0;

      crc_clear <= 0;
      crc_we <= 0;

      count_crc_error <= 0;
      count_full_discard <= 0;
      count_good <= 0;
      count_toobig_discard <= 0;
      count_toomany_discard <= 0;
      count_toosmall_discard <= 0;

      full_discard <= 0;
      toobig_discard <= 0;

    end
  else
    begin
      crc_clear <= 0;
      crc_we <= 0;
      data_fifo_wr_last <= 0;

      // This pipeline:
      //   Allows last four bytes (FCS) of packet to be deleted.
      //   Sets end of packet mark on the last byte of the packet.
      // Note that packet_fifo_we is also in the pipeline- this is so that we don't indicate that we
      // have a packet until the data has been committed in the data fifo.
      data_fifo_wr_data <= pipe_data_0;
      data_fifo_we <= pipe_we_0;
      data_fifo_commit <= pipe_commit_0;
      data_fifo_rollback <= pipe_rollback_0;
      packet_fifo_we <= pipe_packet_fifo_we_0;

      pipe_data_0 <= pipe_data_1;
      pipe_we_0 <= pipe_we_1;
      pipe_rollback_0 <= pipe_rollback_1;
      pipe_commit_0 <= pipe_commit_1;
      pipe_packet_fifo_we_0 <= pipe_packet_fifo_we_1;

      pipe_data_1 <= pipe_data_2;
      pipe_we_1 <= pipe_we_2;
      pipe_rollback_1 <= pipe_rollback_2;
      pipe_commit_1 <= pipe_commit_2;
      pipe_packet_fifo_we_1 <= pipe_packet_fifo_we_2;

      pipe_data_2 <= pipe_data_3;
      pipe_we_2 <= pipe_we_3;
      pipe_rollback_2 <= pipe_rollback_3;
      pipe_commit_2 <= pipe_commit_3;
      pipe_packet_fifo_we_2 <= pipe_packet_fifo_we_3;

      pipe_data_3 <= pipe_data_4;
      pipe_we_3 <= pipe_we_4;
      pipe_rollback_3 <= pipe_rollback_4;
      pipe_commit_3 <= pipe_commit_4;
      pipe_packet_fifo_we_3 <= pipe_packet_fifo_we_4;

      pipe_we_4 <= 0;
      pipe_rollback_4 <= 0;
      pipe_commit_4 <= 0;
      pipe_packet_fifo_we_4 <= 0;

      case (state)
        IDLE:
          if (rx_k == 1 && rxdata == 8'hfb) // Wait for /S/
            state <= CAR;

        CAR:
          begin
            if (rx_k == 1 && rxdata == 8'hfd) // /T/?
              state <= IDLE;
            if (rx_k == 0 && rxdata == 8'hd5) // SFD
              begin
                state <= DATA;
                len <= 0;
                crc_clear <= 1;
                full_discard <= 0;
                toobig_discard <= 0;
              end
          end

        DATA:
          begin
            if (rx_k == 1 && rxdata == 8'hfd) // /T/
              begin
                // Mark last byte
                data_fifo_wr_last <= 1;
                // Delete FCS
                pipe_we_0 <= 0;
                pipe_we_1 <= 0;
                pipe_we_2 <= 0;
                pipe_we_3 <= 0;
                state <= CHECK;
              end
            else
              begin
                len <= len + 1'd1;
                // if (len >= 14) // Only save the body in the data FIFO
                  pipe_we_4 <= !full_discard && !toobig_discard;
                crc_we <= 1;
                pipe_data_4 <= rxdata;
                if (data_fifo_af) // Oops, can't fit
                  full_discard <= 1;
                if (len >= 1518) // MTU exceeded  6 + 6 + 2 + 1500 + 4 -> 1518 bytes max include SA+DA+LEN/TYPE+FCS
                  toobig_discard <= 1;
                // Keep header in a big shift register...
                if (len < 14)
                  eth_header <= { eth_header[103:0], rxdata };
              end
          end

        CHECK:
          begin
            state <= IDLE;
            pipe_rollback_4 <= 1;
            // Discard?
            if (len < 64)
              begin
                count_toosmall_discard <= count_toosmall_discard + 1'd1;
              end
            else if (!crc_good)
              begin
                count_crc_error <= count_crc_error + 1'd1;
              end
            else if (full_discard)
              begin
                count_full_discard <= count_full_discard + 1'd1;
              end
            else if (toobig_discard)
              begin
                count_toobig_discard <= count_toobig_discard + 1'd1;
              end
            else if (packet_fifo_af)
              begin
                count_toomany_discard <= count_toomany_discard + 1'd1;
              end
            else
              begin
                // It's all good- keep it!
                pipe_rollback_4 <= 0;
                packet_fifo_wr_len <= len - 3'd4;

                // Inspect header
                if (eth_header[111:64] == 48'hff_ff_ff_ff_ff_ff)
                  packet_fifo_wr_broadcast <= 1;
                else
                  packet_fifo_wr_broadcast <= 0;

                if (eth_header[111:64] == mac_addr)
                  packet_fifo_wr_forme <= 1;
                else
                  packet_fifo_wr_forme <= 0;

                if (eth_header[15:0] == 16'h0806)
                  packet_fifo_wr_arp <= 1;
                else
                  packet_fifo_wr_arp <= 0;

                if (eth_header[15:0] == 16'h0800)
                  packet_fifo_wr_ip <= 1;
                else
                  packet_fifo_wr_ip <= 0;

                count_good <= count_good + 1'd1;
                state <= FILTER;
              end
          end

        FILTER:
          begin
            // Packet is good, but do we want it?
            if ((packet_fifo_wr_broadcast || packet_fifo_wr_forme) &&
                (packet_fifo_wr_arp || packet_fifo_wr_ip))
              begin
                // We want it
                packet_fifo_we <= 1;
                pipe_commit_4 <= 1;
              end
            else
              begin
                // It's good, but we don't want it
                pipe_rollback_4 <= 1;
                count_filtered <= count_filtered + 1'd1;
              end
            state <= IDLE;
          end

      endcase
    end

endmodule
