-------------------------------------------------------------------------------
-- File    : tb_night_mode.vhd
-- Owner   : Person B
-- Purpose : Self-checking testbench for night_mode. Ends by itself.
-- Tests   : 1) after reset: night = 0, baseline_ready = 0
--           2) calibration needs 16 frames; average of 190/210 = baseline 200
--           3) bright light: night stays 0
--           4) dark light: night rises only after HOLD_MS; a short dip is ignored
--           5) hysteresis: between the two thresholds night does not change;
--              it falls only after HOLD_MS of real brightness
--           6) link_lost forces night low and the hold timer restarts
--           7) re-entering calibrate clears the baseline; night stays 0 until
--              a new baseline exists; then night works with the new baseline
-- Speed   : 1 "ms" = 50 clocks = 1000 ns, HOLD_MS = 5, MARGIN = 40
--           (baseline 200 -> dark below 160, bright above 180)
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_night_mode is end entity;

architecture sim of tb_night_mode is

  constant CLK_PERIOD : time := 20 ns;

  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';
  signal done  : boolean   := false;

  signal tick_1ms       : std_logic := '0';
  signal calibrate      : std_logic := '0';
  signal ldr            : unsigned(7 downto 0) := to_unsigned(200, 8);
  signal frame_ok_p     : std_logic := '0';
  signal link_lost      : std_logic := '0';
  signal night          : std_logic;
  signal baseline_ready : std_logic;

  signal tick_cnt : integer := 0;

begin

  clk_proc : process
  begin
    while not done loop
      clk <= '0'; wait for CLK_PERIOD / 2;
      clk <= '1'; wait for CLK_PERIOD / 2;
    end loop;
    wait;
  end process;

  -- one tick_1ms pulse every 50 clocks
  tick_proc : process (clk)
  begin
    if rising_edge(clk) then
      tick_1ms <= '0';
      if tick_cnt = 49 then
        tick_1ms <= '1';
        tick_cnt <= 0;
      else
        tick_cnt <= tick_cnt + 1;
      end if;
    end if;
  end process;

  dut : entity work.night_mode
    generic map (MARGIN => 40, HOLD_MS => 5)
    port map (
      clk            => clk,
      rst_n          => rst_n,
      tick_1ms       => tick_1ms,
      calibrate      => calibrate,
      ldr            => ldr,
      frame_ok_p     => frame_ok_p,
      link_lost      => link_lost,
      night          => night,
      baseline_ready => baseline_ready
    );

  stim : process

    -- one LDR frame: new value and a one-clock frame_ok_p pulse
    procedure send_frame (v : in integer) is
    begin
      wait until rising_edge(clk);
      ldr        <= to_unsigned(v, 8);
      frame_ok_p <= '1';
      wait until rising_edge(clk);
      frame_ok_p <= '0';
      wait for 2 * CLK_PERIOD;
    end procedure;

  begin
    wait for 100 ns; rst_n <= '1';
    wait for 10 * CLK_PERIOD;

    -- Test 1
    assert night = '0' report "night must be 0 after reset" severity failure;
    assert baseline_ready = '0' report "baseline_ready must be 0 after reset"
      severity failure;

    -- Test 2: calibration, 8 x 190 and 8 x 210 -> average 200
    calibrate <= '1';
    wait for 5 * CLK_PERIOD;
    for i in 0 to 15 loop
      if i mod 2 = 0 then send_frame(190); else send_frame(210); end if;
      if i < 15 then
        assert baseline_ready = '0'
          report "baseline_ready rose before 16 frames" severity failure;
      end if;
    end loop;
    assert baseline_ready = '1' report "baseline_ready missing after 16 frames"
      severity failure;
    calibrate <= '0';
    wait for 5 * CLK_PERIOD;

    -- Test 3: bright light (199 and 161 are both above the dark limit 160)
    ldr <= to_unsigned(199, 8);
    wait for 8000 ns;
    assert night = '0' report "night rose in bright light" severity failure;
    ldr <= to_unsigned(161, 8);
    wait for 8000 ns;
    assert night = '0' report "night rose at 161 (limit is 160)" severity failure;

    -- Test 4: dark light
    ldr <= to_unsigned(159, 8);
    wait for 3000 ns;                                   -- shorter than HOLD_MS
    ldr <= to_unsigned(200, 8);
    wait for 2000 ns;                                   -- a tick resets the timer
    assert night = '0' report "short dip must not set night" severity failure;
    ldr <= to_unsigned(100, 8);
    wait for 3000 ns;
    assert night = '0' report "night rose before HOLD_MS" severity failure;
    wait for 4000 ns;                                   -- about 7 ms in total
    assert night = '1' report "night did not rise after HOLD_MS" severity failure;

    -- Test 5: hysteresis (bright limit is 180)
    ldr <= to_unsigned(170, 8);                         -- between 160 and 180
    wait for 10000 ns;
    assert night = '1' report "night must hold between the limits" severity failure;
    ldr <= to_unsigned(181, 8);
    wait for 3000 ns;                                   -- shorter than HOLD_MS
    ldr <= to_unsigned(170, 8);
    wait for 2000 ns;
    assert night = '1' report "short brightness must not clear night"
      severity failure;
    ldr <= to_unsigned(181, 8);
    wait for 7000 ns;
    assert night = '0' report "night did not clear after HOLD_MS" severity failure;

    -- Test 6: link_lost
    ldr <= to_unsigned(100, 8);
    wait for 8000 ns;
    assert night = '1' report "night should be on again" severity failure;
    link_lost <= '1';
    wait for 4 * CLK_PERIOD;
    assert night = '0' report "link_lost must force night low" severity failure;
    link_lost <= '0';
    wait for 8000 ns;
    assert night = '1' report "night must return after the link returns"
      severity failure;

    -- Test 7: new calibration clears the baseline
    calibrate <= '1';
    wait for 4 * CLK_PERIOD;
    assert night = '0' report "night must be 0 while calibrating" severity failure;
    assert baseline_ready = '0' report "baseline_ready must clear on calibrate"
      severity failure;
    wait for 8000 ns;
    assert night = '0' report "night must stay 0 while calibrating" severity failure;
    calibrate <= '0';
    wait for 8000 ns;                                   -- ldr = 100, no baseline
    assert night = '0' report "night must stay 0 without a baseline"
      severity failure;
    assert baseline_ready = '0' report "baseline_ready should still be 0"
      severity failure;

    calibrate <= '1';
    wait for 5 * CLK_PERIOD;
    for i in 0 to 15 loop
      send_frame(100);
    end loop;
    assert baseline_ready = '1' report "second calibration failed" severity failure;
    calibrate <= '0';
    wait for 8000 ns;                                   -- baseline 100, limit 60
    assert night = '0' report "night rose at the baseline value" severity failure;
    ldr <= to_unsigned(50, 8);
    wait for 8000 ns;
    assert night = '1' report "night did not rise with the new baseline"
      severity failure;

    report "tb_night_mode PASSED" severity note;
    done <= true;
    wait;
  end process;

end architecture;
