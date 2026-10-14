-------------------------------------------------------------------------------
-- Title      : COMP.CE.240, Exercise 05
-- Project    : Triangular Wave Generator
-------------------------------------------------------------------------------
-- File       : wave_gen.vhd
-- Author     : Quang Le, Tatu Nyberg
-- Company    : TAU
-- Edited     : 2026-09-09
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Implementing a parameterizable triangular wave generator 
--              using a bidirectional step counter.
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
        -- Defines the bit width of the output signal
        width_g : INTEGER;
        -- Defines the step size for each clock cycle increment/decrement
        step_g  : INTEGER
    );

    port (
        clk             : IN STD_LOGIC;  -- System clock
        rst_n           : IN STD_LOGIC;  -- Active-low asynchronous reset
        sync_clear_n_in : IN STD_LOGIC;  -- Active-low synchronous clear signal
        value_out       : OUT STD_LOGIC_VECTOR(width_g - 1 DOWNTO 0)
    );
end wave_gen;

architecture functionality of wave_gen is

    -- Tracks the current counting direction ('1' for counting up, '0' for counting down)
    signal direction : STD_LOGIC := '1';
    
    -- Internal signed counter. It is sized to match width_g and initialized to zero.
    signal out_value : signed(width_g - 1 downto 0) := (others => '0');
    
    -- Calculate the exact peak values. 
    -- VHDL integer division automatically rounds downwards (floors) the result, 
    -- which ensures the counter will land exactly on these limits without overflowing.
    constant max_val_c : integer := ((2**(width_g - 1) - 1) / step_g) * step_g;
    constant min_val_c : integer := -max_val_c;
    
begin

    -- Synchronous process for handling the bidirectional counting
    process(clk, rst_n)
    begin
        -- Asynchronous reset: Immediately resets the counter and sets direction to upwards
        if rst_n = '0' then
            direction <= '1';
            out_value <= (others => '0');
            
        -- Synchronous actions occur on the rising edge of the clock
        elsif clk'event and clk = '1' then
            
            -- Synchronous clear: Forces output to 0 and resets direction to upwards 
            -- without needing to be in the process sensitivity list
            if sync_clear_n_in = '0' then
                direction <= '1';
                out_value <= (others => '0');
            else
                
                -- Counting Upwards Logic
                if direction = '1' then
                    -- Using exact equality (=) saves hardware area compared to relative (>=) checks
                    if (out_value = max_val_c) then
                        direction <= '0';                -- Reached the peak, turn around
                        out_value <= out_value - step_g; -- Start stepping down
                    else
                        out_value <= out_value + step_g; -- Continue stepping up
                    end if;
                    
                -- Counting Downwards Logic
                else
                    if (out_value = min_val_c) then
                        direction <= '1';                -- Reached the trough, turn around
                        out_value <= out_value + step_g; -- Start stepping up
                    else
                        out_value <= out_value - step_g; -- Continue stepping down
                    end if;
                end if;
                
            end if;
        end if;
    end process;
    
    -- Concurrent assignment to cast the internal signed counter to the STD_LOGIC_VECTOR output port
    value_out <= std_logic_vector(out_value);
    
end functionality;