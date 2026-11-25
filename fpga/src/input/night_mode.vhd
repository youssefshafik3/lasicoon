-------------------------------------------------------------------------------
-- File    : night_mode.vhd
-- Owner   : Person B
-- Purpose : Decides "is it night?" from the LDR (light sensor) value.
--           1) While calibrate = '1' (game state READY) it measures the room
--              light: the average of 16 LDR frames becomes the baseline.
--           2) Afterwards, night goes HIGH when the light stays darker than
--              (baseline - MARGIN) for HOLD_MS, and goes LOW again when it
--              stays brighter than (baseline - MARGIN/2) for HOLD_MS
--              (hysteresis, so it does not flicker).
--           It does NOT switch the laser and does NOT choose points.
--
-- Generics: MARGIN  : integer := 40    how much darker than baseline = night
--           HOLD_MS : integer := 300   how long the condition must last (ms)
--
-- Ports   : clk, rst_n    clock and synchronous active-low reset
--           tick_1ms      1-clock pulse every millisecond
--           calibrate     '1' while the game is in READY
--           ldr           unsigned 8-bit, from sensor_frame_parser
--           frame_ok_p    pulse: a new ldr value arrived
--           link_lost     '1' = Arduino silent: night is forced low
--           night         level: '1' = night mode
--           baseline_ready level: '1' = a baseline has been measured
--
-- Assumptions:
--   * Smaller ldr value = darker. (Open item 9: confirm the polarity on the
--     real LDR circuit.)
--   * Night can never be '1' before a baseline exists.
--   * If baseline < MARGIN, night can never trigger (value cannot go below 0).
--   * VHDL-93 only.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity night_mode is
  generic (
    MARGIN  : integer := 40;
    HOLD_MS : integer := 300
  );
  port (
    clk            : in  std_logic;
    rst_n          : in  std_logic;                   -- sync, active low
    tick_1ms       : in  std_logic;
    calibrate      : in  std_logic;
    ldr            : in  unsigned(7 downto 0);
    frame_ok_p     : in  std_logic;
    link_lost      : in  std_logic;
    night          : out std_logic;
    baseline_ready : out std_logic
  );
end entity;

architecture rtl of night_mode is

  signal calibrate_d  : std_logic := '0';             -- calibrate, 1 clock late
  signal sum          : unsigned(11 downto 0) := (others => '0');
  signal n_cnt        : integer range 0 to 15 := 0;   -- frames added so far
  signal baseline     : unsigned(7 downto 0) := (others => '0');
  signal baseline_rdy : std_logic := '0';
  signal night_r      : std_logic := '0';
  signal hold_cnt     : unsigned(15 downto 0) := (others => '0');

  -- thresholds are plain integers so they can go below zero without trouble
  signal dark_th   : integer := 0;                    -- below this = dark
  signal bright_th : integer := 0;                    -- above this = bright

begin

  dark_th   <= to_integer(baseline) - MARGIN;
  bright_th <= to_integer(baseline) - MARGIN / 2;

  night          <= night_r;
  baseline_ready <= baseline_rdy;

  process (clk)
  begin
    if rising_edge(clk) then

      if rst_n = '0' then
        calibrate_d  <= '0';
        sum          <= (others => '0');
        n_cnt        <= 0;
        baseline     <= (others => '0');
        baseline_rdy <= '0';
        night_r      <= '0';
        hold_cnt     <= (others => '0');
      else

        calibrate_d <= calibrate;

        -- calibrate just went high: forget the old baseline, start fresh
        if calibrate = '1' and calibrate_d = '0' then
          baseline_rdy <= '0';
          sum          <= (others => '0');
          n_cnt        <= 0;
        end if;

        if link_lost = '1' then
          -- no trustworthy data: night off, restart the hold timer
          night_r  <= '0';
          hold_cnt <= (others => '0');

        elsif calibrate = '1' then
          -- READY: measure the room light, night stays off
          night_r  <= '0';
          hold_cnt <= (others => '0');
          if calibrate_d = '1' and frame_ok_p = '1' then
            if n_cnt = 15 then
              -- 16th frame: average = (sum + this value) / 16
              baseline     <= resize(shift_right(sum + resize(ldr, 12), 4), 8);
              baseline_rdy <= '1';
              sum          <= (others => '0');
              n_cnt        <= 0;
            else
              sum   <= sum + resize(ldr, 12);
              n_cnt <= n_cnt + 1;
            end if;
          end if;

        elsif baseline_rdy = '0' then
          -- never calibrated: cannot judge, so stay at day
          night_r  <= '0';
          hold_cnt <= (others => '0');

        else
          -- normal operation: compare with the baseline once per millisecond
          if tick_1ms = '1' then
            if night_r = '0' then
              if to_integer(ldr) < dark_th then
                if hold_cnt = to_unsigned(HOLD_MS - 1, hold_cnt'length) then
                  night_r  <= '1';
                  hold_cnt <= (others => '0');
                else
                  hold_cnt <= hold_cnt + 1;
                end if;
              else
                hold_cnt <= (others => '0');
              end if;
            else
              if to_integer(ldr) > bright_th then
                if hold_cnt = to_unsigned(HOLD_MS - 1, hold_cnt'length) then
                  night_r  <= '0';
                  hold_cnt <= (others => '0');
                else
                  hold_cnt <= hold_cnt + 1;
                end if;
              else
                hold_cnt <= (others => '0');
              end if;
            end if;
          end if;
        end if;

      end if;
    end if;
  end process;

end architecture;
