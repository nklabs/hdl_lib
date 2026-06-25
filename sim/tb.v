`timescale 1ns / 1ps

module tb;

reg clk = 0;
reg reset_l = 1;

// For lattice
GSR GSR_INST
  (
  .GSR_N (reset_l),
  .CLK (clk)
  );

always #10 clk <= !clk;

// For ncverilog
initial
  begin
//    $shm_open("debug.shm",0,500971520,1);
//    $shm_probe(tb, "AC");
  end

initial
  begin
    // For VCS
    $dumpvars(0);
    $dumpon;

    $display("Hi there!\n");
    clk <= 0;
    @(posedge clk);
    @(posedge clk);
    reset_l <= 0;
    @(posedge clk);
    @(posedge clk);
    reset_l <= 1;
    @(posedge clk);
    @(posedge clk);
    for (x = 0; x != 400; x = x + 1)
      @(posedge clk);
    $finish;
  end
