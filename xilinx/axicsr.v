// Simple AXI lite to CSR bus interface

module axicsr
  (
  // Register bus
  // Vivado not allowing system verilog here..

  bus_in_clk,
  bus_in_reset_l,
  bus_in_wr_addr,
  bus_in_rd_addr,
  bus_in_we,
  bus_in_re,
  bus_in_wr_data,

  bus_out_rd_data,
  bus_out_wr_ack,
  bus_out_rd_ack,

  s00_axi_aclk,
  s00_axi_aresetn,

  // Writes
  s00_axi_awaddr,
  s00_axi_awprot,
  s00_axi_awvalid,
  s00_axi_awready,
  s00_axi_wdata,
  s00_axi_wstrb,
  s00_axi_wvalid,
  s00_axi_wready,
  s00_axi_bresp,
  s00_axi_bvalid,
  s00_axi_bready,

  // Reads
  s00_axi_araddr,
  s00_axi_arprot,
  s00_axi_arvalid,
  s00_axi_arready,

  s00_axi_rdata,
  s00_axi_rresp,
  s00_axi_rvalid,
  s00_axi_rready
  );

parameter integer C_S00_AXI_DATA_WIDTH	= 32;
parameter integer C_S00_AXI_ADDR_WIDTH	= 10;

// Users to add ports here

output [31:0] bus_in_wr_data;
output [C_S00_AXI_ADDR_WIDTH-1:0] bus_in_wr_addr;
output [C_S00_AXI_ADDR_WIDTH-1:0] bus_in_rd_addr;
output bus_in_we;
output bus_in_re;
output bus_in_clk;
output bus_in_reset_l;

input [31:0] bus_out_rd_data;
input bus_out_wr_ack;
input bus_out_rd_ack;

// Ports of Axi Slave Bus Interface S00_AXI
input s00_axi_aclk;
input s00_axi_aresetn;
input [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr;
input [2 : 0] s00_axi_awprot;
input s00_axi_awvalid;

output s00_axi_awready;
reg s00_axi_awready;

input [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata;
input [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb;
input s00_axi_wvalid;

output s00_axi_wready;
reg s00_axi_wready;

output [1 : 0] s00_axi_bresp;
reg [1 : 0] s00_axi_bresp;

output s00_axi_bvalid;
reg  s00_axi_bvalid;

input s00_axi_bready;
input [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr;
input [2 : 0] s00_axi_arprot;
input s00_axi_arvalid;

output s00_axi_arready;
reg s00_axi_arready;

output [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata;
reg [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata;

output [1 : 0] s00_axi_rresp;
reg [1 : 0] s00_axi_rresp;

output s00_axi_rvalid;
reg s00_axi_rvalid;

input s00_axi_rready;

//

reg [31:0] wr_data;
reg [C_S00_AXI_ADDR_WIDTH-1:0] wr_addr;
reg [C_S00_AXI_ADDR_WIDTH-1:0] rd_addr;
reg wren;
reg rden;

assign bus_in_reset_l = s00_axi_aresetn;
assign bus_in_clk = s00_axi_aclk;
assign bus_in_we = wren;
assign bus_in_re = rden;
assign bus_in_wr_data = wr_data;
assign bus_in_rd_addr = rd_addr;
assign bus_in_wr_addr = wr_addr;

// Timeout if bus doesn't ack
parameter MAXTRANS = 2047;
reg [10:0] timeout;

always @(posedge s00_axi_aclk)
  if (!s00_axi_aresetn)
    begin
      wren <= 0;
      rden <= 0;
      wr_addr <= 0;
      rd_addr <= 0;
      wr_data <= 0;

      s00_axi_awready <= 1; // Can accept write address
      s00_axi_wready <= 1; // Can accept write data
      s00_axi_bresp <= 0; // Write response
      s00_axi_bvalid <= 0; // Write response valid

      s00_axi_arready <= 1; // Can accept read address
      s00_axi_rdata <= 0; // Read data
      s00_axi_rresp <= 0; // Read resonse
      s00_axi_rvalid <= 0; // Read data and response valid

      timeout <= 0;
    end
  else
    begin
      wren <= 0;
      rden <= 0;

      if (timeout)
        timeout <= timeout - 1'd1;

      // Handle writes

      if (s00_axi_awvalid && s00_axi_awready) // Latch write address
        begin
          wr_addr <= { s00_axi_awaddr[C_S00_AXI_ADDR_WIDTH-1:2], 2'd0 };
          s00_axi_awready <= 0; // Hold it until transaction complete
          if (!s00_axi_wready || (s00_axi_wvalid && s00_axi_wready)) // If we already have data or we get it this cycle, give write pulse
            begin
              wren <= 1;
              timeout <= MAXTRANS;
            end
        end

      if (s00_axi_wvalid && s00_axi_wready) // Latch write data
        begin
          wr_data <= s00_axi_wdata;
          s00_axi_wready <= 0; // Hold it until transaction complete
          if (!s00_axi_awready || (s00_axi_awvalid && s00_axi_awready)) // If we already have address or we get it this cycle, give write pulse
            begin
              wren <= 1;
              timeout <= MAXTRANS;
            end
        end

      if (bus_out_wr_ack || timeout == 1) // We got the ack: assert valid response
        begin
          s00_axi_bvalid <= 1;
          s00_axi_bresp <= 0; // Write response is always 0 for now
          timeout <= 0;
        end

      if (s00_axi_bvalid && s00_axi_bready) // Write response accepted, allow next
        begin
          s00_axi_bvalid <= 0;
          s00_axi_awready <= 1;
          s00_axi_wready <= 1;
        end

      // Handle reads

      if (s00_axi_arvalid && s00_axi_arready) // Read request
        begin
          s00_axi_arready <= 0;
          rden <= 1;
          timeout <= MAXTRANS;
          rd_addr <= { s00_axi_araddr[C_S00_AXI_ADDR_WIDTH-1:2], 2'd0 };
        end

      if (bus_out_rd_ack || timeout == 1) // Read response
        begin
          s00_axi_rdata <= bus_out_rd_data;
          s00_axi_rvalid <= 1;
          s00_axi_rresp <= 0;
          timeout <= 0;
        end

      if (s00_axi_rvalid && s00_axi_rready) // Read complete
        begin
          s00_axi_rvalid <= 0;
          s00_axi_arready <= 1;
        end
    end

endmodule
