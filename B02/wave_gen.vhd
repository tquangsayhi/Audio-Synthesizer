-------------------------------------------------------------------------------
-- Title      : COMP.CE.240, Bonus Exercise 02
-- Project    : Sine Wave Generator
-------------------------------------------------------------------------------
-- File       : wave_gen.vhd
-- Author     : Quang Le, Tatu Nyberg
-- Company    : TAU
-- Edited     : 2026-09-28
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Synthesizable sine wave generator using the Semi-implicit 
--              Euler method. Replaces the linear 
--              triangle wave with a digital harmonic oscillator.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description

-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wave_gen is
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
end wave_gen;

architecture sine_generator of wave_gen is
    
    -- Divisor to scale the integer math. A power of 2 (256) ensures the 
    -- synthesizer optimizes the division into a zero-cost arithmetic right-shift.
    constant scale_factor : integer := 256; 
    
    -- Maximum positive amplitude for an N-bit signed integer (Amplitude = 1)
    constant max_val_c : integer := ((2**(width_g - 1) - 1) * 7) / 8;
    
    -- Sine (s) and Cosine (c) registers
    signal s : signed(width_g - 1 downto 0) := (others => '0');
    signal c : signed(width_g - 1 downto 0) := to_signed(max_val_c, width_g);
    
    -- Intermediate combinational signal to hold the calculated next sine value
    signal s_next : signed(width_g - 1 downto 0);

    constant step_s : signed(width_g - 1 downto 0) := to_signed(step_g, width_g);

begin

    -- Combinational logic for the new Sine value.
    -- We use the resize() function to ensure VHDL's strict typing allows the 
    -- multiplied and divided integer to fit back into the width_g register.

    s_next <= s + resize((c * step_s) / scale_factor, width_g);

    -- Synchronous Register Updates
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            -- Asynchronous Reset: Phase 0 (Sine = 0, Cosine = Max)
            s <= (others => '0');
            c <= to_signed(max_val_c, width_g);
            
        elsif rising_edge(clk) then 
            
            if sync_clear_n_in = '0' then 
                -- Synchronous Clear from Push Buttons
                s <= (others => '0');
                c <= to_signed(max_val_c, width_g);
            else 
                -- Update sine register
                s <= s_next;
                
                -- Update cosine register using the newly calculated s_next
                c <= c - resize((s_next * step_s) / scale_factor, width_g);
            end if;
            
        end if;
    end process;
    
    -- Route the stabilized sine wave to the output port
    value_out <= std_logic_vector(resize(s, width_g));

end sine_generator;