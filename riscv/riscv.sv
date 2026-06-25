// RISCV CPU Complex

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

module riscv
import bus::*;
import regs_vev::*;
#(
  parameter CPU_FREQ = 25000000
) (
  input cpu_clk,
  input bus_clk,
  input reset_l,

  input uart_rx,
  output uart_tx,

  input brx,
  output btx,

  output wire flash_clk,
  output flash_cs_l,

  input flash_di0,
  input flash_di1,
  input flash_di2,
  input flash_di3,

  output flash_do0,
  output flash_do1,
  output flash_do2,
  output flash_do3,

  output flash_oe0,
  output flash_oe1,
  output flash_oe2,
  output flash_oe3,

  output [31:0] led_reg_out,

  output bus_in_s bus_in,
  input bus_out_s bus_out,

  input net_irq
  );

// Local bus

bus_in_s cpu_bus_in; // Combined bus
bus_out_s cpu_bus_out;

assign cpu_bus_in.reset_l = reset_l;
assign cpu_bus_in.clk = cpu_clk;

// CPU signals

wire [31:0] mem_wdata;
wire [3:0] mem_be;
wire [31:0] mem_addr;
wire extra_uart_irq;
wire uart_irq;
wire [31:0] irq = { 26'd0, extra_uart_irq, net_irq, uart_irq, 3'd0 };

wire [31:0] mem_rdata;
wire mem_read;
wire mem_write;
wire mem_ready;

assign cpu_bus_in.be = mem_be;
assign cpu_bus_in.wr_addr = mem_addr;
assign cpu_bus_in.rd_addr = mem_addr;
assign cpu_bus_in.wr_data = mem_wdata;
assign cpu_bus_in.re = mem_read;
assign cpu_bus_in.we = mem_write;

assign mem_rdata = cpu_bus_out.rd_data;
assign mem_ready = cpu_bus_out.wr_ack | cpu_bus_out.rd_ack;

// RISC-V CPU

