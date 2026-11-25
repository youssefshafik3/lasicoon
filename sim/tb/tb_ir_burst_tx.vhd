-- Testbench for ir_burst_tx
-- Tiny generics: 38 kHz half period = 4 clocks, window = 100 clocks, cooldown = 50 clocks.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_ir_burst_tx is end entity;

architecture sim of tb_ir_burst_tx is
  signal clk              : std_logic := '0';
  signal rst_n            : std_logic := '0';
  signal playing          : std_logic := '0';
  signal night            : std_logic := '0';
  signal fire_p           : std_logic := '0';
  signal hit_seen         : std_logic := '0';
  signal ir_out           : std_logic;
  signal laser_sight      : std_logic;
  signal window_open      : std_logic;
  signal window_expired_p : std_logic;
  signal shot_hard        : std_logic;
  signal busy             : std_logic;

  signal prev_ir     : std_logic := '0';
  signal ir_edges    : integer := 0;   -- rising edges of ir_out
  signal expired_cnt : integer := 0;   -- window_expired_p pulses
  signal done        : boolean := false;
begin

  clk_proc : process
  begin
    while not done loop
      clk <= '0'; wait for 10 ns;
      clk <= '1'; wait for 10 ns;
    end loop;
    wait;
  end process;

  dut : entity work.ir_burst_tx
    generic map (HALF_PERIOD => 4, WINDOW_CLKS => 100, COOLDOWN_CLKS => 50)
    port map (clk => clk, rst_n => rst_n, playing => playing, night => night,
              fire_p => fire_p, hit_seen => hit_seen, ir_out => ir_out,
              laser_sight => laser_sight, window_open => window_open,
              window_expired_p => window_expired_p, shot_hard => shot_hard,
	      busy => busy);

  -- count the 38 kHz rising edges and the expiry pulses
  count_proc : process (clk)
  begin
    if rising_edge(clk) then
      prev_ir <= ir_out;
      if ir_out = '1' and prev_ir = '0' then
        ir_edges <= ir_edges + 1;
      end if;
      if window_expired_p = '1' then
        expired_cnt <= expired_cnt + 1;
      end if;
    end if;
  end process;

  stim : process
  begin
    wait for 100 ns; rst_n <= '1';
    playing <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    -- idle state
    assert laser_sight = '1' report "laser should be on when playing and not night" severity failure;
    assert ir_out = '0'      report "ir_out should be 0 when idle" severity failure;
    assert window_open = '0' report "window should be closed when idle" severity failure;
    assert busy = '0'        report "busy should be 0 when idle" severity failure;

    -- shot 1: daytime, no hit
    fire_p <= '1'; wait until rising_edge(clk); fire_p <= '0';
    wait until rising_edge(clk);
    assert window_open = '1' report "window should open after fire" severity failure;
    assert busy = '1'        report "busy should be 1 during the shot" severity failure;
    assert shot_hard = '0'   report "daytime shot must not be hard" severity failure;

    for i in 1 to 110 loop
      wait until rising_edge(clk);
    end loop;
    -- now the window is over and we are in cooldown
    assert window_open = '0' report "window should close after its length" severity failure;
    assert busy = '1'        report "busy should stay 1 during cooldown" severity failure;
    assert ir_out = '0'      report "ir_out must be 0 during cooldown" severity failure;
    assert expired_cnt = 1   report "expected exactly one window_expired_p" severity failure;
    assert ir_edges >= 12 and ir_edges <= 14
      report "wrong number of 38 kHz pulses in the burst" severity failure;

    -- FIRE during cooldown must be ignored
    fire_p <= '1'; wait until rising_edge(clk); fire_p <= '0';
    wait until rising_edge(clk);
    assert window_open = '0' report "fire during cooldown must be ignored" severity failure;

    -- wait until the cooldown is over
    for i in 1 to 50 loop
      wait until rising_edge(clk);
    end loop;
    assert busy = '0' report "busy should be 0 after cooldown" severity failure;

    -- shot 2: night, with a hit after 10 clocks
    night <= '1';
    wait until rising_edge(clk);
    assert laser_sight = '0' report "laser must be off at night" severity failure;
    fire_p <= '1'; wait until rising_edge(clk); fire_p <= '0';
    wait until rising_edge(clk);
    assert window_open = '1' report "window should open for shot 2" severity failure;
    assert shot_hard = '1'   report "night shot must be hard" severity failure;

    for i in 1 to 10 loop
      wait until rising_edge(clk);
    end loop;
    hit_seen <= '1'; wait until rising_edge(clk); hit_seen <= '0';
    wait until rising_edge(clk);
    assert window_open = '0' report "window must close on a hit" severity failure;
    assert busy = '1'        report "cooldown should follow a hit" severity failure;
    for i in 1 to 5 loop
      wait until rising_edge(clk);
    end loop;
    assert expired_cnt = 1   report "no expiry pulse is allowed after a hit" severity failure;

    -- wait until the cooldown is over
    for i in 1 to 55 loop
      wait until rising_edge(clk);
    end loop;
    assert busy = '0' report "busy should be 0 again" severity failure;

    -- not playing: no shot allowed, no laser
    playing <= '0'; night <= '0';
    wait until rising_edge(clk);
    assert laser_sight = '0' report "laser must be off when not playing" severity failure;
    fire_p <= '1'; wait until rising_edge(clk); fire_p <= '0';
    wait until rising_edge(clk);
    assert window_open = '0' report "no shot allowed when not playing" severity failure;

    done <= true;
    wait;
  end process;

end architecture;
