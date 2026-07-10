//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2026.1 (lin64) Build 6511674 Tue Jun 16 11:01:26 MDT 2026
//Date        : Fri Jul 10 10:26:45 2026
//Host        : nemesiseanu running 64-bit Linux Mint 22.3
//Command     : generate_target vga_ctrl_block_wrapper.bd
//Design      : vga_ctrl_block_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module vga_ctrl_block_wrapper
   (clk_100MHz,
    clk_out1_0,
    reset_rtl_0);
  input clk_100MHz;
  output clk_out1_0;
  input reset_rtl_0;

  wire clk_100MHz;
  wire clk_out1_0;
  wire reset_rtl_0;

  vga_ctrl_block vga_ctrl_block_i
       (.clk_100MHz(clk_100MHz),
        .clk_out1_0(clk_out1_0),
        .reset_rtl_0(reset_rtl_0));
endmodule
