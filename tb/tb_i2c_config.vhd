-------------------------------------------------------------------------------
-- File: tb_i2c_config.vhd
-- Course: COMP.CE.240 Logic Synthesis, Exercise 11
-- Author/group: Fill in according to the course header instructions.
-- Based on the supplied course template. ADDED/CHANGED mark modifications.
--
-- Simple functional test: receive/check all 15 configurations, deliberately
-- NACK each byte position once, then verify successful completion.
-- The template's SCL-gated SDA driver is retained as requested. This is a
-- functional codec model for our controller (which samples ACK during SCL-high),
-- not an electrical/timing compliance model. No timing monitor is included.
--
-- ModelSim:
--   vcom -check_synthesis -cover sbf i2c_config.vhd
--   vcom tb_i2c_config.vhd
--   vsim -coverage work.tb_i2c_config
--   run -all
--   coverage report -details
-- Measure the DUV's required 90% statement/branch and 100% state coverage.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;  -- ADDED: compare the unsigned status count

entity tb_i2c_config is
end tb_i2c_config;

architecture testbench of tb_i2c_config is
  constant n_params_c     : integer := 15;
  constant n_leds_c       : integer := 4;
  constant i2c_freq_c     : integer := 20000;
  constant ref_freq_c     : integer := 50000000;
  constant clock_period_c : time := 20 ns;
  constant n_bytes_c       : integer := 3;
  constant bit_count_max_c : integer := 8;

  -- ADDED: expected values from Exercise 10, independent of the DUV's table.
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

  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';
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
  -- ADDED: explicitly bind the template component to the compiled DUV.
  for i2c_config_1 : i2c_config use entity work.i2c_config;

  signal sdat         : std_logic := 'Z';
  signal sclk         : std_logic;
  signal param_status : std_logic_vector(n_leds_c-1 downto 0);
  signal finished     : std_logic;
  signal sdat_r       : std_logic;
  signal bit_counter_r  : integer range 0 to bit_count_max_c-1;
  signal byte_counter_r : integer range 0 to n_bytes_c-1;
  type states is (wait_start, read_byte, send_ack, wait_stop);
  signal curr_state_r : states;
  signal sdat_old_r, sclk_old_r : std_logic;

  -- ADDED: only the extra bookkeeping needed for receiving and retry testing.
  signal received_byte_r : byte_t;
  -- Number of successful transactions; also indexes the next expected entry.
  signal param_counter_r : natural range 0 to n_params_c := 0;
  -- 0/1/2 select the byte position to reject on successive attempts.
  -- Once this reaches 3, all remaining bytes receive ACK.
  signal nack_counter_r  : natural range 0 to 3 := 0;
  signal send_nack_r     : boolean;
  signal failed_r        : boolean;
  signal test_done : boolean := false;

