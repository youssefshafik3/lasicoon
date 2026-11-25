-------------------------------------------------------------------------------
-- File    : tb_joystick_decoder.vhd
-- Owner   : Person B
-- Purpose : Self-checking testbench for joystick_decoder. Ends by itself.
-- Tests   : 1) link_lost forces all outputs low
--           2) centre = no direction
--           3) each direction alone, and a diagonal
--           4) deadzone edges (100 and 155 are still inside the deadzone)
--           5) hysteresis on the low side and on the high side
--           6) link_lost clears the outputs and they come back afterwards
--           7) INVERT_X / INVERT_Y swap left/right and up/down
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_joystick_decoder is end entity;

architecture sim of tb_joystick_decoder is

  constant CLK_PERIOD : time := 20 ns;

  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';
  signal done  : boolean   := false;

  signal x, y      : unsigned(7 downto 0) := to_unsigned(128, 8);
  signal link_lost : std_logic := '1';

  -- normal decoder
  signal left, right, up, down     : std_logic;
  -- decoder with both axes inverted
  signal left2, right2, up2, down2 : std_logic;

begin

  clk_proc : process
  begin
    while not done loop
      clk <= '0'; wait for CLK_PERIOD / 2;
      clk <= '1'; wait for CLK_PERIOD / 2;
    end loop;
    wait;
  end process;

  dut : entity work.joystick_decoder
    port map (
      clk => clk, rst_n => rst_n, x => x, y => y, link_lost => link_lost,
      left => left, right => right, up => up, down => down
    );

  dut_inv : entity work.joystick_decoder
    generic map (INVERT_X => true, INVERT_Y => true)
    port map (
      clk => clk, rst_n => rst_n, x => x, y => y, link_lost => link_lost,
      left => left2, right => right2, up => up2, down => down2
    );

  stim : process

    -- put new joystick values on the inputs and let them settle
    procedure apply (xv, yv : in integer) is
    begin
      x <= to_unsigned(xv, 8);
      y <= to_unsigned(yv, 8);
      wait for 4 * CLK_PERIOD;
    end procedure;

    -- check the four outputs of the normal decoder
    procedure expect (l, r, u, d : in std_logic; msg : in string) is
    begin
      assert left = l and right = r and up = u and down = d
        report msg severity failure;
    end procedure;

  begin
    wait for 100 ns; rst_n <= '1';
    wait for 5 * CLK_PERIOD;

    -- Test 1: link is lost at start-up, so even an extreme stick does nothing
    apply(10, 10);
    expect('0', '0', '0', '0', "link_lost must force all outputs low");

    link_lost <= '0';

    -- Test 2: centre
    apply(128, 128);
    expect('0', '0', '0', '0', "centre must give no direction");

    -- Test 3: single directions and a diagonal
    apply(50, 128);  expect('1', '0', '0', '0', "x=50 must be left only");
    apply(200, 128); expect('0', '1', '0', '0', "x=200 must be right only");
    apply(128, 50);  expect('0', '0', '1', '0', "y=50 must be up only");
    apply(128, 200); expect('0', '0', '0', '1', "y=200 must be down only");
    apply(50, 50);   expect('1', '0', '1', '0', "x=50,y=50 must be left+up");
    apply(128, 128); expect('0', '0', '0', '0', "back to centre");

    -- Test 4: deadzone edges
    apply(100, 128); expect('0', '0', '0', '0', "x=100 is still in the deadzone");
    apply(99, 128);  expect('1', '0', '0', '0', "x=99 must be left");
    apply(128, 128);
    apply(155, 128); expect('0', '0', '0', '0', "x=155 is still in the deadzone");
    apply(156, 128); expect('0', '1', '0', '0', "x=156 must be right");
    apply(128, 128);

    -- Test 5a: hysteresis, low side (ON below 100, OFF from 108 up)
    apply(50, 128);  expect('1', '0', '0', '0', "hyst low: left on");
    apply(104, 128); expect('1', '0', '0', '0', "hyst low: left must hold at 104");
    apply(108, 128); expect('0', '0', '0', '0', "hyst low: left off at 108");
    apply(104, 128); expect('0', '0', '0', '0', "hyst low: must stay off at 104");

    -- Test 5b: hysteresis, high side (ON above 155, OFF from 147 down)
    apply(200, 128); expect('0', '1', '0', '0', "hyst high: right on");
    apply(150, 128); expect('0', '1', '0', '0', "hyst high: right must hold at 150");
    apply(147, 128); expect('0', '0', '0', '0', "hyst high: right off at 147");
    apply(150, 128); expect('0', '0', '0', '0', "hyst high: must stay off at 150");

    -- Test 6: link lost in the middle, then the link returns
    apply(50, 128);  expect('1', '0', '0', '0', "left on before link loss");
    link_lost <= '1';
    wait for 4 * CLK_PERIOD;
    expect('0', '0', '0', '0', "link_lost must clear left");
    link_lost <= '0';
    wait for 4 * CLK_PERIOD;
    expect('1', '0', '0', '0', "left must return after the link returns");

    -- Test 7: inverted decoder (x=50,y=50 -> right + down)
    apply(50, 50);
    assert left2 = '0' and right2 = '1' and up2 = '0' and down2 = '1'
      report "INVERT_X/INVERT_Y did not swap the directions" severity failure;

    report "tb_joystick_decoder PASSED" severity note;
    done <= true;
    wait;
  end process;

end architecture;
