-------------------------------------------------------------------------------
-- Title      : COMP.CE.240, Exercise 04
-- Project    : 
-------------------------------------------------------------------------------
-- File       : tb_multi_port_adder.vhd
-- Author     : Quang Le, Tatu Nyberg
-- Company    : TAU
-- Edited     : 2026-09-09
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Testbench for Multi-Port Adder
-- Reads input stimuli from a text file, feeds them to the Design Under 
-- Verification (DUV), compares the output against a reference file, and 
-- logs the final outputs to a text file
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description

-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.txtio_pkg.all;
entity tb_multi_port_adder is
  -- The entity has no ports because it is a top-level testbench.
  generic (
    operand_width_g : integer := 3
  );
end tb_multi_port_adder;
---------------------------------------------------------------------------
architecture testbench of tb_multi_port_adder is
  
  -- Configuration constants for the test dimensions
  constant number_of_operands_c : integer :=  4;
  constant num_of_test_vecs_c   : integer := 25;
  constant num_of_input_elems_c : integer := (number_of_operands_c * num_of_test_vecs_c);

  -- Timing and pipeline delay configuration
  constant clk_period_c : time := 10 ns;
  constant duv_delay_c  : integer := 2; -- Compensates for the 2-cycle delay in the DUV
    
  -- File paths for I/O operations
  constant input_file_c  : string := "input.txt";
  constant ref_file_c    : string := "ref_results.txt";
  constant output_file_c : string := "output.txt";

  -- Initialize constant arrays by reading the text files at compile time.
  -- txt_io_read returns a flat integer vector containing all rows.
  constant input_vec_c : integer_vector_t(num_of_input_elems_c-1 downto 0) := 
    txt_io_read(input_file_c, number_of_operands_c, num_of_test_vecs_c, true);
  
  constant ref_vec_c : integer_vector_t(num_of_test_vecs_c-1 downto 0) := 
    txt_io_read(ref_file_c, 1, num_of_test_vecs_c, true);

  -- Internal signals to connect the testbench to the DUV
  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';
  signal operands_r : std_logic_vector(operand_width_g * number_of_operands_c -1 downto 0);
  signal sum   : std_logic_vector(operand_width_g-1 downto 0);
  
  -- Shift register used to track when valid data emerges from the DUV pipeline
  signal output_valid_r : std_logic_vector(duv_delay_c downto 0);

  -- Component declaration for the Design Under Verification (DUV)
  component multi_port_adder 
    generic (
        operand_width_g   : INTEGER := 16;
        num_of_operands_g : integer := 4
    );
    port (
        clk         : IN STD_LOGIC;
        rst_n       : IN STD_LOGIC;
        operands_in : IN STD_LOGIC_VECTOR(operand_width_g * num_of_operands_g -1 DOWNTO 0);
        sum_out     : OUT STD_LOGIC_VECTOR(operand_width_g-1 DOWNTO 0)
    );
  end component multi_port_adder;

begin
  
  -- Generates a continuous clock signal oscillating at clk_period_c
  clk_gen : process (clk)
  begin
    clk <= not clk after clk_period_c/2;
  end process clk_gen;

  -- Deactivate the active-low reset after 2 clock cycles to start the system
  rst_n <= '1' after clk_period_c*2;

  -- Instantiate the DUV and map the testbench signals to its ports
  multi_port_adder1 : multi_port_adder
    generic map (
        operand_width_g   => operand_width_g,
        num_of_operands_g => number_of_operands_c
    )
    port map (
        clk         => clk,
        rst_n       => rst_n,
        operands_in => operands_r,
        sum_out     => sum
    );

  -- Reads integers from the flat input vector, converts them to standard logic vectors,
  -- and feeds them to the DUV cycle by cycle.
  input_reader : process (clk, rst_n)
    variable row_operand_v : integer_vector_t(number_of_operands_c-1 downto 0);
    variable row_idx_v     : integer := 0;
  begin
      if rst_n = '0' then 
        operands_r     <= (others => '0');
        output_valid_r <= (others => '0');
      elsif clk'event and clk = '1' then
        
        -- Shift the valid pipeline to track data delay through the adder
        output_valid_r(duv_delay_c downto 1) <= output_valid_r(duv_delay_c-1 downto 0);
        
        -- While there are still test vectors to process...
        -- We don't use a while loop, because we want to process only one input row per clock cycle.
        -- A while loop would process all the 25 rows during the same clock cycle.
        if(row_idx_v /= num_of_test_vecs_c) then
          output_valid_r(0) <= '1'; -- Push '1' to indicate valid data is entering the DUV
          
          -- Extract the current row of integers from the flat array
          row_operand_v := input_vec_c((row_idx_v * number_of_operands_c+3) downto row_idx_v * number_of_operands_c);
          
          -- Convert each integer to signed standard logic and pack it into the wide input bus
          for i in 0 to (number_of_operands_c - 1) loop
            operands_r((i+1)*operand_width_g -1 downto i * operand_width_g) <= std_logic_vector(to_signed(row_operand_v(i),operand_width_g));
          end loop;
          
          row_idx_v := row_idx_v + 1;
        else
          -- Stop pushing valid flags once all vectors are read
          output_valid_r(0) <= '0';
        end if;
      end if;
  end process;

  -- Checks the DUV output against the reference values and writes the final results to a file.
  checker : process (clk)
    variable output_vec_v  : integer_vector_t(num_of_test_vecs_c-1 downto 0);
    variable ref_row_idx_v : integer := 0;
  begin
      if clk'event and clk = '1' then
        -- Wait until the valid flag has traversed the delay pipeline before checking
        if output_valid_r(duv_delay_c) = '1' then

          -- Similar to the input_reader we didn't use a while loop here.  
          if ref_row_idx_v /= num_of_test_vecs_c then
            -- Verify that the adder's output matches the expected reference result
            assert ref_vec_c(ref_row_idx_v) = to_integer(signed(sum))
              report "Mismatch!"
              severity error;
            
            -- Store the converted output into the array for later logging
            output_vec_v(ref_row_idx_v) := to_integer(signed(sum));
            ref_row_idx_v := ref_row_idx_v + 1;
          end if;
          
          -- Once all rows have been checked, log the results and stop the simulation
          if ref_row_idx_v = num_of_test_vecs_c then
            txt_io_write(output_file_c, output_vec_v, true);
            assert false 
              report "Simulation done"
              severity failure;
          end if;
          
        end if;
      end if;
  end process;
end architecture testbench;