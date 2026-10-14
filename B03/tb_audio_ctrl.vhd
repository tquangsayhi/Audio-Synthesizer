-------------------------------------------------------------------------------
-- Title      : COMP.CE.240, Bonus 3
-- Project    : Self-Checking Audio Controller Testbench
-------------------------------------------------------------------------------
-- File       : tb_audio_ctrl.vhd
-- Author     : Quang Le, Tatu Nyberg
-- Company    : TAU
-- Edited     : 2026-09-24
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Top-level structural testbench with an automated self-checking 
--              process. Compares reconstructed parallel data from the codec 
--              against delayed snapshots of the original wave generator data.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
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
    
    -- Constants
    constant clock_period_c : time := 50 ns;
    constant ref_clk_freq   : integer := 20000000;
    constant sample_rate    : integer := 48000;
    constant step_1         : integer := 2;
    constant step_2         : integer := 10;
    
    -- System signals
    signal clk          : std_logic := '0';
    signal rst_n        : std_logic := '0';
    signal sync_clear_n : std_logic := '1';
    
    -- Interconnect signals
    signal l_data_wg_actrl, r_data_wg_actrl : std_logic_vector(data_width_g-1 downto 0);
    signal aud_bit_clk, aud_lr_clk, aud_data: std_logic;
    signal l_data_codec_tb, r_data_codec_tb : std_logic_vector(data_width_g-1 downto 0);

    -- Self-checking memory registers
    signal expected_left  : std_logic_vector(data_width_g-1 downto 0) := (others => '0');
    signal expected_right : std_logic_vector(data_width_g-1 downto 0) := (others => '0');

    -- Components
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

    -- Clock and reset stimulus
    clk <= not clk after clock_period_c/2;
    rst_n <= '1' after clock_period_c * 2;
    sync_clear_n <= '0' after 200 ns, '1' after 250 ns;

    -- Left Wave Generator
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
    
    -- Right Wave Generator
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

    -- Audio Controller (Parallel to Serial)
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
    
    -- Audio Codec Model (Serial to Parallel)
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

    -- ========================================================================
    -- AUTOMATED SELF-CHECKING VERIFICATION PROCESS
    -- ========================================================================
    checker_process : process
    begin
        -- Wait for the system to exit reset
        wait until rst_n = '1';
        
        loop
            -- 1. WAIT FOR RIGHT CHANNEL TO FINISH (aud_lr_clk rises to '1')
            wait until aud_lr_clk = '1';
            wait for 1 ns; -- Delta-cycle buffer to allow codec output to settle
            
            -- Verify the Right channel from the PREVIOUS frame
            if now > 100 us then
                assert r_data_codec_tb = expected_right
                    report "RIGHT CHANNEL ERROR: Output does not match fed in value!"
                    severity error;
            end if;

            -- Capture the wave generator inputs for the CURRENT frame.
            -- Using 'delayed allows us to sample the stable data from half a clock cycle ago.
            expected_left  <= l_data_wg_actrl'delayed(clock_period_c / 2);
            expected_right <= r_data_wg_actrl'delayed(clock_period_c / 2);

            -- 2. WAIT FOR LEFT CHANNEL TO FINISH (aud_lr_clk falls to '0')
            wait until aud_lr_clk = '0';
            wait for 1 ns; 
            
            -- Verify the Left channel from the CURRENT frame
            if now > 100 us then
                assert l_data_codec_tb = expected_left
                    report "LEFT CHANNEL ERROR: Output does not match fed in value!"
                    severity error;
            end if;
            
        end loop;
    end process;

end architecture testbench;