// Instruction cache

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

module icache
#(
  parameter LOG_SIZE_FILL = 10,
  parameter LOG_SIZE_MEM = 24,
  parameter SIZE_MEM = (1 << LOG_SIZE_MEM), // Size of memory in bytes
  parameter LOG_LINESIZE = 5,
  parameter LINESIZE = (1 << LOG_LINESIZE), // Cache line size in bytes
  parameter LOG_LINES = 10,
  parameter LINES = (1 << LOG_LINES), // Number of cache lines

  parameter CACHE_SIZE = LINES * LINESIZE, // Cache size in bytes

  parameter TAG_SIZE = (LOG_SIZE_MEM - (LOG_LINESIZE + LOG_LINES))
) (
  input reset_l,
  input clk,

  // CPU side
  input client_rd_req,
  input [LOG_SIZE_MEM-1:0] client_addr, // Byte address
  output reg client_rd_ack,
  output [31:0] client_rd_data,

  // Flash side
  output reg [LOG_SIZE_MEM-1:0] spimem_addr, // Byte address
  input [31:0] spimem_rdata,
  input spimem_ready,
  output reg spimem_valid,

  output reg [23:0] miss0,
  output reg [23:0] miss1,
  output reg [23:0] hit0,
  output reg [23:0] hit1,
  output reg [23:0] fhit0,
  output reg [23:0] fhit1,

  input [LOG_SIZE_FILL-1:0] fill_rd_addr,
  output [LOG_SIZE_MEM-1:0] fill_rd_data
  );

reg [LOG_SIZE_MEM-1:0] n_spimem_addr;
reg n_spimem_valid;

// Tag RAM

wire [TAG_SIZE:0] tag0_ram_rd_data;
wire [TAG_SIZE:0] tag1_ram_rd_data;
reg [LOG_LINES-1:0] n_tag_ram_rd_addr, tag_ram_rd_addr;
reg [TAG_SIZE:0] n_tag_ram_wr_data, tag_ram_wr_data;
reg [LOG_LINES-1:0] n_tag_ram_wr_addr, tag_ram_wr_addr;
reg n_tag0_ram_we;
reg n_tag1_ram_we;

reg n_wr_way, wr_way;

ram_blk_dp #(.DATAWIDTH(1 + TAG_SIZE), .ADDRWIDTH(LOG_LINES)) tag0_ram
  (
  .clk (clk),
  .wr_data (n_tag_ram_wr_data),
  .wr_addr (n_tag_ram_wr_addr),
  .we (n_tag0_ram_we),
  .rd_data (tag0_ram_rd_data),
  .rd_addr (n_tag_ram_rd_addr)
  );

ram_blk_dp #(.DATAWIDTH(1 + TAG_SIZE), .ADDRWIDTH(LOG_LINES)) tag1_ram
  (
  .clk (clk),
  .wr_data (n_tag_ram_wr_data),
  .wr_addr (n_tag_ram_wr_addr),
  .we (n_tag1_ram_we),
  .rd_data (tag1_ram_rd_data),
  .rd_addr (n_tag_ram_rd_addr)
  );

// Cache RAM

reg [LOG_LINES + LOG_LINESIZE - 3:0] cache_ram_rd_addr, n_cache_ram_rd_addr;
reg [LOG_LINES + LOG_LINESIZE - 3:0] cache_ram_wr_addr, n_cache_ram_wr_addr;
reg n_cache0_ram_we;
reg n_cache1_ram_we;

wire [31:0] cache0_rd_data;
wire [31:0] cache1_rd_data;

reg n_rd_way, rd_way;

assign client_rd_data = n_rd_way ? cache1_rd_data : cache0_rd_data;

ram_blk_dp #(.DATAWIDTH(32), .ADDRWIDTH(LOG_LINES + LOG_LINESIZE - 2)) data0_ram
  (
  .clk (clk),
  .wr_data (spimem_rdata),
  .wr_addr (cache_ram_wr_addr),
  .we (n_cache0_ram_we),
  .rd_data (cache0_rd_data),
  .rd_addr (n_cache_ram_rd_addr)
  );

