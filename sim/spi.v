reg spi_mosi;
reg spi_miso;
reg spi_clk;
reg spi_cs_l;

// SPI Write

task spi_write;
  input [15:0] addr;
  input [31:0] data;
  integer n;
  begin
    @(posedge slow_clk);
    spi_cs_l <= 0;
    @(posedge slow_clk);
    for (n = 15; n != -1; n = n - 1) begin
      if (n == 1)
        spi_mosi <= 1; // Write
      else
        spi_mosi <= addr[n];
      @(posedge slow_clk);
      spi_clk <= 1;
      @(posedge slow_clk);
      spi_clk <= 0;
    end
    for (n = 31; n != -1; n = n - 1) begin
      spi_mosi <= data[n];
      @(posedge slow_clk);
      spi_clk <= 1;
      @(posedge slow_clk);
      spi_clk <= 0;
    end
    @(posedge slow_clk);
    spi_cs_l <= 1;
    @(posedge slow_clk);
  end
endtask


// SPI Read
reg [31:0] rd_data = 0;
reg data_flag = 0;

task spi_read;
  input [15:0] addr;
  integer n;
  begin
    @(posedge slow_clk);
    spi_cs_l <= 0;
    data_flag <= 0;
    @(posedge slow_clk);
    for (n = 15; n != -1; n = n - 1) begin
      if (n == 1)
        spi_mosi <= 0; // Read
      else
        spi_mosi <= addr[n];
      @(posedge slow_clk);
      spi_clk <= 1;
      @(posedge slow_clk);
      spi_clk <= 0;
    end
    data_flag <= 1;
    for (n = 31; n != -1; n = n - 1) begin
      spi_mosi <= 0;
      @(posedge slow_clk);
      spi_clk <= 1;
      @(posedge slow_clk);
      rd_data[n] = spi_miso;
      spi_clk <= 0;
    end
    @(posedge slow_clk);
    spi_cs_l <= 1;
    @(posedge slow_clk);
    data_flag <= 0;
  end
endtask
