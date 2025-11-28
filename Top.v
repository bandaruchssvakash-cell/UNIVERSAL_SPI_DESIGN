`timescale 1ns / 1ps

module FPGA_Top(
    input clk,          // 100MHz System Clock
    input btnC,         // Reset (Active High on Board)
    input btnU,         // Trigger TX (Active High)
    input [15:0] sw,    // Switches
    output [15:0] led,  // LEDs
    
    // PMOD JA Header Connections
    output JA1, // CS_n
    output JA2, // MOSI
    input  JA3, // MISO
    output JA4  // SCLK
    );

    // Signal Declarations
    wire w_Rst_L = ~btnC; // Invert Button for Active Low Reset
    wire w_TX_Ready;
    wire w_RX_DV;
    wire [7:0] w_RX_Byte;
    
    // Button Edge Detection (Single Pulse Generation)
    reg r_Btn_Prev;
    reg r_TX_DV;
    
    always @(posedge clk) begin
        r_Btn_Prev <= btnU;
        // Generate pulse only on rising edge of button press
        if (btnU && !r_Btn_Prev)
            r_TX_DV <= 1'b1;
        else
            r_TX_DV <= 1'b0;
    end

    // Instantiate the SPI Master
    // Slower Clock (div 32) ensures visible operation on Logic Analyzer/LEDs
    SPI_Master_AllModes #(.CLKS_PER_HALF_BIT(32)) SPI_Inst (
        .i_Rst_L(w_Rst_L),
        .i_Clk(clk),
        
        // Configuration from Switches
        .i_CPOL(sw[0]),      // Switch 0 = CPOL
        .i_CPHA(sw[1]),      // Switch 1 = CPHA
        
        // Data from Switches [9:2]
        .i_TX_Byte(sw[9:2]), 
        .i_TX_DV(r_TX_DV),   // Trigger from Button U
        
        // Outputs to LEDs
        .o_TX_Ready(w_TX_Ready),
        .o_RX_DV(w_RX_DV),
        .o_RX_Byte(w_RX_Byte), // Display Received Byte on LEDs [7:0]
        
        // SPI Physical Interface
        .o_SPI_Clk(JA4),
        .i_SPI_MISO(JA3),
        .o_SPI_MOSI(JA2),
        .o_SPI_CS_n(JA1)
    );

    // LED Assignments
    assign led[7:0]   = w_RX_Byte;      // LEDs 0-7: Received Data
    assign led[14]    = w_TX_Ready;     // LED 14: Ready Status
    assign led[15]    = w_RX_DV;        // LED 15: Data Valid Pulse (Might blink too fast to see)

endmodule