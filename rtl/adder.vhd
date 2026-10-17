-------------------------------------------------------------------------------
-- Title      : COMP.CE.240, Exercise 02
-- Project    : 
-------------------------------------------------------------------------------
-- File       : adder.vhd
-- Author     : Quang Le, Tatu Nyberg
-- Company    : TAU
-- Edited     : 2026-09-2
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Implementing an adder that summs two 8-bit values
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description

-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adder is 
    generic (
        -- Defines the bit width of the input operands
        operand_width_g : INTEGER
    );

    port (
        clk : IN STD_LOGIC;
        rst_n : IN STD_LOGIC;
        a_in : IN STD_LOGIC_VECTOR((operand_width_g-1) DOWNTO 0);
        b_in : IN STD_LOGIC_VECTOR((operand_width_g-1) DOWNTO 0);
        sum_out : OUT STD_LOGIC_VECTOR(operand_width_g DOWNTO 0)
    );

end adder;

architecture rtl of adder is
    -- Internal register to hold the calculated sum, sized to prevent overflow
    signal sum_r : signed(operand_width_g DOWNTO 0);
begin
    PROCESS(clk, rst_n)
    begin
        if (rst_n = '0') then
            -- Reset the internal sum register to all zeros asynchronously
            sum_r <= (others => '0');
        elsif (clk'event and clk = '1') then
            -- Convers inputs to signed, resize to n+1 bits to avoid overflow, and add them synchronously
            sum_r <= resize(signed(a_in), operand_width_g + 1) + resize(signed(b_in), operand_width_g + 1);
        end if;
    END PROCESS;
    -- Convert the internal signed register back to std_logic_vector for the output port
    sum_out <= STD_LOGIC_VECTOR(sum_r);
end rtl;