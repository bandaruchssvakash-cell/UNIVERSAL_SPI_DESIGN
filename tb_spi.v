`timescale 1ns / 1ps

module tb_SPI_AllModes();

  reg r_Rst_L;
  reg r_Clk;
  reg r_CPOL;
  reg r_CPHA;

  // Master Signals
  reg [7:0]  r_Master_TX;
  reg        r_Master_DV;
  wire       w_Master_Ready;
  wire       w_Master_RX_DV;
  wire [7:0] w_Master_RX;

  // Slave Signals
  reg [7:0]  r_Slave_TX;
  wire       w_Slave_RX_DV;
  wire [7:0] w_Slave_RX;

  // Interconnects
  wire w_SPI_Clk;
  wire w_SPI_MOSI;
  wire w_SPI_MISO;
  wire w_SPI_CS_n;

  // Instantiate Master
  SPI_Master_AllModes #(.CLKS_PER_HALF_BIT(16)) UUT_Master
  (
   .i_Rst_L(r_Rst_L), .i_Clk(r_Clk),
   .i_CPOL(r_CPOL), .i_CPHA(r_CPHA),
   .i_TX_Byte(r_Master_TX), .i_TX_DV(r_Master_DV),
   .o_TX_Ready(w_Master_Ready),
   .o_RX_DV(w_Master_RX_DV), .o_RX_Byte(w_Master_RX),
   .o_SPI_Clk(w_SPI_Clk), .i_SPI_MISO(w_SPI_MISO),
   .o_SPI_MOSI(w_SPI_MOSI), .o_SPI_CS_n(w_SPI_CS_n)
  );

  // Instantiate Slave
  SPI_Slave_AllModes UUT_Slave
  (
   .i_Rst_L(r_Rst_L), .i_Clk(r_Clk),
   .i_CPOL(r_CPOL), .i_CPHA(r_CPHA),
   .i_SPI_Clk(w_SPI_Clk), .i_SPI_MOSI(w_SPI_MOSI),
   .i_SPI_CS_n(w_SPI_CS_n), .o_SPI_MISO(w_SPI_MISO),
   .i_TX_Byte(r_Slave_TX),
   .o_RX_DV(w_Slave_RX_DV), .o_RX_Byte(w_Slave_RX)
  );

  initial begin
    r_Clk = 0;
    forever #5 r_Clk = ~r_Clk;
  end

  // Task to Run a Single SPI Transaction
 // Task to Run a Single SPI Transaction
  task run_test(input [7:0] master_data, input [7:0] slave_data);
    begin
      // 1. Setup Data
      r_Master_TX = master_data;
      r_Slave_TX  = slave_data;
      
      // 2. Wait for Ready
      wait(w_Master_Ready);
      @(posedge r_Clk);
      
      // 3. Trigger Transaction
      r_Master_DV = 1;
      @(posedge r_Clk);
      r_Master_DV = 0;
      
      // 4. Wait for completion (Master RX Data Valid)
      @(posedge w_Master_RX_DV);
      
      // --- THE FIX IS HERE ---
      // We wait 200ns to let the Slave finish shifting its last bit
      // and for the signals to settle in the simulation.
      #200; 
      
      // 5. Verify
      if(w_Master_RX == slave_data && w_Slave_RX == master_data)
        $display("[PASS] Mode CPOL=%b CPHA=%b | M sent %h, S rcvd %h | S sent %h, M rcvd %h", 
                 r_CPOL, r_CPHA, master_data, w_Slave_RX, slave_data, w_Master_RX);
      else
        $display("[FAIL] Mode CPOL=%b CPHA=%b | Exp M->S: %h Rcvd: %h | Exp S->M: %h Rcvd: %h", 
                 r_CPOL, r_CPHA, master_data, w_Slave_RX, slave_data, w_Master_RX);
    end
  endtask

  initial begin
    r_Rst_L = 0;
    r_CPOL = 0; r_CPHA = 0;
    r_Master_DV = 0;
    #100 r_Rst_L = 1;
    #100;

    // --- TEST MODE 0 (0,0) ---
    r_CPOL = 0; r_CPHA = 0;
    #20;
    run_test(8'hA1, 8'h55);

    // --- TEST MODE 1 (0,1) ---
    r_CPOL = 0; r_CPHA = 1;
    #100; // Time for CS to go high and settle
    run_test(8'hB2, 8'h66);

    // --- TEST MODE 2 (1,0) ---
    r_CPOL = 1; r_CPHA = 0;
    #100;
    run_test(8'hC3, 8'h77);

    // --- TEST MODE 3 (1,1) ---
    r_CPOL = 1; r_CPHA = 1;
    #100;
    run_test(8'hD4, 8'h88);

    $display("ALL TESTS COMPLETE");
    $stop;
  end

endmodule