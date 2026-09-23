-------------------------------------------------------------------------------
-- Title      : COMP.CE.240, Exercise 08
-- Project    : Synthesizer Top Level
-------------------------------------------------------------------------------
-- File       : synthesizer.vhd
-- Author     : Quang Le, Tatu Nyberg
-- Company    : TAU
-- Edited     : 2026-09-23
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Top-level structural description of the synthesizer. 
--              Connects four parameterizable wave generators (controlled by 
--              push buttons) to a multi-port adder, and routes the mixed 
--              audio to the serial audio controller.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description

-------------------------------------------------------------------------------
library ieee;
USE ieee.std_logic_1164.all;

entity synthesizer is
    generic (
        -- System and audio configuration parameters
        clk_freq_g    : integer := 12288000;
        sample_rate_g : integer := 48000;
        data_width_g  : integer := 16;
        n_keys_g      : integer := 4
    );
    port (
        clk           : in std_logic; 
        rst_n         : in std_logic; 
        
        -- Push button inputs mapped to the wave generators
        keys_in       : in std_logic_vector(n_keys_g-1 downto 0);
        
        -- Serial audio interface signals going to the external codec
        aud_bclk_out  : out std_logic;
        aud_data_out  : out std_logic;
        aud_lrclk_out : out std_logic
    );
end entity synthesizer;

architecture structural of synthesizer is
    
    -- Step values define the specific frequency of each wave generator
    constant step_1 : integer := 1;
    constant step_2 : integer := 2;
    constant step_3 : integer := 4;
    constant step_4 : integer := 8;

    -- Internal signals holding the individual 16-bit waveforms
    signal wave_gen_1 : std_logic_vector(data_width_g-1 downto 0);
    signal wave_gen_2 : std_logic_vector(data_width_g-1 downto 0);
    signal wave_gen_3 : std_logic_vector(data_width_g-1 downto 0);
    signal wave_gen_4 : std_logic_vector(data_width_g-1 downto 0);
    
    -- Flattened bus containing all four waveforms to feed the adder
    signal multi_port_adder_in : std_logic_vector(data_width_g*n_keys_g-1 downto 0);
    
    -- Final mixed audio signal before serialization
    signal multi_port_adder_out : std_logic_vector(data_width_g-1 downto 0);

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

    component multi_port_adder
    generic (
        operand_width_g   : INTEGER := 16;
        num_of_operands_g : INTEGER := 4
    );
    port (
        clk         : IN  STD_LOGIC;
        rst_n       : IN  STD_LOGIC;
        operands_in : IN  STD_LOGIC_VECTOR((operand_width_g*num_of_operands_g - 1) DOWNTO 0);
        sum_out     : OUT STD_LOGIC_VECTOR(operand_width_g-1 DOWNTO 0)
    );
    end component;
    
begin

    -- Concatenate the individual wave generator outputs into a single wide bus for the adder
    multi_port_adder_in <= wave_gen_1 & wave_gen_2 & wave_gen_3 & wave_gen_4;

    -- Wave Generator 1 (Lowest frequency)
    wave_gen1: wave_gen
    generic map (
        width_g => data_width_g,
        step_g  => step_1
    )
    port map (
        clk             => clk,
        rst_n           => rst_n,
        sync_clear_n_in => keys_in(0), -- Controlled by the first push button
        value_out       => wave_gen_1
    );
    
    -- Wave Generator 2
    wave_gen2: wave_gen
    generic map (
        width_g => data_width_g,
        step_g  => step_2
    )
    port map (
        clk             => clk,
        rst_n           => rst_n,
        sync_clear_n_in => keys_in(1), -- Controlled by the second push button
        value_out       => wave_gen_2
    );
    
    -- Wave Generator 3
    wave_gen3: wave_gen
    generic map (
        width_g => data_width_g,
        step_g  => step_3
    )
    port map (
        clk             => clk,
        rst_n           => rst_n,
        sync_clear_n_in => keys_in(2), -- Controlled by the third push button
        value_out       => wave_gen_3
    );
    
    -- Wave Generator 4 (Highest frequency)
    wave_gen4: wave_gen
    generic map (
        width_g => data_width_g,
        step_g  => step_4
    )
    port map (
        clk             => clk,
        rst_n           => rst_n,
        sync_clear_n_in => keys_in(3), -- Controlled by the fourth push button
        value_out       => wave_gen_4
    );

    -- Mixes the four independent waveforms into a single 16-bit audio channel
    mul_port_adder : multi_port_adder
    generic map (
        operand_width_g   => data_width_g,
        num_of_operands_g => n_keys_g
    )
    port map (
        clk         => clk,
        rst_n       => rst_n,
        operands_in => multi_port_adder_in,
        sum_out     => multi_port_adder_out
    );
    
    -- Serializes the mixed audio data to the external DAC
    audio_control : audio_ctrl
    generic map (
        ref_clk_freq_g => clk_freq_g,
        sample_rate_g  => sample_rate_g,
        data_width_g   => data_width_g
    )
    port map (
        clk           => clk,
        rst_n         => rst_n,
        -- Feed the same mixed signal to both left and right channels (Mono output)
        left_data_in  => multi_port_adder_out,
        right_data_in => multi_port_adder_out,
        aud_bclk_out  => aud_bclk_out,
        aud_data_out  => aud_data_out,
        aud_lrclk_out => aud_lrclk_out
    );
    
end architecture structural;