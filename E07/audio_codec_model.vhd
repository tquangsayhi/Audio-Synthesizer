-------------------------------------------------------------------------------
-- Title      : Audio Codec Model
-- Project    : 
-------------------------------------------------------------------------------
-- File       : audio_codec_model.vhd
-- Author     : Quang Le, Tatu Nyberg
-- Company    : TAU
-- Last update: 2026-09-21
-- Platform   : 
-------------------------------------------------------------------------------
-- Description: Models Renesas's audio chip in order to test serial transmission
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  	 Description
-- ????/12/22  1.0      Rasmusa 	 Created
-- 2026/05/27  2.0		Sakari Lahti Modified into a handout for students	
-- 2026/09/21  3.0    Quang Le & Tatu Nyberg Completed the assignment
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity audio_codec_model is

  generic (
    data_width_g : integer := 16);

  port (
    rst_n           : in  std_logic;
    aud_bclk_in     : in  std_logic;
    aud_lrclk_in    : in  std_logic;
    aud_data_in     : in  std_logic;
    value_left_out  : out std_logic_vector(data_width_g-1 downto 0);
    value_right_out : out std_logic_vector(data_width_g-1 downto 0)
    );

end audio_codec_model;

architecture behavioral of audio_codec_model is

  -- FSM states: Wait for the first valid frame, then alternate reading left and right channels
  type state_type is (wait_for_input, read_left, read_right);
  signal current_state : state_type;
  
  -- Counter to track the number of bits shifted in per channel (guarded to prevent overflow)
  signal lrclk_cnt: integer range 0 to data_width_g;
  
  -- Internal shift registers to assemble the incoming serial audio data bit-by-bit
  signal left_reg  : std_logic_vector(data_width_g - 1 downto 0);
  signal right_reg : std_logic_vector(data_width_g - 1 downto 0);

begin  -- rtl

  -- The FSM is clocked by the incoming bit clock from the audio controller
  fsm : process (aud_bclk_in, rst_n) 
  begin  
    if rst_n = '0' then 

      -- Asynchronous reset: clear outputs, clear shift registers, reset counters, and go to wait state
      value_left_out <= (others => '0');
      value_right_out <= (others => '0');
      left_reg <= (others => '0');
      right_reg <= (others => '0');
      lrclk_cnt <= 0;
      current_state <= wait_for_input;

    elsif aud_bclk_in'event and aud_bclk_in = '1' then  
      
      case current_state is

        -------------------------------------------------------------------------------
        when wait_for_input =>
        -------------------------------------------------------------------------------
          
          -- Wait until the left-right clock goes high, signaling the start of the first left channel frame
          if (aud_lrclk_in = '1') then
            current_state <= read_left;
            -- Capture the very first MSB into the shift register
            left_reg(data_width_g - 1) <= aud_data_in;
            lrclk_cnt <= 1;
          end if; 

        -------------------------------------------------------------------------------
        when read_left =>
        -------------------------------------------------------------------------------
          
          -- Check if the channel has switched to the right channel (aud_lrclk_in goes low)
          if (aud_lrclk_in = '0') then
            -- Snapshot: output the fully assembled 16-bit left channel data all at once
            value_left_out <= left_reg;
            
            -- Transition to reading the right channel and capture its first bit
            current_state <= read_right;
            lrclk_cnt <= 1;
            right_reg(data_width_g - 1) <= aud_data_in;
            
          else 
            -- Guard condition: only shift in data if we haven't exceeded the 16-bit data width.
            -- This prevents delta-cycle crashes from trailing padding clocks.
            if lrclk_cnt < data_width_g then
              left_reg(data_width_g - 1 - lrclk_cnt) <= aud_data_in;
              lrclk_cnt <= lrclk_cnt + 1;
            end if;
          end if;
          
        -------------------------------------------------------------------------------
        when read_right =>
        -------------------------------------------------------------------------------
    
          -- Check if the channel has switched back to the left channel (aud_lrclk_in goes high)
          if (aud_lrclk_in = '1') then
            -- Snapshot: output the fully assembled 16-bit right channel data all at once
            value_right_out <= right_reg;
            
            -- Transition to reading the left channel and capture its first bit
            current_state <= read_left;
            lrclk_cnt <= 1;
            left_reg(data_width_g - 1) <= aud_data_in;
            
          else 
            -- Guard condition: ignore extra clock cycles after the 16th bit
            if lrclk_cnt < data_width_g then
              right_reg(data_width_g - 1 - lrclk_cnt) <= aud_data_in;
              lrclk_cnt <= lrclk_cnt + 1;
            end if;
          end if;

      end case;

    end if;
  end process fsm;

end behavioral;