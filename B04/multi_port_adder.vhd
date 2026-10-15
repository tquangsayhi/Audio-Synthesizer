-------------------------------------------------------------------------------
-- Title      : COMP.CE.240, Exercise Bonus 4 
-- Project    : 
-------------------------------------------------------------------------------
-- File       : multi_port_adder.vhd
-- Author     : Quang Le, Tatu Nyberg
-- Company    : TAU
-- Edited     : 2026-10-15
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Implementing a multi-port adder that has its overflow corrected.
-- THE ONLY LINE CHANGED WAS LINE 115
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description

-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity multi_port_adder is
    generic (
        -- Defines the bit width of a single input operand
        operand_width_g : INTEGER := 16;
        -- Defines the number of operands (hardcoded to 4 in this architecture)
        num_of_operands_g : integer := 4
    );
    port (
        clk         : IN STD_LOGIC;  -- System clock
        rst_n       : IN STD_LOGIC;  -- Active-low asynchronous reset
        operands_in : IN STD_LOGIC_VECTOR(operand_width_g * num_of_operands_g -1 DOWNTO 0);
        sum_out     : OUT STD_LOGIC_VECTOR(operand_width_g-1 DOWNTO 0)
    );
end multi_port_adder;

architecture structural of multi_port_adder is

    -- Declaration of the basic 2-input adder component used to build the tree
    component adder
    generic (
        -- Defines the bit width of the input operands for this specific adder
        operand_width_g : INTEGER
    );
    port (
        clk     : IN STD_LOGIC;
        rst_n   : IN STD_LOGIC;
        a_in    : IN STD_LOGIC_VECTOR((operand_width_g-1) DOWNTO 0);
        b_in    : IN STD_LOGIC_VECTOR((operand_width_g-1) DOWNTO 0);
        sum_out : OUT STD_LOGIC_VECTOR(operand_width_g DOWNTO 0)
    );
    end component adder;

    -- Custom array type to hold the intermediate sums from the first stage of the adder tree
    TYPE subtotal_type is array (0 to (num_of_operands_g/2 -1)) of STD_LOGIC_VECTOR(operand_width_g downto 0);
    
    -- Signals to route data between the structural components
    signal subtotal : subtotal_type;                                -- Holds results from adder1 and adder2
    signal total    : STD_LOGIC_VECTOR(operand_width_g+1 downto 0); -- Holds the final result from adder3 (2 bits wider than base)

begin

    -- First stage of the adder tree: Adds operand 0 and operand 1
    adder1 : adder
    generic map (
        operand_width_g => operand_width_g
    )
    port map (
        clk     => clk,
        rst_n   => rst_n,
        -- Slice the first operand (bits 0 to width-1)
        a_in    => operands_in(operand_width_g-1 DOWNTO 0),
        -- Slice the second operand (bits width to 2*width-1)
        b_in    => operands_in(2*operand_width_g -1 DOWNTO operand_width_g),
        -- Store the result in index 0 of the intermediate array
        sum_out => subtotal(0)
    );

    -- First stage of the adder tree: Adds operand 2 and operand 3
    adder2 : adder
    generic map (
        operand_width_g => operand_width_g
    )
    port map (
        clk     => clk,
        rst_n   => rst_n,
        -- Slice the third operand
        a_in    => operands_in(3*operand_width_g-1 DOWNTO 2*operand_width_g),
        -- Slice the fourth operand
        b_in    => operands_in(4*operand_width_g -1 DOWNTO 3*operand_width_g),
        -- Store the result in index 1 of the intermediate array
        sum_out => subtotal(1)
    );

    -- Second stage of the adder tree: Adds the two subtotals together
    adder3 : adder
    generic map (
        -- The generic is increased by 1 because the inputs (subtotal) are 1 bit wider 
        -- than the original operands due to the first stage addition
        operand_width_g => operand_width_g + 1
    )
    port map (
        clk     => clk,
        rst_n   => rst_n,
        a_in    => subtotal(0),
        b_in    => subtotal(1),
        -- Output is now original width + 2 bits
        sum_out => total
    );
    -- The only line that was changed
    -- Scale the full sum by 4 so four waves fit in the output width.
    sum_out <= total(operand_width_g + 1 DOWNTO 2);

    -- Design constraint check: This structural code hardcodes exactly three adders 
    -- in a tree, which only works for exactly 4 operands. If the generic is changed 
    -- in the top-level testbench, this halts compilation/simulation to prevent silent failures.
    assert(num_of_operands_g = 4)
        report "Error: num_of_operands_g must be 4. "
        severity failure;
        
end structural;