-------------------------------------------------------------------------------
-- Title      : COMP.CE.240, Exercise 10
-- Project    : I2C-bus controller
-------------------------------------------------------------------------------
-- File       : i2c_config.vhd
-- Author     : Quang Le, Tatu Nyberg
-- Company    : TAU
-- Edited     : 2026-10-08
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description:  I2C-bus controller, which configures the DA7212 audio codec 
--               before the synthesizer begins to feed data to it.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description

-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_config is
  generic (
    ref_clk_freq_g : integer := 50_000_000;
    i2c_freq_g     : integer := 20_000;
    n_params_g     : integer := 15;
    n_leds_g       : integer := 4
  );
  port (
    clk              : in    std_logic;
    rst_n            : in    std_logic;
    sdat_inout       : inout std_logic;
    sclk_out         : out   std_logic;
    param_status_out : out   std_logic_vector(n_leds_g - 1 downto 0);
    finished_out     : out   std_logic
  );
end entity i2c_config;

architecture rtl of i2c_config is

  subtype byte_t is std_logic_vector(7 downto 0);
  type config_entry_t is record
    reg_addr : byte_t;
    reg_data : byte_t;
  end record;
  type config_table_t is array (natural range <>) of config_entry_t;

  -- Assignment order is significant: the first write resets the codec.
  constant config_c : config_table_t(0 to 14) := (
     0 => (reg_addr => x"1D", reg_data => x"80"), -- CIF_CTRL
     1 => (reg_addr => x"27", reg_data => x"04"), -- PLL_CTRL
     2 => (reg_addr => x"22", reg_data => x"0B"), -- SR: 48 kHz
     3 => (reg_addr => x"28", reg_data => x"00"), -- DAI_CLK_MODE
     4 => (reg_addr => x"29", reg_data => x"81"), -- DAI_CTRL
     5 => (reg_addr => x"69", reg_data => x"08"), -- DAC_L_CTRL
     6 => (reg_addr => x"6A", reg_data => x"00"), -- DAC_R_CTRL
     7 => (reg_addr => x"47", reg_data => x"E1"), -- CP_CTRL
     8 => (reg_addr => x"6B", reg_data => x"09"), -- HP_L_CTRL
     9 => (reg_addr => x"6C", reg_data => x"08"), -- HP_R_CTRL
    10 => (reg_addr => x"4B", reg_data => x"08"), -- MIXOUT_L_SELECT
    11 => (reg_addr => x"4C", reg_data => x"08"), -- MIXOUT_R_SELECT
    12 => (reg_addr => x"6E", reg_data => x"88"), -- MIXOUT_L_CTRL
    13 => (reg_addr => x"6F", reg_data => x"88"), -- MIXOUT_R_CTRL
    14 => (reg_addr => x"51", reg_data => x"F1")  -- SYSTEM_MODES_OUTPUT
  );
  -- DAI_CTRL = enable | output off | normal | stereo | 16-bit | left justified
  --                 1 |          0 |      0 |      0 |     00 | 01 = x"81"
  constant device_write_c : byte_t := "0011010" & '0';

  -- Round the period UP so SCL never exceeds the requested frequency.
  constant period_cycles_c : positive :=
    (ref_clk_freq_g + i2c_freq_g - 1) / i2c_freq_g;
  constant low_cycles_c : positive := (period_cycles_c + 1) / 2;
  constant high_cycles_c : positive := period_cycles_c - low_cycles_c;
  constant high_first_c : positive := high_cycles_c / 2;
  constant high_second_c : positive := high_cycles_c - high_first_c;

  -- Four phases, but deliberately NOT four equal intervals:
  -- 0: SCL falls; hold previous SDA for approximately 1 us.
  -- 1: update/release SDA; wait for the remainder of the low interval.
  -- 2: SCL rises; wait for half the high interval.
  -- 3: sample ACK / select next bit; wait for the remaining high interval.
  -- Defaults: intervals = 50, 1200, 625, 625 clk cycles (total 2500).
  -- This updates SDA early in SCL-low instead of waiting 12.5 us.
  constant sda_hold_cycles_c : positive :=
    (ref_clk_freq_g + 999_999) / 1_000_000;

  type state_t is (idle, start_condition, send_bit, ack,
                   stop_condition, advance, done);
  signal state_r : state_t;
  signal phase_r : natural range 0 to 3;
  signal wait_count_r : natural range 0 to period_cycles_c - 1;

  signal param_index_r : natural range 0 to 14;
  signal byte_index_r : natural range 0 to 2;
  signal bit_index_r : natural range 0 to 7;
  signal tx_byte_r : byte_t;
  signal transaction_failed_r : std_logic;
  signal param_count_r : unsigned(n_leds_g - 1 downto 0);

  signal scl_r : std_logic;
  signal sda_drive_low_r : std_logic;
  signal finished_r : std_logic;
  signal sda_meta_r, sda_sync_r : std_logic;
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of sda_meta_r : signal is "TRUE";
  attribute ASYNC_REG of sda_sync_r : signal is "TRUE";

