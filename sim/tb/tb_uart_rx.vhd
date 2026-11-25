-------------------------------------------------------------------------------
-- File    : tb_uart_rx.vhd
-- Owner   : Person B
-- Purpose : Self-checking testbench for uart_rx. Ends by itself.
-- Tests   : 1) six good bytes sent back to back (incl. 0xFF and 0x00)
--           2) framing error (stop bit low) -> framing_error, no data_valid
--           3) a short glitch on the line is ignored
--           4) a good byte still works after the error
-- Speed   : generics give 16 clocks per bit so the simulation is tiny.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_rx is end entity;

architecture sim of tb_uart_rx is

  constant CLK_PERIOD : time    := 20 ns;
  constant CPB        : integer := 16;                  -- clocks per bit
  constant BIT_T      : time    := CPB * CLK_PERIOD;

  signal clk   : std_logic := '0';
  signal rst_n : std_logic := '0';
  signal done  : boolean   := false;

  signal rx            : std_logic := '1';
  signal data          : std_logic_vector(7 downto 0);
  signal data_valid    : std_logic;
  signal framing_error : std_logic;

  signal valid_cnt : integer := 0;
  signal frame_cnt : integer := 0;
  signal last_data : std_logic_vector(7 downto 0) := (others => '0');

  type byte_array is array (0 to 5) of std_logic_vector(7 downto 0);
  constant TEST_BYTES : byte_array :=
    (x"A5", x"FF", x"00", x"3C", x"01", x"80");

begin

  clk_proc : process
  begin
    while not done loop
      clk <= '0'; wait for CLK_PERIOD / 2;
      clk <= '1'; wait for CLK_PERIOD / 2;
    end loop;
    wait;
  end process;

  -- 16 clocks/bit: CLK_FREQ / BAUD = 16
  dut : entity work.uart_rx
    generic map (CLK_FREQ => 16_000_000, BAUD => 1_000_000)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      rx            => rx,
      data          => data,
      data_valid    => data_valid,
      framing_error => framing_error
    );

  -- counts the pulses the DUT produces
  monitor : process (clk)
  begin
    if rising_edge(clk) then
      if data_valid = '1' then
        valid_cnt <= valid_cnt + 1;
        last_data <= data;
      end if;
      if framing_error = '1' then
        frame_cnt <= frame_cnt + 1;
      end if;
    end if;
  end process;

  stim : process

    -- sends one 8N1 frame, LSB first; stop_level = '0' makes a bad frame
    procedure send_byte (b : in std_logic_vector(7 downto 0);
                         stop_level : in std_logic) is
    begin
      rx <= '0'; wait for BIT_T;                        -- start bit
      for i in 0 to 7 loop
        rx <= b(i); wait for BIT_T;                     -- data bits
      end loop;
      rx <= stop_level; wait for BIT_T;                 -- stop bit
      rx <= '1';
    end procedure;

  begin
    wait for 100 ns; rst_n <= '1';
    wait for 10 * CLK_PERIOD;

    -- Test 1: good bytes, back to back
    for i in 0 to 5 loop
      send_byte(TEST_BYTES(i), '1');
      wait for 2 * CLK_PERIOD;
      assert valid_cnt = i + 1
        report "byte " & integer'image(i) & ": data_valid missing"
        severity failure;
      assert last_data = TEST_BYTES(i)
        report "byte " & integer'image(i) & ": wrong data"
        severity failure;
    end loop;
    assert frame_cnt = 0 report "unexpected framing error" severity failure;

    -- Test 2: framing error (stop bit low)
    wait for 3 * BIT_T;
    send_byte(x"5A", '0');
    wait for 4 * BIT_T;
    assert frame_cnt = 1 report "framing_error not raised" severity failure;
    assert valid_cnt = 6 report "bad frame must not give data_valid"
      severity failure;

    -- Test 3: glitch (3 clocks low) must be ignored
    rx <= '0'; wait for 3 * CLK_PERIOD; rx <= '1';
    wait for 4 * BIT_T;
    assert valid_cnt = 6 report "glitch produced data_valid" severity failure;
    assert frame_cnt = 1 report "glitch produced framing_error"
      severity failure;

    -- Test 4: receiver still works after the error and the glitch
    send_byte(x"C3", '1');
    wait for 2 * CLK_PERIOD;
    assert valid_cnt = 7 report "no byte after recovery" severity failure;
    assert last_data = x"C3" report "wrong byte after recovery"
      severity failure;

    report "tb_uart_rx PASSED" severity note;
    done <= true;
    wait;
  end process;

end architecture;
