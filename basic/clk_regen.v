// Re-create clock as logic instead of clock net
// Useful in FPGAs that do not allow clock net to feed logic
// or where you want typical clk->out delay

module clk_regen
  (
  input reset_l,
  input clk,
  output clk_regen
  );

reg i;
reg q;

always @(posedge clk or negedge reset_l)
  if (!reset_l)
    i <= 0;
  else
    i <= ~i;

always @(negedge clk or negedge reset_l)
  if (!reset_l)
    q <= 0;
  else
    q <= i;

wire clk_regen = i ^ q;

endmodule
