-------------------------------------------------------------------------------
-- Title      : COMP.CE.240, Exercise 11
-- Project    : I2C-bus controller testbench
-------------------------------------------------------------------------------
-- File       : tb_i2c_config.vhd
-- Author     : Quang Le, Tatu Nyberg
-- Company    : TAU
-- Edited     : 2026-10-09
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description:  Design a testbench for I2C-bus controller, which configures the  
--               DA7212 audio codec before the synthesizer begins to feed data to it.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description

-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; 

-------------------------------------------------------------------------------
-- Empty entity
-------------------------------------------------------------------------------

entity tb_i2c_config is
end tb_i2c_config;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture testbench of tb_i2c_config is
  -- Number of parameters to expect
  constant n_params_c     : integer := 15;
  constant n_leds_c       : integer := 4;
  constant i2c_freq_c     : integer := 20000;
  constant ref_freq_c     : integer := 50000000;
  constant clock_period_c : time := 20 ns;
  -- Every transmission consists several bytes and every byte contains given
  -- amount of bits.
  constant n_bytes_c       : integer := 3;
  constant bit_count_max_c : integer := 8;

  -- expected values from Exercise 10, independent of the DUV's table.
  subtype byte_t is std_logic_vector(7 downto 0);
  type config_entry_t is record
    reg_addr : byte_t;
    reg_data : byte_t;
  end record;
  type config_table_t is array (0 to n_params_c-1) of config_entry_t;
  constant expected_c : config_table_t := (
    (x"1D", x"80"), -- CIF_CTRL
    (x"27", x"04"), -- PLL_CTRL
    (x"22", x"0B"), -- SR
    (x"28", x"00"), -- DAI_CLK_MODE
    (x"29", x"81"), -- DAI_CTRL
    (x"69", x"08"), -- DAC_L_CTRL
    (x"6A", x"00"), -- DAC_R_CTRL
    (x"47", x"E1"), -- CP_CTRL
    (x"6B", x"09"), -- HP_L_CTRL
    (x"6C", x"08"), -- HP_R_CTRL
    (x"4B", x"08"), -- MIXOUT_L_SELECT
    (x"4C", x"08"), -- MIXOUT_R_SELECT
    (x"6E", x"88"), -- MIXOUT_L_CTRL
    (x"6F", x"88"), -- MIXOUT_R_CTRL
    (x"51", x"F1")  -- SYSTEM_MODES_OUTPUT
  );

  -- Signals fed to the DUV
  signal clk   : std_logic := '0';  -- Remember that default values supported
  signal rst_n : std_logic := '0';  -- only in synthesis
  -- The DUV prototype
  component i2c_config
    generic (
      ref_clk_freq_g : integer;
      i2c_freq_g     : integer;
      n_params_g     : integer;
      n_leds_g       : integer);
    port (
      clk              : in std_logic;
      rst_n            : in std_logic;
      sdat_inout       : inout std_logic;
      sclk_out         : out std_logic;
      param_status_out : out std_logic_vector(n_leds_g-1 downto 0);
      finished_out     : out std_logic);
  end component;
  -- explicitly bind the template component to the compiled DUV.
  for i2c_config_1 : i2c_config use entity work.i2c_config;

  -- Signals coming from the DUV
  signal sdat         : std_logic := 'Z';
  signal sclk         : std_logic;
  signal param_status : std_logic_vector(n_leds_c-1 downto 0);
  signal finished     : std_logic;
  -- To hold the value that will be driven to sdat when sclk is high.
  signal sdat_r       : std_logic;
  -- Counters for receiving bits and bytes
  signal bit_counter_r  : integer range 0 to bit_count_max_c-1;
  signal byte_counter_r : integer range 0 to n_bytes_c-1;
  -- States for the FSM
  type states is (wait_start, read_byte, send_ack, wait_stop);
  signal curr_state_r : states;
  -- Previous values of the I2C signals for edge detection
  signal sdat_old_r, sclk_old_r : std_logic;

  --  only the extra bookkeeping needed for receiving and retry testing.
  signal received_byte_r : byte_t;
  -- Number of successful transactions; also indexes the next expected entry.
  signal param_counter_r : natural range 0 to n_params_c := 0;
  -- 0/1/2 select the byte position to reject on successive attempts.
  -- Once this reaches 3, all remaining bytes receive ACK.
  signal nack_counter_r  : natural range 0 to 3 := 0;
  signal send_nack_r     : boolean;
  signal failed_r        : boolean;