ram_blk_dp #(.DATAWIDTH(32), .ADDRWIDTH(LOG_LINES + LOG_LINESIZE - 2)) data1_ram
  (
  .clk (clk),
  .wr_data (spimem_rdata),
  .wr_addr (cache_ram_wr_addr),
  .we (n_cache1_ram_we),
  .rd_data (cache1_rd_data),
  .rd_addr (n_cache_ram_rd_addr)
  );

// LRU RAM

wire prev_way;

ram_blk_dp #(.DATAWIDTH(1), .ADDRWIDTH(LOG_LINES)) lru_ram
  (
  .clk (clk),
  .wr_data (n_tag1_ram_we),
  .wr_addr (n_tag_ram_wr_addr),
  .we (n_tag0_ram_we || n_tag1_ram_we),
  .rd_data (prev_way),
  .rd_addr (n_tag_ram_rd_addr)
  );

// Client side state machine

reg client_waiting, n_client_waiting;
reg [LOG_SIZE_MEM-1:0] client_hold_addr, n_client_hold_addr;

// Information about line currently being loaded
// _d to account for delay through memory
reg [LOG_LINESIZE-3:0] working_low, n_working_low, working_low_d;
reg [LOG_LINESIZE-3:0] working_high, n_working_high, working_high_d;
reg [LOG_SIZE_MEM-LOG_LINESIZE-1:0] working_line, n_working_line, working_line_d;

reg cache_ready, n_cache_ready; // Indicates that initial clearing is done

// Number of accesses (not really hits)
reg [23:0] n_hit0;
reg [23:0] n_hit1;
reg [23:0] n_fhit0;
reg [23:0] n_fhit1;

always @(posedge clk)
  if (!reset_l)
    begin
      tag_ram_rd_addr <= 0;
      cache_ram_rd_addr <= 0;
      client_hold_addr <= 0;
      client_waiting <= 0;
      working_low_d <= 0;
      working_high_d <= 0;
      working_line_d <= 0;
      rd_way <= 0;
      hit0 <= 0;
      hit1 <= 0;
      fhit0 <= 0;
      fhit1 <= 0;
    end
  else
    begin
      tag_ram_rd_addr <= n_tag_ram_rd_addr;
      cache_ram_rd_addr <= n_cache_ram_rd_addr;
      client_hold_addr <= n_client_hold_addr;
      client_waiting <= n_client_waiting;
      working_low_d <= working_low;
      working_high_d <= working_high;
      working_line_d <= working_line;
      rd_way <= n_rd_way;
      hit0 <= n_hit0;
      hit1 <= n_hit1;
      fhit0 <= n_fhit0;
      fhit1 <= n_fhit1;
    end

always @(*)
  begin
    n_rd_way = rd_way;
    n_tag_ram_rd_addr = tag_ram_rd_addr;
    n_cache_ram_rd_addr = cache_ram_rd_addr;
    n_client_waiting = client_waiting;
    n_client_hold_addr = client_hold_addr;
    n_hit0 <= hit0;
    n_hit1 <= hit1;
    n_fhit0 <= fhit0;
    n_fhit1 <= fhit1;
    client_rd_ack = 0;

    if (client_waiting)
      // We have read the RAMs, check that the line is valid and is for the correct address
      if (cache_ready && tag0_ram_rd_data[TAG_SIZE] && tag0_ram_rd_data[TAG_SIZE - 1:0] == client_hold_addr[LOG_SIZE_MEM - 1:LOG_LINES + LOG_LINESIZE])
        begin
          n_hit0 <= hit0 + 1'd1;
          n_rd_way = 0;
          client_rd_ack = 1;
          n_client_waiting = 0;
        end
      else if (cache_ready && tag1_ram_rd_data[TAG_SIZE] && tag1_ram_rd_data[TAG_SIZE - 1:0] == client_hold_addr[LOG_SIZE_MEM - 1:LOG_LINES + LOG_LINESIZE])
        begin
          n_hit1 <= hit1 + 1'd1;
          n_rd_way = 1;
          client_rd_ack = 1;
          n_client_waiting = 0;
        end
      // Handle partially full cache line- this happens when cache line is currently being loaded
      else if (cache_ready && working_line_d == client_hold_addr[LOG_SIZE_MEM - 1:LOG_LINESIZE] && (working_high_d - working_low_d) > (client_hold_addr[LOG_LINESIZE-1:2] - working_low_d))
        begin
          if (wr_way)
            n_fhit1 <= fhit1 + 1'd1;
          else
            n_fhit0 <= fhit0 + 1'd1;
          n_rd_way = wr_way;
          client_rd_ack = 1;
          n_client_waiting = 0;
        end

    // Register a new request- it can happen same cycle that previous request as acknowledged
    // Feed address right to cache ram and tag ram
    if (client_rd_req)
      begin
        n_tag_ram_rd_addr = client_addr[LOG_LINESIZE + LOG_LINES - 1:LOG_LINESIZE];
        n_cache_ram_rd_addr = client_addr[LOG_LINESIZE + LOG_LINES - 1:2];
        n_client_hold_addr = client_addr;
        n_client_waiting = 1;
      end
  end

