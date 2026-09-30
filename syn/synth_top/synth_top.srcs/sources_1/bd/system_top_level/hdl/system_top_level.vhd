--Copyright 1986-2017 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2017.2 (win64) Build 1909853 Thu Jun 15 18:39:09 MDT 2017
--Date        : Wed Sep 30 13:25:51 2026
--Host        : HTC219-308-SPC running 64-bit major release  (build 9200)
--Command     : generate_target system_top_level.bd
--Design      : system_top_level
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity system_top_level is
  port (
    pin_aud_bitclk : out STD_LOGIC;
    pin_aud_data : out STD_LOGIC;
    pin_aud_lrclk : out STD_LOGIC;
    pin_aud_mclk : out STD_LOGIC;
    pin_clk125mhz : in STD_LOGIC;
    pin_i2c_sclk : out STD_LOGIC;
    pin_i2c_sdata : inout STD_LOGIC;
    pin_keys : in STD_LOGIC_VECTOR ( 3 downto 0 );
    pin_leds_i2c : out STD_LOGIC_VECTOR ( 3 downto 0 );
    pin_rst_n : in STD_LOGIC
  );
  attribute CORE_GENERATION_INFO : string;
  attribute CORE_GENERATION_INFO of system_top_level : entity is "system_top_level,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=system_top_level,x_ipVersion=1.00.a,x_ipLanguage=VHDL,numBlks=5,numReposBlks=5,numNonXlnxBlks=2,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=2,numPkgbdBlks=0,bdsource=USER,synth_mode=Global}";
  attribute HW_HANDOFF : string;
  attribute HW_HANDOFF of system_top_level : entity is "system_top_level.hwdef";
end system_top_level;

architecture STRUCTURE of system_top_level is
  component system_top_level_i2c_config_0_0 is
  port (
    clk : in STD_LOGIC;
    rst_n : in STD_LOGIC;
    sdat_inout : inout STD_LOGIC;
    sclk_out : out STD_LOGIC;
    param_status_out : out STD_LOGIC_VECTOR ( 3 downto 0 );
    finished_out : out STD_LOGIC
  );
  end component system_top_level_i2c_config_0_0;
  component system_top_level_clk_wiz_0_0 is
  port (
    clk_in1 : in STD_LOGIC;
    clk_out1 : out STD_LOGIC;
    clk_out2 : out STD_LOGIC;
    locked : out STD_LOGIC
  );
  end component system_top_level_clk_wiz_0_0;
  component system_top_level_util_vector_logic_0_1 is
  port (
    Op1 : in STD_LOGIC_VECTOR ( 3 downto 0 );
    Op2 : in STD_LOGIC_VECTOR ( 3 downto 0 );
    Res : out STD_LOGIC_VECTOR ( 3 downto 0 )
  );
  end component system_top_level_util_vector_logic_0_1;
  component system_top_level_util_vector_logic_1_0 is
  port (
    Op1 : in STD_LOGIC_VECTOR ( 0 to 0 );
    Op2 : in STD_LOGIC_VECTOR ( 0 to 0 );
    Res : out STD_LOGIC_VECTOR ( 0 to 0 )
  );
  end component system_top_level_util_vector_logic_1_0;
  component system_top_level_synthesizer_0_0 is
  port (
    clk : in STD_LOGIC;
    rst_n : in STD_LOGIC;
    keys_in : in STD_LOGIC_VECTOR ( 3 downto 0 );
    aud_bclk_out : out STD_LOGIC;
    aud_data_out : out STD_LOGIC;
    aud_lrclk_out : out STD_LOGIC
  );
  end component system_top_level_synthesizer_0_0;
  signal Net : STD_LOGIC;
  signal clk_in1_1 : STD_LOGIC;
  signal clk_wiz_0_clk_out1 : STD_LOGIC;
  signal clk_wiz_0_clk_out2 : STD_LOGIC;
  signal clk_wiz_0_locked : STD_LOGIC;
  signal i2c_config_0_param_status_out : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal i2c_config_0_sclk_out : STD_LOGIC;
  signal keys_in_1 : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal pin_rst_n_1 : STD_LOGIC;
  signal synthesizer_0_aud_bclk_out : STD_LOGIC;
  signal synthesizer_0_aud_data_out : STD_LOGIC;
  signal synthesizer_0_aud_lrclk_out : STD_LOGIC;
  signal util_vector_logic_0_Res : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal util_vector_logic_1_Res : STD_LOGIC_VECTOR ( 0 to 0 );
  signal NLW_i2c_config_0_finished_out_UNCONNECTED : STD_LOGIC;
begin
  clk_in1_1 <= pin_clk125mhz;
  keys_in_1(3 downto 0) <= pin_keys(3 downto 0);
  pin_aud_bitclk <= synthesizer_0_aud_bclk_out;
  pin_aud_data <= synthesizer_0_aud_data_out;
  pin_aud_lrclk <= synthesizer_0_aud_lrclk_out;
  pin_aud_mclk <= clk_wiz_0_clk_out2;
  pin_i2c_sclk <= i2c_config_0_sclk_out;
  pin_leds_i2c(3 downto 0) <= util_vector_logic_0_Res(3 downto 0);
  pin_rst_n_1 <= pin_rst_n;
clk_wiz_0: component system_top_level_clk_wiz_0_0
     port map (
      clk_in1 => clk_in1_1,
      clk_out1 => clk_wiz_0_clk_out1,
      clk_out2 => clk_wiz_0_clk_out2,
      locked => clk_wiz_0_locked
    );
i2c_config_0: component system_top_level_i2c_config_0_0
     port map (
      clk => clk_wiz_0_clk_out1,
      finished_out => NLW_i2c_config_0_finished_out_UNCONNECTED,
      param_status_out(3 downto 0) => i2c_config_0_param_status_out(3 downto 0),
      rst_n => util_vector_logic_1_Res(0),
      sclk_out => i2c_config_0_sclk_out,
      sdat_inout => pin_i2c_sdata
    );
synthesizer_0: component system_top_level_synthesizer_0_0
     port map (
      aud_bclk_out => synthesizer_0_aud_bclk_out,
      aud_data_out => synthesizer_0_aud_data_out,
      aud_lrclk_out => synthesizer_0_aud_lrclk_out,
      clk => clk_wiz_0_clk_out2,
      keys_in(3 downto 0) => keys_in_1(3 downto 0),
      rst_n => util_vector_logic_1_Res(0)
    );
util_vector_logic_0: component system_top_level_util_vector_logic_0_1
     port map (
      Op1(3 downto 0) => i2c_config_0_param_status_out(3 downto 0),
      Op2(3 downto 0) => keys_in_1(3 downto 0),
      Res(3 downto 0) => util_vector_logic_0_Res(3 downto 0)
    );
util_vector_logic_1: component system_top_level_util_vector_logic_1_0
     port map (
      Op1(0) => clk_wiz_0_locked,
      Op2(0) => pin_rst_n_1,
      Res(0) => util_vector_logic_1_Res(0)
    );
end STRUCTURE;
