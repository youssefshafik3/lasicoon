-------------------------------------------------------------------------------
-- File    : tb_sensor_frame_parser.vhd
-- Owner   : Person B
-- Purpose : Self-checking testbench for sensor_frame_parser. Ends by itself.
-- Tests   : 1) link_lost is high after reset
--           2) one good frame is accepted, link_lost goes low
--           3) a frame restarted by 0xFF in the middle is resynchronised
--           4) bytes without a header are ignored
--           5) an incomplete frame does not change x, y, ldr
--           6) watchdog: link_lost rises only after WATCHDOG_MS ms
--           7) the link recovers with the next good frame
-- Speed   : tick_1ms comes every 50 clocks (1 "ms" = 1000 ns) and the
--           watchdog is 5 ms, so the simulation is tiny.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_sensor_frame_parser is end entity;

architecture sim of tb_sensor_frame_parser is

  constant CLK_PERIOD : time := 20 ns;

  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';
  signal done  : boolean   := false;

  signal tick_1ms   : std_logic := '0';
  signal data       : std_logic_vector(7 downto 0) := (others => '0');
  signal data_valid : std_logic := '0';
  signal x, y, ldr  : unsigned(7 downto 0);
  signal frame_ok_p : std_logic;
  signal link_lost  : std_logic;

  signal tick_cnt  : integer := 0;
  signal frame_cnt : integer := 0;

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

  dut : entity work.sensor_frame_parser
    generic map (WATCHDOG_MS => 5)
    port map (
      clk        => clk,
      rst_n      => rst_n,
      tick_1ms   => tick_1ms,
      data       => data,
      data_valid => data_valid,
      x          => x,
      y          => y,
      ldr        => ldr,
      frame_ok_p => frame_ok_p,
      link_lost  => link_lost
    );

  -- counts complete frames
  monitor : process (clk)
  begin
    if rising_edge(clk) then
      if frame_ok_p = '1' then
        frame_cnt <= frame_cnt + 1;
      end if;
    end if;
  end process;

  stim : process

    -- gives the DUT one byte with a one-clock data_valid pulse
    procedure send_byte (b : in std_logic_vector(7 downto 0)) is
    begin
      wait until rising_edge(clk);
      data       <= b;
      data_valid <= '1';
      wait until rising_edge(clk);
      data_valid <= '0';
      wait for 3 * CLK_PERIOD;
    end procedure;

  begin
    wait for 100 ns; rst_n <= '1';
    wait for 10 * CLK_PERIOD;

    -- Test 1: nothing received yet
    assert link_lost = '1' report "link_lost must be 1 after reset"
      severity failure;

    -- Test 2: one good frame  FF, 16, 32, 48
    send_byte(x"FF"); send_byte(x"10"); send_byte(x"20"); send_byte(x"30");
    assert frame_cnt = 1 report "frame 1 not accepted" severity failure;
    assert x = to_unsigned(16, 8)  report "frame 1: wrong x"   severity failure;
    assert y = to_unsigned(32, 8)  report "frame 1: wrong y"   severity failure;
    assert ldr = to_unsigned(48, 8) report "frame 1: wrong ldr" severity failure;
    assert link_lost = '0' report "link_lost must drop after a frame"
      severity failure;

    -- Test 3: broken frame, then 0xFF restarts: FF 01 | FF 100 101 102
    send_byte(x"FF"); send_byte(x"01");
    send_byte(x"FF"); send_byte(x"64"); send_byte(x"65"); send_byte(x"66");
    assert frame_cnt = 2 report "resync: frame 2 not accepted" severity failure;
    assert x = to_unsigned(100, 8)  report "resync: wrong x"   severity failure;
    assert y = to_unsigned(101, 8)  report "resync: wrong y"   severity failure;
    assert ldr = to_unsigned(102, 8) report "resync: wrong ldr" severity failure;

    -- Test 4: bytes with no header are ignored
    send_byte(x"05"); send_byte(x"06"); send_byte(x"07");
    assert frame_cnt = 2 report "headerless bytes made a frame" severity failure;
    assert x = to_unsigned(100, 8) report "headerless bytes changed x"
      severity failure;

    -- Test 5: incomplete frame must not change the outputs
    send_byte(x"FF"); send_byte(x"09"); send_byte(x"08");
    assert frame_cnt = 2 report "incomplete frame counted" severity failure;
    assert x = to_unsigned(100, 8) and y = to_unsigned(101, 8)
      report "incomplete frame changed x or y" severity failure;

    -- Test 6: watchdog. A fresh complete frame restarts it.
    send_byte(x"FF"); send_byte(x"01"); send_byte(x"02"); send_byte(x"03");
    assert frame_cnt = 3 report "frame 3 not accepted" severity failure;
    wait for 3000 ns;                                  -- about 3 ms
    assert link_lost = '0' report "link_lost rose too early" severity failure;
    wait for 4000 ns;                                  -- about 7 ms in total
    assert link_lost = '1' report "link_lost did not rise" severity failure;

    -- Test 7: recovery
    send_byte(x"FF"); send_byte(x"0A"); send_byte(x"0B"); send_byte(x"0C");
    assert frame_cnt = 4 report "frame 4 not accepted" severity failure;
    assert link_lost = '0' report "link_lost did not recover" severity failure;
    assert ldr = to_unsigned(12, 8) report "recovery: wrong ldr" severity failure;

    report "tb_sensor_frame_parser PASSED" severity note;
    done <= true;
    wait;
  end process;

end architecture;