// Flash side state machine

reg [2:0] state, n_state;

parameter
  RESET = 0,
  IDLE = 1,
  FILL = 2,
  PAUSE = 3;

reg [2:0] rand_way, n_rand_way;

reg [23:0] n_miss0;
reg [23:0] n_miss1;

// Fill monitor

reg [LOG_SIZE_FILL-1:0] fill_wr_addr, n_fill_wr_addr;
reg fill_we, n_fill_we;

ram_blk_dp #(.DATAWIDTH(LOG_SIZE_MEM), .ADDRWIDTH(LOG_SIZE_FILL)) fill_ram
  (
  .clk (clk),
  .wr_data (client_hold_addr),
  .wr_addr (fill_wr_addr),
  .we (n_fill_we),
  .rd_data (fill_rd_data),
  .rd_addr (fill_rd_addr)
  );

always @(posedge clk)
  if (!reset_l)
    begin
      state <= RESET;
      tag_ram_wr_addr <= 0;
      tag_ram_wr_data <= 0;
      cache_ram_wr_addr <= 0;
      working_low <= 0;
      working_high <= 0;
      working_line <= 0;
      spimem_addr <= 0;
      spimem_valid <= 0;
      cache_ready <= 0;
      wr_way <= 0;
      rand_way <= 0;
      miss0 <= 0;
      miss1 <= 0;
      fill_wr_addr <= 0;
      fill_we <= 0;
    end
  else
    begin
      state <= n_state;
      tag_ram_wr_addr <= n_tag_ram_wr_addr;
      tag_ram_wr_data <= n_tag_ram_wr_data;
      cache_ram_wr_addr <= n_cache_ram_wr_addr;
      working_low <= n_working_low;
      working_high <= n_working_high;
      working_line <= n_working_line;
      spimem_addr <= n_spimem_addr;
      spimem_valid <= n_spimem_valid;
      cache_ready <= n_cache_ready;
      wr_way <= n_wr_way;
      rand_way <= n_rand_way;
      miss0 <= n_miss0;
      miss1 <= n_miss1;
      fill_wr_addr <= n_fill_wr_addr;
      fill_we <= n_fill_we;
    end

