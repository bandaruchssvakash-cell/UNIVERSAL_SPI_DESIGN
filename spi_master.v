`timescale 1ns / 1ps

module SPI_Master_AllModes
  #(parameter CLKS_PER_HALF_BIT = 4)
  (
   input        i_Rst_L,
   input        i_Clk,
   
   // Mode Configuration
   input        i_CPOL, // 0=Idle Low, 1=Idle High
   input        i_CPHA, // 0=Sample Leading, 1=Sample Trailing
   
   // User Interface
   input [7:0]  i_TX_Byte,
   input        i_TX_DV,
   output reg   o_TX_Ready,
   output reg   o_RX_DV,
   output reg [7:0] o_RX_Byte,

   // SPI Interface
   output reg   o_SPI_Clk,
   input        i_SPI_MISO,
   output reg   o_SPI_MOSI,
   output reg   o_SPI_CS_n
   );

  localparam IDLE     = 2'b00;
  localparam TRANSFER = 2'b01;
  localparam CLEANUP  = 2'b10;

  reg [1:0] r_SM_CS;
  reg [2:0] r_Bit_Idx;
  reg [7:0] r_TX_Shift;
  reg [7:0] r_RX_Shift;
  
  reg [$clog2(CLKS_PER_HALF_BIT*2)-1:0] r_Clk_Count; 
  reg r_Leading_Edge;
  reg r_Trailing_Edge;
  
  // Wires to determine Sample vs Shift based on CPHA
  reg w_Sample_En;
  reg w_Shift_En;

  always @(posedge i_Clk or negedge i_Rst_L) begin
    if (~i_Rst_L) begin
      o_TX_Ready      <= 1'b0;
      o_RX_DV         <= 1'b0;
      o_RX_Byte       <= 8'h00;
      o_SPI_Clk       <= i_CPOL; // Default to CPOL
      o_SPI_MOSI      <= 1'b0;
      o_SPI_CS_n      <= 1'b1;
      r_SM_CS         <= IDLE;
      r_Bit_Idx       <= 3'b111;
      r_Clk_Count     <= 0;
      r_TX_Shift      <= 8'h00;
      r_RX_Shift      <= 8'h00;
    end
    else begin
      r_Leading_Edge  <= 1'b0;
      r_Trailing_Edge <= 1'b0;
      w_Sample_En     <= 1'b0;
      w_Shift_En      <= 1'b0;
      o_RX_DV         <= 1'b0;

      case (r_SM_CS)
        // IDLE STATE
        IDLE: begin
          o_SPI_CS_n  <= 1'b1;
          o_TX_Ready  <= 1'b1;
          o_SPI_Clk   <= i_CPOL; // Set Idle State
          r_Clk_Count <= 0;
          
          if (i_TX_DV) begin
            o_TX_Ready  <= 1'b0;
            r_TX_Shift  <= i_TX_Byte;
            r_SM_CS     <= TRANSFER;
            o_SPI_CS_n  <= 1'b0;
            r_Bit_Idx   <= 3'b111;

            // CPHA=0: Data must be valid BEFORE first clock edge
            if (i_CPHA == 1'b0) begin
               o_SPI_MOSI <= i_TX_Byte[7];
            end
          end
        end

        // TRANSFER STATE
        // TRANSFER: Generate Clock and Handle Bits
        TRANSFER: begin
          // 1. Clock Generation Logic
          if (r_Clk_Count == CLKS_PER_HALF_BIT-1) begin
            r_Clk_Count <= 0;
            o_SPI_Clk   <= ~o_SPI_Clk; 
            
            // Edge Detection
            if (o_SPI_Clk == i_CPOL) begin // Leading Edge
               if (i_CPHA == 1'b0) w_Sample_En <= 1'b1;
               else                w_Shift_En  <= 1'b1;
            end 
            else begin // Trailing Edge
               if (i_CPHA == 1'b0) w_Shift_En  <= 1'b1;
               else                w_Sample_En <= 1'b1;
            end
          end 
          else begin
            r_Clk_Count <= r_Clk_Count + 1;
          end

          // 2. Handle SAMPLING (MISO)
          if (w_Sample_En) begin
            r_RX_Shift[r_Bit_Idx] <= i_SPI_MISO;
            
            // CORRECTION FOR CPHA=1: Decrement HERE (after sampling), not during shift
            if (i_CPHA == 1'b1) begin
               if (r_Bit_Idx == 0) r_SM_CS <= CLEANUP;
               else r_Bit_Idx <= r_Bit_Idx - 1;
            end
          end

          // 3. Handle SHIFTING (MOSI)
          if (w_Shift_En) begin
            if (i_CPHA == 1'b0) begin
               // CPHA=0: Shift on Trailing Edge. Decrement here.
               if (r_Bit_Idx == 0) r_SM_CS <= CLEANUP;
               else begin
                  r_Bit_Idx <= r_Bit_Idx - 1;
                  o_SPI_MOSI <= r_TX_Shift[r_Bit_Idx - 1];
               end
            end
            else begin
               // CPHA=1: Shift on Leading Edge.
               // CORRECTION: Just output data. Do NOT decrement yet!
               o_SPI_MOSI <= r_TX_Shift[r_Bit_Idx]; 
            end
          end
        end

        // CLEANUP STATE
        CLEANUP: begin
           // Wait a bit before raising CS
           // CLEANUP STATE
           // Wait longer (Full bit period) to ensure Slave syncs the last edge
           if (r_Clk_Count == CLKS_PER_HALF_BIT*2-1) begin
             o_SPI_CS_n <= 1'b1;
             o_RX_Byte  <= r_RX_Shift;
             o_RX_DV    <= 1'b1;
             o_SPI_Clk  <= i_CPOL; // Return to idle
             r_SM_CS    <= IDLE;
           end
           else begin
             r_Clk_Count <= r_Clk_Count + 1;
           end
        end
      endcase
    end
  end
endmodule