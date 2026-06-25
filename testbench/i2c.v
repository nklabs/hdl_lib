
wire sda;
pullup (sda);

wire scl;
pullup (scl);

reg scl_in;
assign scl = (scl_in == 0 ? 1'b0 : 1'bz);
wire scl_out = scl;

reg sda_in;
assign sda = (sda_in == 0 ? 1'b0 : 1'bz);
wire sda_out = sda;

task i2c_wait_scl;
  begin
    // $display("scl wait...");
    @(posedge clk);
    while (scl != 1)
      begin
        @(posedge clk);
      end
    // $display("done.");
  end
endtask

task i2c_delay;
  begin
    for (x = 0; x != 10; x = x + 1)
      @(posedge clk);
  end
endtask

reg start;

task i2c_start;
  begin
    start <= 1;
    scl_in <= 1;
    i2c_delay();
    sda_in <= 0;
    i2c_delay();
    scl_in <= 0;
    i2c_delay();
    start <= 0;
  end
endtask

reg stop;

task i2c_stop;
  begin
    stop <= 1;
    sda_in <= 0;
    i2c_delay();
    scl_in <= 1;
    i2c_wait_scl();
    i2c_delay();
    sda_in <= 1;
    i2c_delay();
    stop <= 0;
  end
endtask

task i2c_write;
  input [7:0] data;
  integer n;
  begin
    n = 7;
    sda_in <= data[n];
    i2c_delay();
    scl_in <= 1;
    i2c_wait_scl(); // Should wait only on first bit
    i2c_delay();
    scl_in <= 0;
    i2c_delay();
    for (n = 6; n != -1; n = n - 1)
      begin
        sda_in <= data[n];
        i2c_delay();
        scl_in <= 1;
        i2c_delay();
        scl_in <= 0;
        i2c_delay();
      end
  end
endtask

task i2c_check_ack;
  begin
    sda_in <= 1;
    i2c_delay();
    scl_in <= 1;
    i2c_delay();
    if (sda_out != 0)
      $display("Missing ack!\n");
    scl_in <= 0;
    i2c_delay();
  end
endtask

reg [7:0] rd_data;

reg ack_it;
task i2c_read;
  integer n;
  begin
    n = 7;
    i2c_delay();
    scl_in <= 1;
    i2c_wait_scl(); // Should wait only on first bit
    i2c_delay();
    rd_data[n] <= sda_out;
    scl_in <= 0;
    for (n = 6; n != -1; n = n - 1)
      begin
        i2c_delay();
        scl_in <= 1;
        i2c_delay();
        rd_data[n] <= sda_out;
        scl_in <= 0;
      end
    i2c_delay();
    scl_in <= 1; // Ack pulse
    ack_it <= 1;
    i2c_delay();
    scl_in <= 0;
    ack_it <= 0;
    i2c_delay();
  end
endtask

task i2c_read_more;
  integer n;
  begin
    n = 7;
    i2c_delay();
    scl_in <= 1;
    i2c_wait_scl(); // Should wait only on first bit
    i2c_delay();
    rd_data[n] <= sda_out;
    scl_in <= 0;
    n = n - 1;
    for (n = 6; n != -1; n = n - 1)
      begin
        i2c_delay();
        scl_in <= 1;
        i2c_delay();
        rd_data[n] <= sda_out;
        scl_in <= 0;
      end
    i2c_delay();
    sda_in <= 0; // Assert sda low: we want the next byte
    i2c_delay();
    scl_in <= 1; // Ack pulse
    i2c_delay();
    scl_in <= 0;
    i2c_delay();
    sda_in <= 1;
  end
endtask