begin
  -- stop the clock after PASS so run -all ends without a fake error.
  clk <= not clk after clock_period_c/2;
  rst_n <= '1' after clock_period_c*4;

  -- physical pull-up on the shield must be represented in simulation.
  sdat <= 'H';

  -- Assign sdat_r when sclk is active, otherwise 'Z'.
  -- Note that sdat_r is usually 'Z'
  with sclk select
    sdat <= sdat_r when '1',
            'Z'    when others;

  -- Component instantiation
  i2c_config_1 : i2c_config
    generic map (
      ref_clk_freq_g => ref_freq_c,
      i2c_freq_g => i2c_freq_c,
      n_params_g => n_params_c,
      n_leds_g => n_leds_c)
    port map (
      clk => clk, rst_n => rst_n,
      sdat_inout => sdat, sclk_out => sclk,
      param_status_out => param_status, finished_out => finished);

  -----------------------------------------------------------------------------
  -- The main process that controls the behavior of the test bench
  fsm_proc : process(clk, rst_n)
    -- normalize H to 1; byte_v lets us check the eighth bit immediately.
    -- A signal assignment would not update received_byte_r until later.
    variable sda_v  : std_logic;
    variable byte_v : byte_t;
  begin
    if rst_n = '0' then                 -- asynchronous reset (active low)
      curr_state_r <= wait_start;
      sdat_old_r <= '0';
      sclk_old_r <= '0';
      byte_counter_r <= 0;
      bit_counter_r <= 0;
      sdat_r <= 'Z';
      --reset receiver data and test progress.
      received_byte_r <= (others => '0');
      param_counter_r <= 0;
      nack_counter_r <= 0;
      send_nack_r <= false;
      failed_r <= false;
    elsif rising_edge(clk) then         -- rising clock edge
      sda_v := to_X01(sdat); -- recognizes the weak pull-up as high
      -- The previous values are required for the edge detection
      sclk_old_r <= sclk;
      sdat_old_r <= sda_v;


      -- Falling edge detection for acknowledge control
      -- Must be done on the falling edge in order to be stable during
      -- the high period of sclk
      if sclk = '0' and sclk_old_r = '1' then
        -- If we are supposed to send ack
        if curr_state_r = send_ack and not send_nack_r then
          -- Send ack (low = ACK, high = NACK)
          sdat_r <= '0';
        else
          -- Otherwise, sdat is in high impedance state.
          sdat_r <= 'Z';
        end if;
      end if;

      -------------------------------------------------------------------------
      -- FSM
      case curr_state_r is
        -----------------------------------------------------------------------
        -- Wait for the start condition
        when wait_start =>
          -- While clk stays high, the sdat falls
          if sclk = '1' and sclk_old_r = '1' and
             sdat_old_r = '1' and sda_v = '0' then
            -- restart at byte 0 after every START, including retries.
            assert unsigned(param_status) = to_unsigned(param_counter_r, n_leds_c)
              report "Status incorrect before START (check NACK handling)"
              severity failure;
            byte_counter_r <= 0;
            bit_counter_r <= 0;
            received_byte_r <= (others => '0');
            failed_r <= false;
            curr_state_r <= read_byte;
          end if;

        -----------------------------------------------------------------------
        -- Wait for a byte to be read
        when read_byte =>
          -- Detect a rising edge
          if sclk = '1' and sclk_old_r = '0' then
            -- assemble the actual SDA bits, MSB first.
            byte_v := received_byte_r(6 downto 0) & sda_v;
            received_byte_r <= byte_v;
            if bit_counter_r /= bit_count_max_c-1 then
              -- Normally just receive a bit
              bit_counter_r <= bit_counter_r + 1;
            else
              -- four independent checks of the received byte contents.
              case byte_counter_r is
                when 0 =>
                  assert byte_v(7 downto 1) = "0011010"
                    report "Wrong device address" severity failure;
                  assert byte_v(0) = '0'
                    report "R/W bit must be 0 (write)" severity failure;
                when 1 =>
                  assert byte_v = expected_c(param_counter_r).reg_addr
                    report "Wrong register address at parameter " &
                      integer'image(param_counter_r) severity failure;
                when 2 =>
                  assert byte_v = expected_c(param_counter_r).reg_data
                    report "Wrong register data at parameter " &
                      integer'image(param_counter_r) severity failure;
              end case;
              --reject byte 0, then 1, then 2 of parameter 0 in three
              -- attempts. This exercises retries at every byte position.
              send_nack_r <= param_counter_r = 0 and nack_counter_r < 3
                            and byte_counter_r = nack_counter_r;
              -- When terminal count is reached, let's send the ack
              bit_counter_r <= 0;
              curr_state_r <= send_ack;
            end if;
          end if;

        -----------------------------------------------------------------------
        -- Send acknowledge
        when send_ack =>
          -- Detect a rising edge
          if sclk = '1' and sclk_old_r = '0' then
            -- NACK requires STOP immediately, not the next byte.
            if send_nack_r then
              report "NACK after byte " & integer'image(byte_counter_r) severity note;
              nack_counter_r <= nack_counter_r + 1;
              failed_r <= true;
              curr_state_r <= wait_stop;
            elsif byte_counter_r /= n_bytes_c-1 then
              -- Transmission continues
              byte_counter_r <= byte_counter_r + 1;
              curr_state_r <= read_byte;
            else
              curr_state_r <= wait_stop;
            end if;
          end if;

        -----------------------------------------------------------------------
        -- Wait for the stop condition
        when wait_stop =>
          -- Stop condition detection: sdat rises while sclk stays high
          if sclk = '1' and sclk_old_r = '1' and
             sdat_old_r = '0' and sda_v = '1' then
            --only a successful transaction advances the expectation.
            -- After NACK it stays unchanged, so the retry must send the same
            -- value and must start again with the device address.
            if not failed_r then
              param_counter_r <= param_counter_r + 1;
              report "Received parameter " & integer'image(param_counter_r + 1)
                severity note;
            end if;
            curr_state_r <= wait_start;
          end if;
      end case;
    end if;
  end process;

  --detect conflicting strong drivers.
  -----------------------------------------------------------------------------
  -- Asserts for verification
  -----------------------------------------------------------------------------

  -- SDAT should never contain X:s.
  assert sdat /= 'X' report "Three state bus in state X" severity error;

  completion_proc : process
  begin
    wait until rst_n = '1';
    wait until finished = '1';

    -- all parameters must be sent before finished go high
    assert param_counter_r = n_params_c
      report "finished asserted before 15 successful configurations" severity failure;

    -- make sure that we have delivered our expected number of nack
    assert nack_counter_r = 3
      report "Not all three NACK cases were tested" severity failure;

    -- Final status must be 15
    assert unsigned(param_status) = to_unsigned(n_params_c, n_leds_c)
      report "Final status must be 15" severity failure;
  end process;

    -- End of simulation, but not during the reset
  assert finished = '0' or rst_n = '0' report
    "Simulation done" severity failure;
end testbench;
