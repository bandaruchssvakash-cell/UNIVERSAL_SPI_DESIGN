module SPI_Slave_AllModes
  (
   input        i_Rst_L,
   input        i_Clk,
   input        i_CPOL,
   input        i_CPHA,
   
   // SPI Interface
   input        i_SPI_Clk,
   input        i_SPI_MOSI,
   input        i_SPI_CS_n,
   output reg   o_SPI_MISO,
   
   // User Interface
   input  [7:0] i_TX_Byte,
   output reg   o_RX_DV,
   output reg [7:0] o_RX_Byte
   );

  reg [2:0] r_SPI_Clk_Sync; // 3 bits for edge detection
  reg [1:0] r_SPI_CS_Sync;

  // Edge Detection Logic
  wire w_SPI_Clk_Rising  = (r_SPI_Clk_Sync[2:1] == 2'b01);
  wire w_SPI_Clk_Falling = (r_SPI_Clk_Sync[2:1] == 2'b10);
  wire w_SPI_CS_Active   = ~r_SPI_CS_Sync[1];

  reg [2:0] r_Bit_Idx;
  reg [7:0] r_RX_Temp;
  reg [7:0] r_TX_Temp;
  
  // Logic helpers
  reg w_Sample_Enable;
  reg w_Drive_Enable;

  always @(posedge i_Clk or negedge i_Rst_L) begin
    if (~i_Rst_L) begin
      r_SPI_Clk_Sync <= 3'b000;
      r_SPI_CS_Sync  <= 2'b11;
      o_RX_DV        <= 1'b0;
      o_RX_Byte      <= 8'h00;
      o_SPI_MISO     <= 1'b0;
      r_Bit_Idx      <= 3'b111;
      r_TX_Temp      <= 8'h00;
    end
    else begin
      r_SPI_Clk_Sync <= {r_SPI_Clk_Sync[1:0], i_SPI_Clk};
      r_SPI_CS_Sync  <= {r_SPI_CS_Sync[0], i_SPI_CS_n};
      o_RX_DV        <= 1'b0;
      w_Sample_Enable <= 1'b0;
      w_Drive_Enable  <= 1'b0;

      // Determine Logic for Sample vs Drive
      // CPOL=0: Rise=Leading, Fall=Trailing
      // CPOL=1: Fall=Leading, Rise=Trailing
      if (i_CPOL == 0) begin
        if (i_CPHA == 0) begin // Mode 0: Sample Rise, Drive Fall
           if (w_SPI_Clk_Rising) w_Sample_Enable <= 1;
           if (w_SPI_Clk_Falling) w_Drive_Enable <= 1;
        end else begin         // Mode 1: Drive Rise, Sample Fall
           if (w_SPI_Clk_Rising) w_Drive_Enable <= 1;
           if (w_SPI_Clk_Falling) w_Sample_Enable <= 1;
        end
      end else begin // CPOL == 1
         if (i_CPHA == 0) begin // Mode 2: Sample Fall, Drive Rise
           if (w_SPI_Clk_Falling) w_Sample_Enable <= 1;
           if (w_SPI_Clk_Rising) w_Drive_Enable <= 1;
         end else begin         // Mode 3: Drive Fall, Sample Rise
           if (w_SPI_Clk_Falling) w_Drive_Enable <= 1;
           if (w_SPI_Clk_Rising) w_Sample_Enable <= 1;
         end
      end

      if (w_SPI_CS_Active) begin
        // SAMPLING (MOSI)
        if (w_Sample_Enable) begin
          r_RX_Temp[r_Bit_Idx] <= i_SPI_MOSI;
          if (r_Bit_Idx == 0) begin
             o_RX_DV     <= 1'b1;
             o_RX_Byte   <= {r_RX_Temp[7:1], i_SPI_MOSI};
             r_Bit_Idx   <= 3'b111;
             r_TX_Temp   <= i_TX_Byte; 
          end else begin
             r_Bit_Idx <= r_Bit_Idx - 1;
          end
        end
        
        // DRIVING (MISO)
        if (w_Drive_Enable) begin
           o_SPI_MISO <= r_TX_Temp[r_Bit_Idx];
        end
      end
      else begin
        // Reset and CPHA Setup
        r_Bit_Idx <= 3'b111;
        r_TX_Temp <= i_TX_Byte;
        
        // CPHA=0 Special Case: Slave drives MISO immediately when CS goes Low
        if (i_CPHA == 0) o_SPI_MISO <= i_TX_Byte[7];
      end
    end
  end
endmodule