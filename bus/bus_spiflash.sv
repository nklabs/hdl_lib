// Bus accessible SPI Flash

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

module bus_spiflash
import bus::*;
#(
  parameter LOG_SIZE_FILL = 10,
  parameter BUS_ADDR_CFG = 0, // Config register I/O address
  parameter SIZE_CFG = 4,

  parameter BUS_ADDR_MEM = 32'h0010_0000, // Where memory is located on the bus
  parameter SIZE_MEM = 32'h0010_0000, // How much bus space allocated for the memory
  parameter BANK0_OFFSET = 32'h0060_0000, // Offset within flash to our memory
  parameter BANK1_OFFSET = 32'h00E0_0000 // Offset within flash to our memory
) (
  input bus_in_s bus_in,
  output bus_out_s bus_out,

  output flash_cs_l,
  output flash_clk,

  output flash_io0_oe,
  output flash_io1_oe,
  output flash_io2_oe,
  output flash_io3_oe,

  output flash_io0_do,
  output flash_io1_do,
  output flash_io2_do,
  output flash_io3_do,

  input flash_io0_di,
  input flash_io1_di,
  input flash_io2_di,
  input flash_io3_di,

  output [23:0] miss0,
  output [23:0] miss1,
  output [23:0] hit0,
  output [23:0] hit1,
  output [23:0] fhit0,
  output [23:0] fhit1,
  output [23:0] fill_rd_data,
  input [LOG_SIZE_FILL-1:0] fill_rd_addr
  );

wire spimem_ready; // High when flash data is available (high only when spimem_valid is high)
reg bank_read; // High if we are waiting to read the active bank
reg mem_read; // High if no longer waiting for active bank, so normal memory access is available
wire mem_ready = (spimem_ready && mem_read); // Gated spimem_ready for normal memory access
reg bank; // The bank that the firmware is located in

// Flash config register

wire decode_wr_cfg = ({ bus_in.wr_addr[BUS_ADDR_WIDTH-1:2], 2'd0 } == BUS_ADDR_CFG);
wire decode_rd_cfg = ({ bus_in.rd_addr[BUS_ADDR_WIDTH-1:2], 2'd0 } == BUS_ADDR_CFG);

wire decode_rd_mem = (bus_in.rd_addr >= BUS_ADDR_MEM && bus_in.rd_addr < (BUS_ADDR_MEM + SIZE_MEM));

wire mem_rd_req = decode_rd_mem && bus_in.re;

wire cfg_wr_ack = decode_wr_cfg && bus_in.we;
wire cfg_rd_ack = decode_rd_cfg && bus_in.re;
reg cfg_rd_ack_reg;
reg cfg_wr_ack_reg;

wire [3:0] cfgreg_we = (bus_in.be & { 4 { cfg_wr_ack } });
wire [31:0] cfgreg_do;

always @(posedge bus_in.clk)
  if (!bus_in.reset_l)
    begin
      cfg_rd_ack_reg <= 0;
      cfg_wr_ack_reg <= 0;
    end
  else
    begin
      cfg_rd_ack_reg <= cfg_rd_ack;
      cfg_wr_ack_reg <= cfg_wr_ack;
    end

wire [31:0] spimem_rdata;

`ifdef NOCACHE

reg [23:0] spimem_addr;
reg spimem_valid;

always @(posedge bus_clk)
  if (!bus_reset_l)
    begin
      spimem_valid <= 0;
      spimem_addr <= 0;
    end
  else
    begin
      spimem_valid <= mem_rd_req || (spimem_valid && !mem_ready);
      if (mem_rd_req)
        spimem_addr <= bus_in.rd_addr - BUS_ADDR_MEM + BANK0_OFFSET;
    end

assign bus_out.rd_data = mem_ready ? spimem_rdata : (cfg_rd_ack_reg ? cfgreg_do : 32'd0);
assign bus_out.rd_ack = cfg_rd_ack_reg | mem_ready;

`else

// A cache in front of spimemio

wire [23:0] spimem_addr;
wire spimem_valid;

wire mem_rd_ack;
wire [31:0] mem_rd_data;
wire [23:0] client_addr = bus_in.rd_addr - BUS_ADDR_MEM + BANK0_OFFSET;

icache icache
  (
  .reset_l (bus_in.reset_l),
  .clk (bus_in.clk),

  // CPU side
  .client_rd_req (mem_rd_req),
  .client_addr (client_addr),
  .client_rd_ack (mem_rd_ack),
  .client_rd_data (mem_rd_data),

  // Flash side
  .spimem_addr (spimem_addr), // Byte address
  .spimem_rdata (spimem_rdata),
  .spimem_ready (mem_ready),
  .spimem_valid (spimem_valid),

  .miss0 (miss0),
  .miss1 (miss1),
  .hit0 (hit0),
  .hit1 (hit1),
  .fhit0 (fhit0),
  .fhit1 (fhit1),

  .fill_rd_data (fill_rd_data),
  .fill_rd_addr (fill_rd_addr)
  );

assign bus_out.rd_data = mem_rd_ack ? mem_rd_data : (cfg_rd_ack_reg ? cfgreg_do : 32'd0);
assign bus_out.rd_ack = cfg_rd_ack_reg | mem_rd_ack;

`endif

assign bus_out.wr_ack = cfg_wr_ack_reg;
assign bus_out.irq = 0;

spimemio spimemio
  (
  .clk (bus_in.clk),
  .resetn (bus_in.reset_l),

  .valid (bank_read || spimem_valid),
  .ready (spimem_ready),
  .addr (bank_read ? 24'hFE0000 : ({ spimem_addr[23] ^ bank, spimem_addr[22:0] })),
  .rdata (spimem_rdata),

  .flash_csb (flash_cs_l),
  .flash_clk (flash_clk),

  .flash_io0_oe (flash_io0_oe),
  .flash_io1_oe (flash_io1_oe),
  .flash_io2_oe (flash_io2_oe),
  .flash_io3_oe (flash_io3_oe),

  .flash_io0_do (flash_io0_do),
  .flash_io1_do (flash_io1_do),
  .flash_io2_do (flash_io2_do),
  .flash_io3_do (flash_io3_do),

  .flash_io0_di (flash_io0_di),
  .flash_io1_di (flash_io1_di),
  .flash_io2_di (flash_io2_di),
  .flash_io3_di (flash_io3_di),

  .cfgreg_we (cfgreg_we),
  .cfgreg_di (bus_in.wr_data),
  .cfgreg_do (cfgreg_do),
  .bank (bank)
  );

// Read active bank

always @(posedge bus_in.clk)
  if (!bus_in.reset_l)
    begin
      bank <= 0;
      bank_read <= 1;
      mem_read <= 0;
    end
  else
    begin
      mem_read <= !bank_read;
      if (bank_read && spimem_ready)
        begin
          bank_read <= 0;
          bank <= spimem_rdata[0];
        end
    end

endmodule
