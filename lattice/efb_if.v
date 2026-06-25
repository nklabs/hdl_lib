// Provide non-wishbone access to flash interface part of Lattice embedded
// function block

// 1. Issue a command on cmd_data and set cmd_valid
//      cmd_len has length of command: 1 - 4 bytes
//      cmd_wr_len has number of data bytes to write following the command
//      cmd_resp_len has response length in bytes: 0 - 4 bytes
//      cmd_rd_len has number of data bytes to read after command
// 2. Wait for cmd_ack, immediately clear cmd_valid
//
// You can have response data or read data, but not both (so one of
// cmd_resp_len and cmd_rd_len must be 0).
//
// The state machine here will frame each command: set CFGCR.WBCE before
// each command and clear it after each command.
//
// FIFO interfaces are provided for the data bytes (cmd_wr_len and cmd_rd_len).

// Some commands:
//   3c 00 00 00 -> xx xx xx xx       Read status
//   26 00 00                         Disable interface
//   FF FF FF FF                      Bypass
//   74 08 00 00                      Enable interface
//   46 00 00 00                      Set address to 0
//   B4 00 00 00 40 00 00 01          Set address
//
//   CA 10 00 01 -> 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f   Read a page
//
//   CA 10 00 03 -> xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx
//                  00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f
//                  10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f   Read two pages
//
//   E0 00 00 00 -> xx xx xx xx       Read device ID code

module efb_if
  (
  input clk,
  input reset_l,

  input [31:0] cmd_data, // 1 - 4 bytes of command data (first byte at [31:24])
  input [2:0] cmd_len, // Length of command in bytes
  input [3:0] cmd_resp_len, // Length of response: 0, 1 or 4
  input [5:0] cmd_wr_len, // Number write bytes to transfer from write data fifo
  input [5:0] cmd_rd_len, // Number of read bytes to transfer to read data fifo

  input cmd_valid, // Command available
  output reg cmd_ack, // Pulsed when command complete

  output reg [31:0] cmd_resp, // 0 - 4 bytes of response (last byte always at [7:0])

  // Interface to write data FIFO
  input [7:0] wr_fifo_rd_data,
  output reg wr_fifo_re,

  // Interface to read data FIFO
  output reg [7:0] rd_fifo_wr_data,
  output reg rd_fifo_we
  );

// Lattice embedded function block

parameter
  CFGCR = 8'h70, // Read/write
  CFGTXDR = 8'h71, // Write
  CFGSR = 8'h72, // Read
  CFGRXDR = 8'h73, // Read
  CFGIRQ = 8'h74, // Read/write
  CFGIRQEN = 8'h75; // Read/write

reg wb_reset;
reg wb_strobe;
reg wb_we;
reg [7:0] wb_addr;
reg [7:0] wb_wr_data;
wire [7:0] wb_rd_data;
wire wb_ack;

efb efb
  (
  .wb_clk_i (clk),
  .wb_rst_i (wb_rst_i[0]), // Synchronous reset
  .wb_cyc_i (wb_strobe),
  .wb_stb_i (wb_strobe),
  .wb_we_i (wb_we),
  .wb_adr_i (wb_addr),
  .wb_dat_i (wb_wr_data),
  .wb_dat_o (wb_rd_data),
  .wb_ack_o (wb_ack)
  );

parameter
  RESET = 0,
  IDLE = 1,
  WR_CMD = 2,
  WR_DATA = 4,
  RD_RESP = 5,
  RD_DATA = 6,
  CLOSE = 7;

reg [3:0] state;
reg [5:0] count;

// 80 -> 70 before each command
// 00 -> 70 after each command

reg [7:0] wb_data;

always @(posedge clk or negedge reset_l)
  if (!reset_l)
    begin
      state <= RESET;
      wb_reset <= 1;
      wb_strobe <= 0;
      wb_we <= 0;
      wb_addr <= 0;
      wb_wr_data <= 0;
      count <= 10;
      wb_data <= 0;

      cmd_ack <= 0;
      cmd_resp <= 0;

      wr_fifo_re <= 0;
      rd_fifo_we <= 0;
      rd_fifo_wr_data <= 0;
    end
  else
    begin
      wr_fifo_re <= 0;
      rd_fifo_we <= 0;
      cmd_ack <= 0;

      if (wb_ack)
        begin
          wb_strobe <= 0;
          wb_data <= wb_rd_data;
        end

      if (!wb_strobe) // Pause if wishbone is busy
        case (state)
          RESET: // Reset wishbone interface
            if (!count)
              begin
                state <= IDLE;
                wb_reset <= 0;
              end
            else
              count <= count - 1'd1;

          IDLE:
            if (cmd_valid && !cmd_ack)
              begin // Start command
                wb_wr_data <= 8'h80;
                wb_addr <= CFGCR;
                wb_we <= 1;
                wb_strobe <= 1;
                state <= WR_CMD;
                count <= cmd_len;
                cmd_resp <= cmd_data;
              end

          WR_CMD: // Write command
            if (count)
              begin
                count <= count - 1'd1;
                cmd_resp <= { cmd_resp[23:0], 8'd0 };
                wb_wr_data <= cmd_resp[31:24];
                wb_addr <= CFGTXDR;
                wb_we <= 1;
                wb_strobe <= 1;
              end
            else
              begin
                count <= cmd_wr_len;
                state <= WR_DATA;
              end

          WR_DATA: // Write data
            if (count)
              begin
                count <= count - 1'd1;
                wb_wr_data <= wr_fifo_rd_data;
                wr_fifo_re <= 1;
                wb_addr <= CFGTXDR;
                wb_we <= 1;
                wb_strobe <= 1;
              end
            else if (cmd_resp_len)
              begin
                count <= cmd_resp_len;
                wb_we <= 0;
                wb_strobe <= 1;
                wb_addr <= CFGRXDR;
                count <= count - 1'd1;
                state <= RD_RESP;
              end
            else if (cmd_rd_len)
              begin
                count <= cmd_rd_len;
                wb_we <= 0;
                wb_strobe <= 1;
                wb_addr <= CFGRXDR;
                count <= count - 1'd1;
                state <= RD_DATA;
              end
            else
              state <= CLOSE;

          RD_RESP: // Read response
            begin
              cmd_resp <= { cmd_resp[23:0], wb_data };
              if (count != 1)
                begin
                  wb_we <= 0;
                  wb_strobe <= 1;
                  wb_addr <= CFGRXDR;
                  count <= count - 1'd1;
                  state <= RD_RESP;
                end
              else
                state <= CLOSE;
            end

          RD_DATA: // Read data
            begin
              rd_fifo_wr_data <= wb_data;
              rd_fifo_we <= 1;
              if (count != 1)
                begin
                  wb_we <= 0;
                  wb_strobe <= 1;
                  wb_addr <= CFGRXDR;
                  count <= count - 1'd1;
                  state <= RD_DATA;
                end
              else
                state <= CLOSE;
            end

          CLOSE:
            begin // Terminate command
              wb_wr_data <= 8'h00;
              wb_addr <= CFGCR;
              wb_we <= 1;
              wb_stobe <= 1;
              state <= IDLE;
              cmd_ack <= 1;
            end
        endcase
    end

endmodule
