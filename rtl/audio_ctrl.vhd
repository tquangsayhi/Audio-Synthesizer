-------------------------------------------------------------------------------
-- Title      : COMP.CE.240, Exercise 06 / 07
-- Project    : Audio Codec Controller
-------------------------------------------------------------------------------
-- File       : audio_ctrl.vhd
-- Author     : Quang Le, Tatu Nyberg
-- Company    : TAU
-- Edited     : 2026-09-21
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Parallel-to-serial audio controller for DA7212 codec.
--              Generates synchronized BCLK and LRCLK using a derived counter.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description

-------------------------------------------------------------------------------
library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
 
entity audio_ctrl is 
    generic ( 
        ref_clk_freq_g : integer := 12_288_000; 
        sample_rate_g  : integer := 48_000; 
        data_width_g   : integer := 16 
    ); 
 
    port ( 
        clk            : in  std_logic; 
        rst_n          : in  std_logic; 
        left_data_in   : in  std_logic_vector(data_width_g-1 downto 0); 
        right_data_in  : in  std_logic_vector(data_width_g-1 downto 0); 
        aud_bclk_out   : out std_logic; 
        aud_data_out   : out std_logic; 
        aud_lrclk_out  : out std_logic 
    ); 
end entity audio_ctrl; 
 
architecture rtl of audio_ctrl is 
 
    -- Dynamically calculate the number of main clock cycles per BCLK half-period
    constant bclk_half_period_c : integer := 
        ref_clk_freq_g / (4 * sample_rate_g * data_width_g); 
 
    -- Divider counter for generating BCLK
    signal bclk_counter_r : 
        integer range 0 to bclk_half_period_c-1 := 0; 
 
    -- Tracks the 32 bits of a full audio frame (Left + Right)
    signal bit_counter_r : 
        integer range 0 to 2*data_width_g := 0; 
 
    -- Active shift register for serial output
    signal data_r : 
        std_logic_vector(data_width_g-1 downto 0) := (others => '0'); 
 
    -- Holding register to cache right channel data while left channel transmits
    signal right_data_r : 
        std_logic_vector(data_width_g-1 downto 0) := (others => '0'); 
 
    -- Internal clock states
    signal bclk_r  : std_logic := '1'; 
    signal lrclk_r : std_logic := '0'; 
 
begin 
 
    -- Route internal registers to output ports. MSB is always sent first.
    aud_bclk_out  <= bclk_r; 
    aud_lrclk_out <= lrclk_r; 
    aud_data_out  <= data_r(data_width_g-1); 
 
    -- Single synchronous process driven by the main clock
    process(clk, rst_n) 
    begin 
        if rst_n = '0' then 
 
            bclk_counter_r <= 0; 
            bit_counter_r  <= 0; 
            bclk_r  <= '1'; 
            lrclk_r <= '0'; 
            data_r       <= (others => '0'); 
            right_data_r <= (others => '0'); 
        elsif rising_edge(clk) then 
 
                -- Wait for BCLK half-period to elapse
                if bclk_counter_r = bclk_half_period_c - 1 then 
 
                    bclk_counter_r <= 0; 
 
                    -- Execute data logic right before BCLK falls (falling edge operation)
                    if bclk_r = '1' then 
 
                        -- Start of a new 32-bit audio frame
                        if bit_counter_r = 0 
                           or bit_counter_r = 2*data_width_g then 
 
                            data_r       <= left_data_in;      -- Load left channel for immediate shift
                            right_data_r <= right_data_in;     -- Cache right channel for later
 
                            lrclk_r <= '1';                    -- Set Left-Right clock for Left channel
                            bit_counter_r <= 1; 
 
                        -- Shifting Left Channel (Bits 1 to 15)
                        elsif bit_counter_r < data_width_g then 
 
                            data_r <= 
                                data_r(data_width_g-2 downto 0) & '0'; -- Shift left, append '0'
 
                            bit_counter_r <= bit_counter_r + 1; 
 
                        -- Mid-frame transition: Load Right Channel
                        elsif bit_counter_r = data_width_g then 
 
                            data_r <= right_data_r;            -- Move cached right data into active shift register
                            lrclk_r <= '0';                    -- Set Left-Right clock for Right channel
 
                            bit_counter_r <= bit_counter_r + 1; 
 
                        -- Shifting Right Channel (Bits 17 to 31)
                        elsif bit_counter_r < 2*data_width_g then 
 
                            data_r <= 
                                data_r(data_width_g-2 downto 0) & '0'; -- Shift left, append '0'
 
                            bit_counter_r <= bit_counter_r + 1; 
 
                        end if; 
 
                    end if; 
 
                    -- Toggle BCLK state
                    bclk_r <= not bclk_r; 
 
                else 
                    -- Increment BCLK divider
                    bclk_counter_r <= bclk_counter_r + 1; 
 
                end if; 
 
        end if; 
    end process; 
 
end architecture rtl;
