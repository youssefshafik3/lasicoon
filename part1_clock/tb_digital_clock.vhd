-- Testbench for digital_clock
-- One clock cycle = one second, so the clock period does not change the result.
-- CLK_PERIOD is a constant: 20 ns = 50 MHz. If the TA confirms 50 GHz, use 20 ps
-- and run ModelSim with: vsim -t ps work.tb_digital_clock

library ieee;
use ieee.std_logic_1164.all;

entity tb_digital_clock is end entity;

architecture sim of tb_digital_clock is
  constant CLK_PERIOD : time := 20 ns;

  signal clk     : std_logic := '0';
  signal rst_n   : std_logic := '0';
  signal seconds : integer range 0 to 59;
  signal minutes : integer range 0 to 59;
  signal hours   : integer range 0 to 23;
  signal done    : boolean := false;
begin

  clk_proc : process
  begin
    while not done loop
      clk <= '0'; wait for CLK_PERIOD / 2;
      clk <= '1'; wait for CLK_PERIOD / 2;
    end loop;
    wait;
  end process;

  dut : entity work.digital_clock
    port map (clk => clk, rst_n => rst_n,
              seconds => seconds, minutes => minutes, hours => hours);

  stim : process
    variable t : integer;

    -- n rising edges, then the falling edge, so the new values are stable
    procedure cycles (n : integer) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
      wait until falling_edge(clk);
    end procedure;
  begin
    -- 1. reset: everything goes to 00:00:00
    cycles(3);
    assert seconds = 0 and minutes = 0 and hours = 0
      report "reset did not give 00:00:00" severity failure;

    rst_n <= '1';                             -- released at a falling edge

    -- 2. count a full day (86400 cycles) and check every single cycle,
    --    including the roll-overs 59 s -> 1 min, 59 min -> 1 h and 23:59:59 -> 00:00:00
    for k in 1 to 86400 loop
      cycles(1);
      assert seconds = k mod 60
        report "seconds wrong" severity failure;
      assert minutes = (k / 60) mod 60
        report "minutes wrong" severity failure;
      assert hours = (k / 3600) mod 24
        report "hours wrong" severity failure;
    end loop;

    -- 3. run 02:05 into the next day, then reset in the middle
    cycles(125);
    assert minutes = 2 and seconds = 5
      report "clock not at 00:02:05 before reset" severity failure;

    rst_n <= '0';
    cycles(1);
    assert seconds = 0 and minutes = 0 and hours = 0
      report "mid-run reset did not give 00:00:00" severity failure;

    -- 4. after the reset is released, the clock continues on the next cycle
    rst_n <= '1';
    cycles(1);
    assert seconds = 1 and minutes = 0 and hours = 0
      report "clock did not continue after reset" severity failure;
    cycles(1);
    assert seconds = 2
      report "clock stopped counting after reset" severity failure;

    done <= true;
    wait;
  end process;

end architecture;
