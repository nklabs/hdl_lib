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


// IP Hierarchy:
// -------------
// uart_top
// - uart_rx
// -- uart_fifo
// - uart_tx
// -- uart_fifo


// UART message format:
//    Read message:   rd <addr in hex, no leading "0x">
//    Write message   wr <addr in hex> <data in hex>


// IP Description: UART CLI for access to the CSR registers without RISC-V core.
// 115200 Baud, 8N1

// Note: Make sure to set the CLKS_PER_BIT parameter. IP will not function 
// if set incorrectly. Its value can be solved with the follwoing equation: 

// CLKS_PER_BIT = (Clock Frequency) / 115200



// `define ECHO_ONLY
module uart_top #(parameter CLKS_PER_BIT = 977) //977 for 112.5MHz
  (
  input clk, 
  input reset_l,

  // UART
  input rx,
  output tx,

  output reg new_csr = 0,

  output reg [7:0] debug_out,
  //input [1:0] sws, //sw1 4 and 5

  // csr access
  output reg [15:0] bus_orig_addr,
  output reg [31:0] bus_orig_wr_data,
  output reg bus_orig_we = 0,
  input [31:0] bus_orig_rd_data,
  output reg bus_orig_re = 0
  );

// speed up uart signal for simulation
// `ifdef SYNTHESIS
//   parameter CLKS_PER_BIT = 286; //33MHz sample clk, 115200 baud
// `else
//   parameter CLKS_PER_BIT = 16;
// `endif

//parameter CLKS_PER_BIT = 286; //33MHz sample clk, 115200 baud

reg mux_sel = 1; // 1: echo, 0: response

wire [7:0] rx_data;
wire [7:0] tx_data;
wire rx_pulse;
reg tx_en;
reg tx_en_r;

wire tx_busy;

wire echo_empty;

wire new_msg_pulse;

// echo fifo signals
reg [7:0] echo_fifo_wr_data;
reg echo_fifo_wr_en = 0;


// msg fifo signals
wire [7:0] msg_fifo_wr_data;
wire msg_fifo_wr_en;

wire [7:0] msg_fifo_rd_data;
reg msg_fifo_rd_en = 0;
wire msg_fifo_empty;


reg [7:0] rx_state;
reg [7:0] tx_state;

uart_rx  #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_rx (
  .clk(clk),
  .reset_l(reset_l),
  .rx(rx),
  .data_out(rx_data),
  .rx_pulse(rx_pulse),

  .msg_fifo_we(msg_fifo_wr_en),
  .msg_fifo_data(msg_fifo_wr_data),
  .new_msg_pulse(new_msg_pulse),

  .debug_state(rx_state)
);


uart_tx  #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_tx (
  .clk(clk),
  .reset_l(reset_l),
  .tx(tx),
  .busy(tx_busy),
  .data_in(tx_data),
  .tx_en(tx_en),

  .debug_state(tx_state)
);

reg [7:0] resp_data;
reg resp_wr_en = 0;



`ifdef ECHO_ONLY

  always @(posedge clk) begin
    echo_fifo_wr_data <= rx_data;
    echo_fifo_wr_en <= rx_pulse;
  end

`else

  always @(posedge clk) begin
    if (mux_sel) begin
      echo_fifo_wr_data <= rx_data;
      echo_fifo_wr_en <= rx_pulse;
    end
    else begin
      echo_fifo_wr_data <= resp_data;
      echo_fifo_wr_en <= resp_wr_en;
    end
  end

