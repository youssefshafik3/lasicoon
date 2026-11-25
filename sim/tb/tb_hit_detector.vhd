-- Testbench for hit_detector
-- Receivers are active-low: a '0' bit means that receiver sees IR.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_hit_detector is end entity;

architecture sim of tb_hit_detector is
  signal clk              : std_logic := '0';
  signal rst_n            : std_logic := '0';
  signal rx_sync          : std_logic_vector(4 downto 0) := "11111";
  signal armed            : std_logic_vector(4 downto 0) := "00000";
  signal window_open      : std_logic := '0';
  signal window_expired_p : std_logic := '0';
  signal hit_p            : std_logic;
  signal hit_idx          : unsigned(2 downto 0);
  signal miss_p           : std_logic;

  signal hit_cnt  : integer := 0;
  signal miss_cnt : integer := 0;
  signal done     : boolean := false;
begin

  clk_proc : process
  begin
    while not done loop
      clk <= '0'; wait for 10 ns;
      clk <= '1'; wait for 10 ns;
    end loop;
    wait;
  end process;

  dut : entity work.hit_detector
    generic map (N_TARGETS => 5)
    port map (clk => clk, rst_n => rst_n, rx_sync => rx_sync, armed => armed,
              window_open => window_open, window_expired_p => window_expired_p,
              hit_p => hit_p, hit_idx => hit_idx, miss_p => miss_p);

  -- count the pulses
  count_proc : process (clk)
  begin
    if rising_edge(clk) then
      if hit_p = '1' then  hit_cnt  <= hit_cnt + 1;  end if;
      if miss_p = '1' then miss_cnt <= miss_cnt + 1; end if;
    end if;
  end process;

  stim : process
    procedure wait_clk (n : integer) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;
  begin
    wait for 100 ns; rst_n <= '1';
    wait_clk(2);

    -- 1. window closed: a low receiver must be ignored
    rx_sync <= "11011";                       -- target 2 sees IR
    armed   <= "11111";
    wait_clk(5);
    assert hit_cnt = 0 report "hit with the window closed" severity failure;

    -- 2. window open, target 2 low but NOT armed: no hit
    armed       <= "00000";
    window_open <= '1';
    wait_clk(5);
    assert hit_cnt = 0 report "hit on a target that is not armed" severity failure;

    --    now arm target 2: exactly one hit, index 2
    armed <= "00100";
    wait_clk(4);
    assert hit_cnt = 1 report "armed target was not hit" severity failure;
    assert hit_idx = to_unsigned(2, 3) report "wrong hit index" severity failure;
    wait_clk(10);
    assert hit_cnt = 1 report "more than one hit in a single window" severity failure;

    -- close the window
    window_open <= '0';
    rx_sync     <= "11111";
    armed       <= "00000";
    wait_clk(3);

    -- 3. two targets low at once (1 and 3): lowest index wins
    rx_sync     <= "10101";
    armed       <= "11111";
    window_open <= '1';
    wait_clk(6);
    assert hit_cnt = 2 report "second hit missing" severity failure;
    assert hit_idx = to_unsigned(1, 3) report "lowest index must win" severity failure;
    window_open <= '0';
    rx_sync     <= "11111";
    wait_clk(3);

    -- 4. miss: window opens, nothing seen, window expires
    window_open <= '1';
    wait_clk(10);
    window_open <= '0';
    window_expired_p <= '1';
    wait until rising_edge(clk);
    window_expired_p <= '0';
    wait_clk(4);
    assert miss_cnt = 1 report "miss not reported" severity failure;
    assert hit_cnt = 2  report "a miss must not make a hit" severity failure;

    -- 5. hit right at the end of the window: hit, but NO miss
    rx_sync     <= "11110";                   -- target 0 sees IR
    armed       <= "11111";
    window_open <= '1';
    wait until rising_edge(clk);              -- hit is found on this edge
    window_open      <= '0';
    window_expired_p <= '1';
    wait until rising_edge(clk);
    window_expired_p <= '0';
    wait_clk(4);
    assert hit_cnt = 3  report "late hit missing" severity failure;
    assert hit_idx = to_unsigned(0, 3) report "late hit has wrong index" severity failure;
    assert miss_cnt = 1 report "miss reported after a hit" severity failure;

    -- 6. a new window allows a new hit
    rx_sync     <= "11111";
    window_open <= '0';
    wait_clk(3);
    rx_sync     <= "01111";                   -- target 4 sees IR
    window_open <= '1';
    wait_clk(4);
    assert hit_cnt = 4 report "hit in a new window missing" severity failure;
    assert hit_idx = to_unsigned(4, 3) report "new window hit has wrong index" severity failure;

    done <= true;
    wait;
  end process;

end architecture;