begin
  -- The table holds 15 settings. Smaller n_params_g sends its first entries.
  assert n_params_g >= 1 and n_params_g <= config_c'length
    report "n_params_g must be between 1 and 15" severity failure;
  assert n_leds_g >= 1 and n_params_g < 2**n_leds_g
    report "n_leds_g cannot represent the completed parameter count"
    severity failure;
  assert i2c_freq_g > 0 and i2c_freq_g <= 100_000
    report "Use a positive Standard-mode I2C frequency, at most 100 kHz"
    severity failure;
  assert ref_clk_freq_g >= 1_000_000 and
         low_cycles_c > sda_hold_cycles_c and high_first_c >= 4
    report "Reference clock is too slow for this timing/synchronizer"
    severity failure;

  sclk_out <= scl_r;
  sdat_inout <= '0' when sda_drive_low_r = '1' else 'Z';
  param_status_out <= std_logic_vector(param_count_r);
  finished_out <= finished_r;

  -- Synchronize the external SDA input. Sampling occurs well inside SCL-high.
  -- to_X01 also maps the testbench pull-up value 'H' to logic '1'.
  synchronize_sda : process(clk, rst_n)
  begin
    if rst_n = '0' then
      sda_meta_r <= '1';
      sda_sync_r <= '1';
    elsif rising_edge(clk) then
      sda_meta_r <= to_X01(sdat_inout);
      sda_sync_r <= sda_meta_r;
    end if;
  end process;

  controller : process(clk, rst_n)
  begin
    if rst_n = '0' then
      state_r <= idle;
      phase_r <= 0;
      wait_count_r <= 0;
      param_index_r <= 0;
      byte_index_r <= 0;
      bit_index_r <= 7;
      tx_byte_r <= device_write_c;
      transaction_failed_r <= '0';
      param_count_r <= (others => '0');
      scl_r <= '1';
      sda_drive_low_r <= '0';
      finished_r <= '0';

    elsif rising_edge(clk) then
      if wait_count_r /= 0 then
        wait_count_r <= wait_count_r - 1;
      else
        -- Defaults for the time until the NEXT phase action.
        -- START/IDLE/ADVANCE use a half-period delay instead.
        if state_r = send_bit or state_r = ack or
           state_r = stop_condition then
          case phase_r is
            when 0 => wait_count_r <= sda_hold_cycles_c - 1;
            when 1 => wait_count_r <= low_cycles_c - sda_hold_cycles_c - 1;
            when 2 => wait_count_r <= high_first_c - 1;
            when 3 => wait_count_r <= high_second_c - 1;
          end case;
        else
          wait_count_r <= low_cycles_c - 1;
        end if;

        case state_r is
          when idle =>
            -- Bus-free interval before the first START.
            scl_r <= '1';
            sda_drive_low_r <= '0';
            state_r <= start_condition;

          when start_condition =>
            -- SDA high -> low while SCL is already high.
            sda_drive_low_r <= '1';
            tx_byte_r <= device_write_c;
            byte_index_r <= 0;
            bit_index_r <= 7;
            transaction_failed_r <= '0';
            phase_r <= 0;
            state_r <= send_bit;

          when send_bit =>
            case phase_r is
              when 0 =>
                scl_r <= '0';
                phase_r <= 1;
              when 1 =>
                -- tx_byte_r changes internally; SDA changes only here.
                sda_drive_low_r <= not tx_byte_r(bit_index_r);
                phase_r <= 2;
              when 2 =>
                scl_r <= '1';
                phase_r <= 3;
              when 3 =>
                -- SDA stays unchanged for the rest of SCL-high.
                phase_r <= 0;
                if bit_index_r = 0 then
                  state_r <= ack;
                else
                  bit_index_r <= bit_index_r - 1;
                end if;
            end case;

          when ack =>
            case phase_r is
              when 0 =>
                scl_r <= '0';
                phase_r <= 1;
              when 1 =>
                sda_drive_low_r <= '0'; -- release SDA for the codec
                phase_r <= 2;
              when 2 =>
                scl_r <= '1'; -- ninth clock pulse
                phase_r <= 3;
              when 3 =>
                phase_r <= 0;
                if sda_sync_r /= '0' then
                  -- Only a definite low counts as ACK.
                  transaction_failed_r <= '1';
                  state_r <= stop_condition;
                elsif byte_index_r = 2 then
                  state_r <= stop_condition;
                else
                  -- First ACK -> register address; second ACK -> value.
                  if byte_index_r = 0 then
                    tx_byte_r <= config_c(param_index_r).reg_addr;
                  else
                    tx_byte_r <= config_c(param_index_r).reg_data;
                  end if;
                  byte_index_r <= byte_index_r + 1;
                  bit_index_r <= 7;
                  state_r <= send_bit;
                end if;
            end case;

          when stop_condition =>
            case phase_r is
              when 0 =>
                scl_r <= '0'; -- finish the ninth clock BEFORE changing SDA
                phase_r <= 1;
              when 1 =>
                sda_drive_low_r <= '1'; -- prepare SDA low while SCL low
                phase_r <= 2;
              when 2 =>
                scl_r <= '1';
                -- Give STOP a full half-period of setup time, including
                -- when i2c_freq_g is set to the Standard-mode maximum.
                wait_count_r <= low_cycles_c - 1;
                phase_r <= 3;
              when 3 =>
                sda_drive_low_r <= '0'; -- SDA low -> high: STOP
                phase_r <= 0;
                state_r <= advance;
            end case;

          when advance =>
            -- STOP has completed; leave both lines high during this decision.
            if transaction_failed_r = '1' then
              -- No counter/index increment: retry the entire same parameter.
              state_r <= start_condition;
            else
              param_count_r <= param_count_r + 1;
              if param_index_r = n_params_g - 1 then
                finished_r <= '1';
                state_r <= done;
              else
                param_index_r <= param_index_r + 1;
                state_r <= start_condition;
              end if;
            end if;

          when done =>
            -- Registers retain their values. No further I2C activity.
            wait_count_r <= 0;
        end case;
      end if;
    end if;
  end process;
end architecture rtl;
