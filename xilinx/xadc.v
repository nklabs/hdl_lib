// Interface to Zynq 7000 XADC

module bus_xadc
import bus::*;
#(
  parameter ADDR = 0
) (
  input bus_in_s bus_in,
  output bus_out_s bus_out,

  input vp, // XADC dedicated  input
  input vn
  );

// On-die temp sensor

wire [31:0] regxadc_out;
wire [31:0] regxadc_in;
wire regxadc_pulse;

wire [5:0] xadc_addr = regxadc_out[21:16];
wire [15:0] xadc_wr_data = regxadc_out[15:0];
wire [15:0] xadc_rd_data;
wire xadc_en = regxadc_pulse;
wire xadc_we = regxadc_out[31] && xadc_en;
wire xadc_ack;

reg [15:0] xadc_data;
assign regxadc_in[15:0] = xadc_data;

reg xadc_busy;

always @(posedge bus_in.clk)
  if (!bus_in.reset_l)
    begin
      xadc_busy <= 0;
      xadc_data <= 0;
    end
  else if (xadc_ack)
    begin
      xadc_busy <= 0;
      xadc_data <= xadc_rd_data;
    end
  else if (xadc_en)
    begin
      xadc_busy <= 1;
      xadc_data <= 0;
    end

assign regxadc_in[31] = xadc_busy;
assign regxadc_in[30:16] = 0;

xadc_wiz_0 xadc
  (
  .daddr_in (xadc_addr),            // Address bus for the dynamic reconfiguration port
  .dclk_in (bus_in.clk),             // Clock input for the dynamic reconfiguration port
  .den_in (xadc_en),              // Enable Signal for the dynamic reconfiguration port
  .di_in (xadc_wr_data),               // Input data bus for the dynamic reconfiguration port
  .dwe_in (xadc_we),              // Write Enable for the dynamic reconfiguration port
  .reset_in (!bus_in.reset_l),            // Reset signal for the System Monitor control logic
  .busy_out (),            // ADC Busy signal
  .channel_out (),         // Channel Selection Outputs
  .do_out (xadc_rd_data),              // Output data bus for dynamic reconfiguration port
  .drdy_out (xadc_ack),            // Data ready signal for the dynamic reconfiguration port
  .eoc_out (),             // End of Conversion Signal
  .eos_out (),             // End of Sequence Signal
  .alarm_out (),           // OR'ed output of all the Alarms
  .vp_in (vp),               // Dedicated Analog Input Pair
  .vn_in (vn)
  );

bus_split_reg #(.ADDR(ADDR), .DATAWIDTH(32), .IZ(0)) regxadc
  (
  .bus_in (bus_in),
  .bus_out (bus_out),

  .out (regxadc_out),
  .in (regxadc_in),
  .wr_pulse (regxadc_pulse)
  );

endmodule
