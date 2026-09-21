-------------------------------------------------------------------------------
-- Title      : COMP.CE.240, Exercise 06 / 07
-- Project    : Audio Codec Controller Testbench
-------------------------------------------------------------------------------
-- File       : tb_audio_ctrl.vhd
-- Author     : Quang Le, Tatu Nyberg
-- Company    : TAU
-- Edited     : 2026-09-21
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Top-level structural testbench. Connects two triangular 
--              wave generators (Left/Right) to the audio controller, and 
--              verifies the serial transmission through the codec model.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description

-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_audio_ctrl is 
    generic (
        data_width_g : integer := 16
    );
end entity tb_audio_ctrl;

architecture testbench of tb_audio_ctrl is 
    
    -- Simulation Configuration Constants
    constant clock_period_c : time := 50 ns;       -- 50 ns cycle simulates a 20 MHz clock frequency
    constant ref_clk_freq   : integer := 20000000; -- Matches the 20 MHz generated clock
    constant sample_rate    : integer := 48000;    -- Standard 48 kHz audio sampling rate
    
    -- Wave Generator Step Configurations
    constant step_1 : integer := 2;                -- Step value for the left channel wave generator
    constant step_2 : integer := 10;               -- Step value for the right channel wave generator
    
    -- System Control Signals
    signal clk, rst_n       : std_logic := '0';
    signal sync_clear_n     : std_logic := '1';
    
    -- Parallel Data Interconnects (Wave Generators -> Audio Controller)
    signal l_data_wg_actrl, r_data_wg_actrl : std_logic_vector(data_width_g-1 downto 0);
    
    -- Serial Audio Bus (Audio Controller -> Codec Model)
    signal aud_bit_clk, aud_lr_clk, aud_data : std_logic;
    
    -- Deserialized Output Data (Codec Model -> Testbench Monitor)
    signal l_data_codec_tb, r_data_codec_tb : std_logic_vector(data_width_g-1 downto 0);

    -- Component Declarations
    component wave_gen 
    generic (
        width_g : INTEGER;
        step_g  : INTEGER
    );
    port (
        clk             : IN  STD_LOGIC;
        rst_n           : IN  STD_LOGIC;
        sync_clear_n_in : IN  STD_LOGIC;
        value_out       : OUT STD_LOGIC_VECTOR(width_g - 1 downto 0)
    );
    end component;

    component audio_ctrl
    generic (
        ref_clk_freq_g : integer := 12288000;
        sample_rate_g  : integer := 48000;
        data_width_g   : integer := 16
    );
    port (
        clk           : in  std_logic;
        rst_n         : in  std_logic;
        left_data_in  : in  std_logic_vector(data_width_g - 1 downto 0);
        right_data_in : in  std_logic_vector(data_width_g - 1 downto 0);
        aud_bclk_out  : out std_logic;
        aud_data_out  : out std_logic;
        aud_lrclk_out : out std_logic
    );
    end component;
    
    component audio_codec_model
    generic (
        data_width_g : integer := 16
    );
    port (
        rst_n           : in  std_logic;
        aud_bclk_in     : in  std_logic;
        aud_lrclk_in    : in  std_logic;
        aud_data_in     : in  std_logic;
        value_left_out  : out std_logic_vector(data_width_g-1 downto 0);
        value_right_out : out std_logic_vector(data_width_g-1 downto 0)
    );
    end component;

begin
    
    -- Clock and Reset Generation
    clk <= not clk after clock_period_c / 2;
    rst_n <= '1' after clock_period_c * 2;
    
    -- Synchronous clear stimulus: Pulses low at 200 ns to ensure the 
    -- wave generators are reset at least once well before the 10 ms mark.
    sync_clear_n <= '0' after 200 ns, '1' after 250 ns;

    -- Left Channel Wave Generator Instance
    wave_gen_1 : wave_gen
    generic map (
        width_g => data_width_g,
        step_g  => step_1
    )
    port map (
        clk             => clk,
        rst_n           => rst_n,
        sync_clear_n_in => sync_clear_n,
        value_out       => l_data_wg_actrl
    );
    
    -- Right Channel Wave Generator Instance
    wave_gen_2 : wave_gen
    generic map (
        width_g => data_width_g,
        step_g  => step_2
    )
    port map (
        clk             => clk,
        rst_n           => rst_n,
        sync_clear_n_in => sync_clear_n,
        value_out       => r_data_wg_actrl
    );

    -- Audio Controller Instance (Parallel to Serial Conversion)
    audio_control : audio_ctrl
    generic map (
        ref_clk_freq_g => ref_clk_freq,
        sample_rate_g  => sample_rate,
        data_width_g   => data_width_g
    )
    port map (
        clk           => clk,
        rst_n         => rst_n,
        left_data_in  => l_data_wg_actrl,
        right_data_in => r_data_wg_actrl,
        aud_bclk_out  => aud_bit_clk,
        aud_data_out  => aud_data,
        aud_lrclk_out => aud_lr_clk
    );
    
    -- Audio Codec Model Instance (Serial to Parallel Verification)
    codec_inst : audio_codec_model
    generic map (
        data_width_g => data_width_g
    )
    port map (
        rst_n           => rst_n,
        aud_bclk_in     => aud_bit_clk,
        aud_lrclk_in    => aud_lr_clk,
        aud_data_in     => aud_data,
        value_left_out  => l_data_codec_tb,
        value_right_out => r_data_codec_tb
    );
    
end architecture testbench;