`endif




uart_fifo  echo_fifo (
  .clk(clk),
  .reset_l(reset_l),

  .wr_en(echo_fifo_wr_en),
  .wr_data(echo_fifo_wr_data),
  .full(),

  .rd_en(tx_en && !tx_en_r),
  .rd_data(tx_data),
  .empty(echo_empty)
);

uart_fifo  msg_fifo (
  .clk(clk),
  .reset_l(reset_l),

  .wr_en(msg_fifo_wr_en),
  .wr_data(msg_fifo_wr_data),
  .full(),

  .rd_en(msg_fifo_rd_en),
  .rd_data(msg_fifo_rd_data),
  .empty(msg_fifo_empty)
);

always @(posedge clk) begin
  tx_en_r <= tx_en;
  if (!echo_empty & !tx_busy)
    tx_en <= 1;
  else
    tx_en <= 0;
end



function [3:0] a2hex_byte;
  input [7:0] ascii;
  begin
    if (ascii >= 8'h30 && ascii <= 8'h39) // 0-9
      return (ascii - 8'h30);
    else if (ascii >= 8'h41 && ascii <= 8'h46) // A-F
      return (ascii - 8'h41 + 8'h0a);
    else if (ascii >= 8'h61 && ascii <= 8'h66) // a-f
      return (ascii - 8'h61 + 8'h0a);
    else
      return 4'h00;
  end
endfunction

function [31:0] a2hex;
  input [63:0] ascii;
  begin
    return {
      a2hex_byte(ascii[63:56]),
      a2hex_byte(ascii[55:48]),
      a2hex_byte(ascii[47:40]),
      a2hex_byte(ascii[39:32]),
      a2hex_byte(ascii[31:24]),
      a2hex_byte(ascii[23:16]),
      a2hex_byte(ascii[15:8]),
      a2hex_byte(ascii[7:0])
    };
  end
endfunction

function [7:0] hex2a_byte;
  input [3:0] hex;
  begin
    if (hex < 4'ha)
      return {4'h0, hex} + 8'h30; // 0-9
    else if (hex >= 4'ha)
      return {4'h0, hex} + 8'h57; // a-f
  end
endfunction

function [63:0] hex2a;
  input [31:0] hex;
  begin
    return {
      hex2a_byte(hex[31:28]),
      hex2a_byte(hex[27:24]),
      hex2a_byte(hex[23:20]),
      hex2a_byte(hex[19:16]),
      hex2a_byte(hex[15:12]),
      hex2a_byte(hex[11:8]),
      hex2a_byte(hex[7:4]),
      hex2a_byte(hex[3:0])
    };
  end
endfunction


reg [63:0] ascii_header = 0;
reg [31:0] ascii_addr = 0;
reg [63:0] ascii_data = 0;


reg new_data = 0; //flag for when new data is provided to check for valid wr or rd

parameter RD_RESP_0 = 56'h52656164203078;   //"Read 0x"
parameter RD_RESP_1 = 64'h2066726f6d203078; //" from 0x"

parameter WR_RESP_0 = 64'h57726f7465203078; //"Wrote 0x"
parameter WR_RESP_1 = 48'h20746f203078;     //" to 0x"

// "Error: Invalid command    "
parameter ER_RESP = 216'h4572726f723a20496e76616c696420636f6d6d616e642020202020;



enum {
  IDLE = 0,
  GET_HEADER = 1,
  GET_ADDR = 2,
  GET_DATA = 3,
  PROCESS_HEADER = 4,
  CSR_RD = 5,
  BUILD_RD_RESP = 6,
  CSR_WR = 7,
  BUILD_WR_RESP = 8,
  BUILD_ER_RESP = 9,
  RESPONSE = 10,
  CARRIAGE_RETURN = 11,
  LINE_FEED = 12,
  MSG_DONE = 13,
  TOGGLE_MUX = 14
} state = IDLE;

reg [215:0] resp_out;
reg [31:0] csr_rd_data;
reg [4:0] resp_byte_cnt = 0;

reg [215:0] resp_hold; 

reg [7:0] debug_state;

always @(posedge clk)
  if (!reset_l) begin
    state <= IDLE;
  end
  else begin
    case (state)
      IDLE: begin
        debug_state <= 0;
        new_csr <= 0; 
        mux_sel <= 1;
        new_data <= 0;
        resp_byte_cnt <= 0;
        if (new_msg_pulse) begin
          state <= GET_HEADER;
        end
      end


      GET_HEADER: begin
        debug_state[0] <= 1'b1; 
        if (msg_fifo_rd_en)
          msg_fifo_rd_en <= 0;

        if (msg_fifo_empty) begin
          mux_sel <= 0;
          state <= BUILD_ER_RESP;
        end

        else if (!msg_fifo_rd_en) begin
          msg_fifo_rd_en <= 1;
          if (msg_fifo_rd_data == 8'h20)
            state <= GET_ADDR;
          else
            ascii_header <= {ascii_header[55:0], msg_fifo_rd_data};
        end
      end

      GET_ADDR: begin
        debug_state[1] <= 1'b1; 
        if (msg_fifo_rd_en)
          msg_fifo_rd_en <= 0;

        // if (msg_fifo_empty) begin
        //   mux_sel <= 0;
        //   state <= BUILD_ER_RESP;
        // end

        else if (!msg_fifo_rd_en) begin
          msg_fifo_rd_en <= 1;
          if (msg_fifo_rd_data == 8'h20)
            if (ascii_header[15:0] == 16'h7264)
              state <= TOGGLE_MUX;
              //state <= PROCESS_HEADER;
            else
              state <= GET_DATA;
          else if (msg_fifo_rd_data == 8'h0d)
            state <= TOGGLE_MUX;
            //state <= PROCESS_HEADER;
          else
            ascii_addr <= {ascii_addr[23:0], msg_fifo_rd_data};
        end
      end

      GET_DATA: begin
        new_data <= 1;

        if (msg_fifo_rd_en)
          msg_fifo_rd_en <= 0;

        if (msg_fifo_empty) begin
          mux_sel <= 0;
          //state <= PROCESS_HEADER; //ER_RESPONSE;
          state <= TOGGLE_MUX;
        end

        else if (!msg_fifo_rd_en) begin
          msg_fifo_rd_en <= 1;
          if (msg_fifo_rd_data == 8'h20 || msg_fifo_rd_data == 8'h0d)
            state <= TOGGLE_MUX;  
            //state <= PROCESS_HEADER;
          else
            ascii_data <= {ascii_data[55:0], msg_fifo_rd_data};
        end
      end

      TOGGLE_MUX: begin 
        debug_state[2] <= 1'b1; 
        if (msg_fifo_rd_en)
          msg_fifo_rd_en <= 0;
        new_csr <= 1;
        bus_orig_addr <= a2hex({32'h00000000, ascii_addr});
        bus_orig_re <= 1 && !new_data;
        state <= PROCESS_HEADER;
      end 


      PROCESS_HEADER: begin
        debug_state[3] <= 1'b1; 
        //new_csr <= 1; 

        if (msg_fifo_rd_en)
          msg_fifo_rd_en <= 0;

        mux_sel <= 0;
        if (ascii_header[15:0] == 16'h7264 && !new_data) begin // ASCII "rd"
          //state <= RD_RESPONSE;
          state <= CSR_RD;
        end
        else if (ascii_header[15:0] == 16'h7772 && new_data) begin // ASCII "wr"
          new_data <= 0;
          state <= CSR_WR;
        end
        else begin
          state <= BUILD_ER_RESP;
        end
      end


      CSR_RD: begin
        debug_state[4] <= 1'b1; 
        csr_rd_data <= bus_orig_rd_data;
        //csr_rd_data <= 32'habcd1234;
        //bus_orig_re <= 1;
        state <= BUILD_RD_RESP;
      end

      BUILD_RD_RESP: begin
        debug_state[5] <= 1'b1; 
        bus_orig_re <= 0;
        resp_out <= {RD_RESP_0, hex2a(csr_rd_data), RD_RESP_1, ascii_addr};
        resp_hold <= {RD_RESP_0, hex2a(csr_rd_data), RD_RESP_1, ascii_addr};
        state <= RESPONSE;
      end


      CSR_WR: begin
        //bus_orig_addr <= a2hex({32'h00000000, ascii_addr});
        bus_orig_wr_data <= a2hex(ascii_data);
        bus_orig_we <= 1;
        state <= BUILD_WR_RESP;
      end

      BUILD_WR_RESP: begin
        bus_orig_we <= 0;
        resp_out <= {WR_RESP_0, ascii_data, WR_RESP_1, ascii_addr, 8'h20};
        resp_hold <= {WR_RESP_0, ascii_data, WR_RESP_1, ascii_addr, 8'h20};
        state <= RESPONSE;
      end


      BUILD_ER_RESP: begin
        resp_out <= ER_RESP;
        resp_hold <= ER_RESP;
        state <= RESPONSE;
      end


      RESPONSE: begin
        debug_state[6] <= 1'b1; 
        new_csr <= 0; 
        resp_wr_en <= 1;
        if (resp_byte_cnt == 27) begin
          resp_byte_cnt <= 0;
          resp_wr_en <= 0;
          state <= CARRIAGE_RETURN;
        end
        else begin
          resp_data <= resp_out[215:208];
          resp_out <= {resp_out[207:0], 8'h00}; //shift into fifo
          resp_byte_cnt <= resp_byte_cnt + 1;
        end
      end


      CARRIAGE_RETURN: begin
        resp_data <= 8'h0d;
        resp_wr_en <= 1;
        state <= LINE_FEED;
      end

      LINE_FEED: begin
        resp_data <= 8'h0a;
        resp_wr_en <= 1;
        state <= MSG_DONE;
      end

      MSG_DONE: begin
        debug_state[7] <= 1'b1; 
        ascii_header <= 0;
        ascii_addr <= 0;
        ascii_data <= 0;
        resp_wr_en <= 0;
        mux_sel <= 1; // back to echo mode
        state <= IDLE;
      end

    endcase
  end



assign debug_out = debug_state; 


endmodule