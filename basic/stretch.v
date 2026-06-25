// Array of pulse stretchers.

module stretch
#(
  parameter DATAWIDTH=1,
  parameter N=6 // Output pulse width in clock cycles
  parameter WIDTH = 3 // Big enough for N
) (
  input reset_l,
  input clk,
  input [DATAWIDTH-1:0] i,
  output reg [DATAWIDTH-1:0] o
  );

integer x;

reg [WIDTH-1:0] counters[DATAWIDTH-1:0];

always @(posedge clk or negedge reset_l)
  if(!reset_l)
    begin
      o <= 0;
      for(x = 0; x != DATAWIDTH; x = x + 1) counters[x] <= 0;
    end
  else
    begin
      o <= o | i;
      for(x = 0; x != DATAWIDTH; x = x + 1)
        if(i[x])
          counters[x] <= N-1;
        else if(counters[x])
          counters[x] <= counters[x] - 1;
        else
          o[x] <= 0;
    end

endmodule