always @(*)
  begin
    n_state = state;
    n_tag_ram_wr_addr = tag_ram_wr_addr;
    n_tag_ram_wr_data = tag_ram_wr_data;
    n_tag0_ram_we = 0;
    n_tag1_ram_we = 0;
    n_cache_ram_wr_addr = cache_ram_wr_addr;
    n_cache0_ram_we = 0;
    n_cache1_ram_we = 0;
    n_working_low = working_low;
    n_working_high = working_high;
    n_working_line = working_line;
    n_spimem_addr = spimem_addr;
    n_spimem_valid = spimem_valid;
    n_cache_ready = cache_ready;
    n_wr_way = wr_way;
    n_rand_way = rand_way;
    n_miss0 = miss0;
    n_miss1 = miss1;
    n_fill_wr_addr = fill_wr_addr;
    n_fill_we = 0;

    case (state)
      RESET:
        begin
          n_tag0_ram_we = 1;
          n_tag1_ram_we = 1;
          n_tag_ram_wr_addr = tag_ram_wr_addr + 1'd1;
          if (tag_ram_wr_addr + 1'd1 == 6'd0)
            begin
              n_state = IDLE;
              n_cache_ready = 1;
            end
        end

      IDLE:
        if (client_waiting && (!tag0_ram_rd_data[TAG_SIZE] || tag0_ram_rd_data[TAG_SIZE - 1:0] != client_hold_addr[LOG_SIZE_MEM - 1:LOG_LINES + LOG_LINESIZE])
                           && (!tag1_ram_rd_data[TAG_SIZE] || tag1_ram_rd_data[TAG_SIZE - 1:0] != client_hold_addr[LOG_SIZE_MEM - 1:LOG_LINES + LOG_LINESIZE]))
          begin
            // Choose way to fill
            if (!tag0_ram_rd_data[TAG_SIZE])
              n_wr_way = 0;
            else if (!tag1_ram_rd_data[TAG_SIZE])
              n_wr_way = 1;
            else
              begin
                n_wr_way = !prev_way;
              end

            if (n_wr_way)
              n_miss1 = miss1 + 1'd1;
            else
              n_miss0 = miss0 + 1'd1;

            // Line is invalid or has data for another address
            // So we need to fill this line...
            n_working_line = client_hold_addr[LOG_SIZE_MEM - 1:LOG_LINESIZE];
            n_working_low = client_hold_addr[LOG_LINESIZE-1:2];
            n_working_high = client_hold_addr[LOG_LINESIZE-1:2];
            n_spimem_addr = client_hold_addr[LOG_SIZE_MEM-1:0]; // Starting address to read
            n_spimem_valid = 1;
            n_tag_ram_wr_addr = client_hold_addr[LOG_LINESIZE + LOG_LINES - 1:LOG_LINESIZE];
            n_tag_ram_wr_data = { 1'b0, client_hold_addr[LOG_SIZE_MEM - 1:LOG_LINESIZE + LOG_LINES] };
            n_cache_ram_wr_addr = client_hold_addr[LOG_LINESIZE + LOG_LINES - 1:2];
            n_state = FILL;
            n_fill_we = 1;
            n_fill_wr_addr = fill_wr_addr + 1'd1;
          end

      FILL:
        if (spimem_ready)
          begin
            if (wr_way)
              begin
                n_cache1_ram_we = 1;
                n_tag1_ram_we = 1; // Mark incompletely filled line as invalid
              end
            else
              begin
                n_cache0_ram_we = 1;
                n_tag0_ram_we = 1; // Mark incompletely filled line as invalid
              end
            n_cache_ram_wr_addr[LOG_LINESIZE - 3:0] = cache_ram_wr_addr[LOG_LINESIZE-3:0] + 1'd1;
            n_working_high = working_high + 1'd1;
            n_spimem_addr[LOG_LINESIZE-1:0] = spimem_addr[LOG_LINESIZE-1:0] + 3'd4;
            if (working_high + 1'd1 == working_low)
              begin
                n_state = PAUSE;
                n_spimem_valid = 0;
                n_tag_ram_wr_data[TAG_SIZE] = 1; // Line is now valid
                // Get spi flash to start prereading next line..
                n_spimem_addr[LOG_LINESIZE-1:0] = 0;
                n_spimem_addr[LOG_SIZE_MEM-1:LOG_LINESIZE] = spimem_addr[LOG_SIZE_MEM-1:LOG_LINESIZE] + 1'd1;
              end
          end

      PAUSE: // Allow time for valid to propagate through tag RAM otherwise we trigger a fill on the same row
        n_state = IDLE;
    endcase
  end

endmodule
