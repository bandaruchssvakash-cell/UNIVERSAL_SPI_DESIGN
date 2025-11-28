# UNIVERSAL_SPI_CONTROLLER_DESIGN

A robust, synthesizable Serial Peripheral Interface (SPI) Master and Slave implementation in Verilog. This IP Core is designed to be a "Universal Superset," supporting all 4 SPI Modes (CPOL/CPHA) via runtime configuration.

## Features
- **Universal Mode Support:** Supports SPI Modes 0, 1, 2, and 3 dynamically.
- **Full Duplex:** Simultaneous transmission and reception.
- **Robust Synchronization:** Slave module includes 2-stage synchronizers for safe Clock Domain Crossing (CDC).
- **Parameterized Speed:** Master clock frequency is configurable via `CLKS_PER_HALF_BIT` parameter.
- **Verified:**
  - **RTL:** Behavioral simulation covering all 4 modes.
  - **Gate Level:** Post-Implementation timing verification.
  - **Hardware:** Tested on Digilent Basys 3 (Artix-7 FPGA).

## Project Structure
- `rtl/` : Synthesizable Verilog source files (`spi_master.v`, `spi_slave.v`, `FPGA_Top.v`).
- `sim/` : Testbench files (`tb_spi.v`).
- `constraints/` : XDC constraints for Basys 3 board.

## Simulation Results
The design was verified using Vivado Simulator (XSim).
- **Mode 0 & 2 (CPHA=0):** Data sampled on Leading Edge.
- **Mode 1 & 3 (CPHA=1):** Data sampled on Trailing Edge.

## Implementation Details
- **Target Device:** Xilinx Artix-7 (xc7a35tcpg236-1)
- **Resource Usage:** Low LUT/FF count, suitable for small FPGAs.
- **Max Frequency:** 100 MHz System Clock (SPI Clock derived).

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
