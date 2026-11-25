-- Testbench for lfsr_rng

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_lfsr_rng is end entity;

architecture sim of tb_lfsr_rng is
  signal clk       : std_logic := '0';
  signal rst_n     : std_logic := '0';
  signal seed_load : std_logic := '0';
  signal rnd       : std_logic_vector(15 downto 0);
  signal done      : boolean := false;
begin

  clk_proc : process
  begin
    while not done loop
      clk <= '0'; wait for 10 ns;
      clk <= '1'; wait for 10 ns;
    end loop;
    wait;
  end process;

  dut : entity work.lfsr_rng
    port map (clk => clk, rst_n => rst_n, seed_load => seed_load, rnd => rnd);

  stim : process
    variable start  : std_logic_vector(15 downto 0);
    variable seed_a : std_logic_vector(15 downto 0);
    variable seed_b : std_logic_vector(15 downto 0);
    variable prev   : std_logic_vector(15 downto 0);
    procedure wait_clk (n : integer) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;
  begin
    wait for 100 ns; rst_n <= '1';
    wait_clk(2);
    assert rnd /= x"0000" report "rnd is zero after reset" severity failure;

    -- 1. the output changes from clock to clock
    prev := rnd;
    wait_clk(1);
    assert rnd /= prev report "rnd did not change" severity failure;

    -- 2. two START presses at different times give different seeds
    wait_clk(7);
    seed_load <= '1'; wait until rising_edge(clk); seed_load <= '0';
    wait until rising_edge(clk);
    seed_a := rnd;
    wait_clk(37);
    seed_load <= '1'; wait until rising_edge(clk); seed_load <= '0';
    wait until rising_edge(clk);
    seed_b := rnd;
    assert seed_a /= seed_b report "different press times gave the same seed" severity failure;
    assert seed_a /= x"0000" and seed_b /= x"0000"
      report "seed must never be zero" severity failure;

    -- 3. full period: the sequence must visit 65535 states, never hit zero,
    --    and come back to its start value only after exactly 65535 steps
    seed_load <= '1'; wait until rising_edge(clk); seed_load <= '0';
    wait until rising_edge(clk);
    start := rnd;
    for i in 1 to 65534 loop
      wait until rising_edge(clk);
      assert rnd /= x"0000" report "LFSR reached all zeros" severity failure;
      assert rnd /= start   report "LFSR period is too short (wrong taps)" severity failure;
    end loop;
    wait until rising_edge(clk);
    assert rnd = start report "LFSR did not return to start after 65535 steps" severity failure;

    done <= true;
    wait;
  end process;

end architecture;