picorv32 #(
  .STACKADDR (32'h0001_0000), // End of RAM, initial SP value
  .PROGADDR_RESET (32'h0010_0000), // Start of ROM, initial PC value
  .PROGADDR_IRQ (32'h0010_0010),
  .BARREL_SHIFTER (1),
  .COMPRESSED_ISA (1),
  .ENABLE_COUNTERS (1),
  .ENABLE_MUL (1),
  .ENABLE_DIV (1),
  .ENABLE_IRQ (1),
  .ENABLE_IRQ_QREGS (0),
  .LATCHED_IRQ (32'hffff_ffe7) // NET IRQ and UART IRQ are level sensitive
) cpu
  (
  .clk (cpu_clk),
  .resetn (reset_l),

  .trap (),

  .mem_ready (mem_ready),
  .mem_rdata (mem_rdata),

  .mem_valid (),
  .mem_instr (),
  .mem_addr (),
  .mem_wdata (),
  .mem_wstrb (),

  .mem_la_read (mem_read),
  .mem_la_write (mem_write),
  .mem_la_addr (mem_addr),
  .mem_la_wdata (mem_wdata),
  .mem_la_wstrb (mem_be),

  .irq (irq),
  .eoi (),

  .pcpi_valid (),
  .pcpi_insn (),
  .pcpi_rs1 (),
  .pcpi_rs2 (),
  .pcpi_wr (1'd0),
  .pcpi_rd (32'd0),
  .pcpi_wait (1'd0),
  .pcpi_ready (1'd0),

  .trace_valid (),
  .trace_data ()
  );

// Software's RAM

bus_out_s cpu_ram_bus_out;

bus_ram #(.BUS_ADDR(BUS_RAM_ADDR), .LOGSIZE(RAM_LOGSIZE)) cpu_ram
  (
  .bus_in (cpu_bus_in),
  .bus_out (cpu_ram_bus_out)
  );

// Software access to SPI Flash

bus_out_s cpu_rom_bus_out;

`ifdef junk
// Note that path for INIT_FILE is relative to diamond implementation directory.
bus_rom #(.BUS_ADDR(BUS_ROM_ADDR), .LOGSIZE(16), .INIT_FILE("../../fw/tof.mem")) cpu_rom
  (
  .bus_in (cpu_bus_in),
  .bus_out (cpu_rom_bus_out)
  );
`endif

reg mclk_oe;
reg mclk_oe_1;

// Lattice way of accessing spi_sclk pin
// USRMCLK u1 (.USRMCLKI(flash_clk), .USRMCLKTS(mclk_oe)) /* synthesis syn_noprune=1 */;
wire flash_clk_i;
assign flash_clk = mclk_oe ? 1'bz : flash_clk_i;

always @(posedge cpu_clk)
  if (!reset_l)
    begin
      mclk_oe_1 <= 1;
      mclk_oe <= 1;
    end
  else
    begin
      mclk_oe_1 <= 0;
      mclk_oe <= mclk_oe_1;
    end

wire [23:0] miss0;
wire [23:0] miss1;
wire [23:0] hit0;
wire [23:0] hit1;
wire [23:0] fhit0;
wire [23:0] fhit1;

wire [23:0] fill_rd_data;
wire [9:0] fill_rd_addr;

bus_spiflash #(
  .BUS_ADDR_MEM(SPIFLASH_ADDR),
  .SIZE_MEM(SPIFLASH_SIZE),
  .BUS_ADDR_CFG(SPIFLASH_CFG_REG),
  .BANK0_OFFSET(SPIFLASH_BANK0_OFFSET),
  .BANK1_OFFSET(SPIFLASH_BANK1_OFFSET)
) cpu_rom (
  .bus_in (cpu_bus_in),
  .bus_out (cpu_rom_bus_out),

  .flash_cs_l (flash_cs_l),
  .flash_clk (flash_clk_i),

  .flash_io0_oe (flash_oe0),
  .flash_io1_oe (flash_oe1),
  .flash_io2_oe (flash_oe2),
  .flash_io3_oe (flash_oe3),

  .flash_io0_do (flash_do0),
  .flash_io1_do (flash_do1),
  .flash_io2_do (flash_do2),
  .flash_io3_do (flash_do3),

  .flash_io0_di (flash_di0),
  .flash_io1_di (flash_di1),
  .flash_io2_di (flash_di2),
  .flash_io3_di (flash_di3),

  .miss0 (miss0),
  .miss1 (miss1),
  .hit0 (hit0),
  .hit1 (hit1),
  .fhit0 (fhit0),
  .fhit1 (fhit1),

  .fill_rd_data (fill_rd_data),
  .fill_rd_addr (fill_rd_addr)
  );

// UART

bus_out_s uart_bus_out;

bus_uart #(.BUS_ADDR(UART_ADDR), .CPU_FREQ(CPU_FREQ)) uart
  (
  .bus_in (cpu_bus_in),
  .bus_out (uart_bus_out),
  .ser_tx (uart_tx),
  .ser_rx (uart_rx),
  .recv_buf_valid (uart_irq)
  );

// Software controllable LEDs register

bus_out_s led_reg_bus_out;

bus_reg #(.ADDR(LED_REG_ADDR)) led_reg
  (
  .bus_in (cpu_bus_in),
  .bus_out (led_reg_bus_out),

  .out (led_reg_out),
  .wr_pulse ()
  );

// Software access to CPU_FREQ

bus_out_s cpu_reg_10_bus_out;

bus_ro_reg #(.ADDR(CPU_FREQ_REG_ADDR)) cpu_reg_10
  (
  .bus_in (cpu_bus_in),
  .bus_out (cpu_reg_10_bus_out),

  .in (CPU_FREQ),
  .rd_pulse ()
  );

// Free running timer

reg [31:0] wallclock;

always @(posedge cpu_clk)
  if (!reset_l)
    wallclock <= 0;
  else
    wallclock <= wallclock + 1'd1;

bus_out_s cpu_reg_14_bus_out;

bus_ro_reg #(.ADDR(WALLCLOCK_ADDR)) cpu_reg_14
  (
  .bus_in (cpu_bus_in),
  .bus_out (cpu_reg_14_bus_out),

  .in (wallclock),
  .rd_pulse ()
  );

// Extra UART

bus_out_s extra_uart_bus_out;

bus_uart #(.BUS_ADDR(EXTRA_UART_ADDR), .CPU_FREQ(CPU_FREQ)) extra_uart
  (
  .bus_in (cpu_bus_in),
  .bus_out (extra_uart_bus_out),
  .ser_tx (btx),
  .ser_rx (brx),
  .recv_buf_valid (extra_uart_irq)
  );

// Bridge to peripheral bus

bus_out_s peripheral_bus_out;

bus_window_async #(.BUS_ADDR(PERIPH_BASE_ADDR), .ADDRWIDTH(PERIPH_LOGSIZE)) peripheral_bus_bridge
  (
  .sub_clk (bus_clk),
  .sub_reset_l (reset_l),

  .bus_in (cpu_bus_in),
  .bus_out (peripheral_bus_out),

  .sub_bus_in (bus_in),
  .sub_bus_out (bus_out)
  );

// Cache stats

bus_out_s hit0_bus_out;

bus_ro_reg #(.ADDR(HIT0_ADDR), .DATAWIDTH(24)) hit0_reg
  (
  .bus_in (cpu_bus_in),
  .bus_out (hit0_bus_out),
  .in (hit0),
  .rd_pulse ()
  );

bus_out_s hit1_bus_out;

bus_ro_reg #(.ADDR(HIT1_ADDR), .DATAWIDTH(24)) hit1_reg
  (
  .bus_in (cpu_bus_in),
  .bus_out (hit1_bus_out),
  .in (hit1),
  .rd_pulse ()
  );

bus_out_s fhit0_bus_out;

bus_ro_reg #(.ADDR(FHIT0_ADDR), .DATAWIDTH(24)) fhit0_reg
  (
  .bus_in (cpu_bus_in),
  .bus_out (fhit0_bus_out),
  .in (fhit0),
  .rd_pulse ()
  );

bus_out_s fhit1_bus_out;

bus_ro_reg #(.ADDR(FHIT1_ADDR), .DATAWIDTH(24)) fhit1_reg
  (
  .bus_in (cpu_bus_in),
  .bus_out (fhit1_bus_out),
  .in (fhit1),
  .rd_pulse ()
  );

bus_out_s miss0_bus_out;

bus_ro_reg #(.ADDR(MISS0_ADDR), .DATAWIDTH(24)) miss0_reg
  (
  .bus_in (cpu_bus_in),
  .bus_out (miss0_bus_out),
  .in (miss0),
  .rd_pulse ()
  );

bus_out_s miss1_bus_out;

bus_ro_reg #(.ADDR(MISS1_ADDR), .DATAWIDTH(24)) miss1_reg
  (
  .bus_in (cpu_bus_in),
  .bus_out (miss1_bus_out),
  .in (miss1),
  .rd_pulse ()
  );

bus_out_s fill_rd_bus_out;

wire [23:0] fill_out;

assign fill_rd_addr = fill_out[9:0];

bus_split_reg #(.ADDR(FILL_ADDR), .DATAWIDTH(24)) fill_reg
  (
  .bus_in (cpu_bus_in),
  .bus_out (fill_rd_bus_out),
  .in (fill_rd_data),
  .out (fill_out),
  .rd_pulse (),
  .wr_pulse ()
  );

assign cpu_bus_out =
  cpu_ram_bus_out |
  cpu_rom_bus_out |
  uart_bus_out |
  led_reg_bus_out |
  cpu_reg_10_bus_out |
  cpu_reg_14_bus_out |
  peripheral_bus_out |
  extra_uart_bus_out |
  hit0_bus_out |
  fhit0_bus_out |
  hit1_bus_out |
  fhit1_bus_out |
  miss0_bus_out |
  miss1_bus_out |
  fill_rd_bus_out
  ;

endmodule