begin
  -- CHANGED: stop the clock after PASS so run -all ends without a fake error.
  clk <= not clk after clock_period_c/2 when not test_done else '0';
  rst_n <= '1' after clock_period_c*4;

  -- ADDED: physical pull-up on the shield must be represented in simulation.
  -- This is a separate weak driver, not a second sequential assignment.
  sdat <= 'H';

  -- RETAINED from template: apply the codec response only while SCL is high.
  with sclk select
    sdat <= sdat_r when '1',
            'Z'    when others;

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

  fsm_proc : process(clk, rst_n)
    -- ADDED: normalize H to 1; byte_v lets us check the eighth bit immediately.
    -- A signal assignment would not update received_byte_r until later.
    variable sda_v  : std_logic;
    variable byte_v : byte_t;
  begin
    if rst_n = '0' then
      curr_state_r <= wait_start;
      sdat_old_r <= '0';
      sclk_old_r <= '0';
      byte_counter_r <= 0;
      bit_counter_r <= 0;
      sdat_r <= 'Z';
      -- ADDED: reset receiver data and test progress.
      received_byte_r <= (others => '0');
      param_counter_r <= 0;
      nack_counter_r <= 0;
      send_nack_r <= false;
      failed_r <= false;
    elsif rising_edge(clk) then
      sda_v := to_X01(sdat); -- CHANGED: recognizes the weak pull-up as high
      sclk_old_r <= sclk;
      sdat_old_r <= sda_v;

      -- Template ACK preparation on a detected falling edge.
      -- CHANGED: sometimes release for NACK instead of always returning ACK.
      if sclk = '0' and sclk_old_r = '1' then
        if curr_state_r = send_ack and not send_nack_r then
          sdat_r <= '0';
        else
          sdat_r <= 'Z';
        end if;
      end if;

      case curr_state_r is
        when wait_start =>
          if sclk = '1' and sclk_old_r = '1' and
             sdat_old_r = '1' and sda_v = '0' then
            -- ADDED: restart at byte 0 after every START, including retries.
            assert param_counter_r < n_params_c
              report "Unexpected transaction after all parameters" severity failure;
            assert unsigned(param_status) = to_unsigned(param_counter_r, n_leds_c)
              report "Status incorrect before START (check NACK handling)"
              severity failure;
            byte_counter_r <= 0;
            bit_counter_r <= 0;
            received_byte_r <= (others => '0');
            failed_r <= false;
            curr_state_r <= read_byte;
          end if;

        when read_byte =>
          if sclk = '1' and sclk_old_r = '0' then
            -- ADDED: assemble the actual SDA bits, MSB first.
            byte_v := received_byte_r(6 downto 0) & sda_v;
            received_byte_r <= byte_v;
            if bit_counter_r /= bit_count_max_c-1 then
              bit_counter_r <= bit_counter_r + 1;
            else
              -- ADDED: four independent checks of the received byte contents.
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
              -- ADDED: reject byte 0, then 1, then 2 of parameter 0 in three
              -- attempts. This exercises retries at every byte position.
              send_nack_r <= param_counter_r = 0 and nack_counter_r < 3
                            and byte_counter_r = nack_counter_r;
              bit_counter_r <= 0;
              curr_state_r <= send_ack;
            end if;
          end if;

        when send_ack =>
          if sclk = '1' and sclk_old_r = '0' then
            -- ADDED: NACK requires STOP immediately, not the next byte.
            if send_nack_r then
              report "NACK after byte " & integer'image(byte_counter_r) severity note;
              nack_counter_r <= nack_counter_r + 1;
              failed_r <= true;
              curr_state_r <= wait_stop;
            elsif byte_counter_r /= n_bytes_c-1 then
              byte_counter_r <= byte_counter_r + 1;
              curr_state_r <= read_byte;
            else
              curr_state_r <= wait_stop;
            end if;
          end if;

        when wait_stop =>
          if sclk = '1' and sclk_old_r = '1' and
             sdat_old_r = '0' and sda_v = '1' then
            -- ADDED: only a successful transaction advances the expectation.
            -- After NACK it stays unchanged, so the retry must send the same
            -- register/value and must start again with the device address.
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

  -- RETAINED template check: detect conflicting strong drivers.
  assert sdat /= 'X' report "Three state bus in state X" severity error;

  -- CHANGED: instead of reporting a failure just because finished went high,
  -- first check the result and report PASS. Allow two clk periods for sampled
  -- STOP bookkeeping to settle; no knowledge of DUV internal states is needed.
  completion_proc : process
  begin
    wait until rst_n = '1';
    wait until finished = '1';
    wait for 2 * clock_period_c;
    assert param_counter_r = n_params_c
      report "finished asserted before 15 successful configurations" severity failure;
    assert nack_counter_r = 3
      report "Not all three NACK cases were tested" severity failure;
    assert unsigned(param_status) = to_unsigned(n_params_c, n_leds_c)
      report "Final status must be 15" severity failure;
    assert curr_state_r = wait_start
      report "Final STOP missing" severity failure;
    -- ADDED: leave the clock running briefly so the DUV executes its DONE
    -- branch after its last internal delay; useful for the required coverage.
    wait for 1 sec / i2c_freq_c;
    report "PASS: 15 correct configurations and three NACK/retry cases" severity note;
    test_done <= true;
    wait;
  end process;

  -- ADDED: a small watchdog prevents endless simulation if the DUV gets stuck.
  watchdog_proc : process
  begin
    wait until test_done for 60 ms;
    assert test_done report "TIMEOUT: controller did not finish" severity failure;
    wait;
  end process;
end testbench;
