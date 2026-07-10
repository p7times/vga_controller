-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2026.1 (lin64) Build 6511674 Tue Jun 16 11:01:26 MDT 2026
-- Date        : Fri Jul 10 10:27:15 2026
-- Host        : nemesiseanu running 64-bit Linux Mint 22.3
-- Command     : write_vhdl -force -mode synth_stub
--               /home/user/Desktop/Personal_Stuff/Homework/an4/PRACTICA_CAPGEMINI/vga_ctrl/vga_ctrl.gen/sources_1/bd/vga_ctrl_block/ip/vga_ctrl_block_clk_wiz_0_0/vga_ctrl_block_clk_wiz_0_0_stub.vhdl
-- Design      : vga_ctrl_block_clk_wiz_0_0
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a35ticpg236-1L
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity vga_ctrl_block_clk_wiz_0_0 is
  Port ( 
    clk_out1 : out STD_LOGIC;
    reset : in STD_LOGIC;
    clk_in1 : in STD_LOGIC
  );

  attribute CORE_GENERATION_INFO : string;
  attribute CORE_GENERATION_INFO of vga_ctrl_block_clk_wiz_0_0 : entity is "vga_ctrl_block_clk_wiz_0_0,clk_wiz_v6_0_19_0_0,{component_name=vga_ctrl_block_clk_wiz_0_0,use_phase_alignment=true,use_min_o_jitter=false,use_max_i_jitter=false,use_dyn_phase_shift=false,use_inclk_switchover=false,use_dyn_reconfig=false,enable_axi=0,feedback_source=FDBK_AUTO,PRIMITIVE=MMCM,num_out_clk=1,clkin1_period=10.000,clkin2_period=10.000,use_power_down=false,use_reset=true,use_locked=false,use_inclk_stopped=false,feedback_type=SINGLE,CLOCK_MGR_TYPE=NA,manual_override=false}";
end vga_ctrl_block_clk_wiz_0_0;

architecture stub of vga_ctrl_block_clk_wiz_0_0 is
  attribute syn_black_box : boolean;
  attribute black_box_pad_pin : string;
  attribute syn_black_box of stub : architecture is true;
  attribute black_box_pad_pin of stub : architecture is "clk_out1,reset,clk_in1";
begin
end;
