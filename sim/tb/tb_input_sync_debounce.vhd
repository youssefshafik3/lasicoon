-- Testbench for input_sync_debounce (ACTIVE_LOW = true, DEBOUNCE_MS = 3)
-- tick_1ms is shortened to every 5 clocks so the simulation is fast.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_input_sync_debounce is end entity;

architecture sim of tb_input_sync_debounce is
  signal clk         : std_logic := '0';
  signal rst_n       : std_logic := '0';
  signal tick        : std_logic := '0';
  signal raw         : std_logic := '1';   -- idle = high (active-low button)
  signal level       : std_logic;
  signal press       : std_logic;
  signal press_count : integer := 0;
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

  -- fake 1 ms tick: one pulse every 5 clocks
  tick_proc : process (clk)
    variable c : integer := 0;
  begin
    if rising_edge(clk) then
      if c = 4 then tick <= '1'; c := 0;
      else          tick <= '0'; c := c + 1;
      end if;
    end if;
  end process;

  dut : entity work.input_sync_debounce
    generic map (DEBOUNCE_MS => 3, ACTIVE_LOW => true)
    port map (clk => clk, rst_n => rst_n, tick_1ms => tick,
              raw_in => raw, level_out => level, press_p => press);

  -- count how many press pulses we see
  count_proc : process (clk)
  begin
    if rising_edge(clk) then
      if press = '1' then press_count <= press_count + 1; end if;
    end if;
  end process;

  stim : process
  begin
    wait for 100 ns; rst_n <= '1';
    wait for 500 ns;
    assert level = '0' report "idle level should be 0" severity failure;

    -- short bounces (shorter than the debounce time): must be ignored
    raw <= '0'; wait for 20 ns;
    raw <= '1'; wait for 20 ns;
    raw <= '0'; wait for 20 ns;
    raw <= '1'; wait for 600 ns;
    assert press_count = 0 report "bounce was counted as press" severity failure;
    assert level = '0' report "level changed on bounce" severity failure;

    -- real press: held long enough
    raw <= '0'; wait for 1000 ns;
    assert level = '1' report "press not detected" severity failure;
    assert press_count = 1 report "should be exactly one press pulse" severity failure;

    -- release
    raw <= '1'; wait for 1000 ns;
    assert level = '0' report "release not detected" severity failure;
    assert press_count = 1 report "release must not make a pulse" severity failure;

    done <= true;
    wait;
  end process;

end architecture;
