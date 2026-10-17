-------------------------------------------------------------------------------
-- Title      : COMP.CE.240, Exercise 02 (or 03/04 depending on your progress)
-- Project    : 
-------------------------------------------------------------------------------
-- File       : multi_port_adder.vhd
-- Author     : Quang Le, Tatu Nyberg
-- Company    : TAU
-- Edited     : 2026-23-9
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Implementing a multi-port adder that sums four parameterizable 
--              input values using a structural tree of 2-input adders.
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
        -- Defines the number of operands and can be any 2^n value
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
    
    -- One big array holding all N inputs and N-1 intermediate sums
    type tree_array_t is array (0 to 2*num_of_operands_g - 2) of std_logic_vector(operand_width_g - 1 downto 0);
    signal tree_data : tree_array_t;

    -- Intermediate signal array to catch the 1-bit wider output from the adder components
    type sum_array_t is array (0 to num_of_operands_g - 2) of std_logic_vector(operand_width_g downto 0);
    signal sum_data : sum_array_t;

begin

    -- Unpack the flattened input vector into the first N indices of the tree array
    gen_inputs: for i in 0 to num_of_operands_g - 1 generate
        tree_data(i) <= operands_in((i + 1) * operand_width_g - 1 downto i * operand_width_g);
    end generate gen_inputs;

    -- Generate the dynamic tree of adders
    gen_adders: for i in 0 to num_of_operands_g - 2 generate
        
        adder_inst : adder 
            GENERIC MAP (
                operand_width_g => operand_width_g
            )
            PORT MAP (
                clk     => clk,
                rst_n   => rst_n,
                -- Adders read from successive indices: 2*i and 2*i + 1
                a_in    => tree_data(2 * i),
                b_in    => tree_data(2 * i + 1),
                sum_out => sum_data(i)
            );
            
        -- Write results to the bigger index (N + i) while cutting the overflow bit to fit the array
        tree_data(num_of_operands_g + i) <= sum_data(i)(operand_width_g - 1 downto 0);
        
    end generate gen_adders;

    -- The final result is always located at the very last index of the tree
    sum_out <= tree_data(2*num_of_operands_g - 2);


        
end structural;