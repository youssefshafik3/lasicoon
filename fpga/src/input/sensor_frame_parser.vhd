-------------------------------------------------------------------------------
-- File    : sensor_frame_parser.vhd
-- Owner   : Person B
-- Purpose : Assembles the bytes coming out of uart_rx into frames
--           0xFF, x, y, ldr and keeps a watchdog on the link.
--           It does NOT apply a deadzone or any threshold.
--
-- Generics: WATCHDOG_MS : integer := 100   (ms without a complete frame
--                                           before link_lost goes high)
--
-- Ports   : clk, rst_n      clock and synchronous active-low reset
--           tick_1ms        1-clock pulse every millisecond (from tick_gen)
--           data            byte from uart_rx
--           data_valid      1-clock pulse from uart_rx: "data" is new
--           x, y, ldr       unsigned 8-bit values of the last COMPLETE frame
--           frame_ok_p      1-clock pulse each time a complete frame arrives
--           link_lost       level: '1' = no complete frame for WATCHDOG_MS
--
-- Assumptions:
--   * Data bytes are never 0xFF (the Arduino clamps them to 254), so 0xFF
--     always means "a new frame starts here".
--   * After reset link_lost = '1' until the first complete frame arrives.
--   * VHDL-93 only.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sensor_frame_parser is
  generic (
    WATCHDOG_MS : integer := 100
  );
  port (
    clk        : in  std_logic;
    rst_n      : in  std_logic;                       -- sync, active low
    tick_1ms   : in  std_logic;
    data       : in  std_logic_vector(7 downto 0);
    data_valid : in  std_logic;
    x          : out unsigned(7 downto 0);
    y          : out unsigned(7 downto 0);
    ldr        : out unsigned(7 downto 0);
    frame_ok_p : out std_logic;                       -- pulse, 1 clock
    link_lost  : out std_logic                        -- level
  );
end entity;

architecture rtl of sensor_frame_parser is

  -- which byte of the frame we expect next:
  -- 0 = waiting for the 0xFF header, 1 = x, 2 = y, 3 = ldr
  signal idx    : integer range 0 to 3 := 0;

  -- x and y are kept here until the whole frame has arrived
  signal x_tmp  : unsigned(7 downto 0) := (others => '0');
  signal y_tmp  : unsigned(7 downto 0) := (others => '0');

  -- counts milliseconds since the last complete frame
  signal wd_cnt : unsigned(15 downto 0) := (others => '0');

begin

  process (clk)
  begin
    if rising_edge(clk) then

      -- pulse defaults to 0 every clock
      frame_ok_p <= '0';

      if rst_n = '0' then
        idx       <= 0;
        x_tmp     <= (others => '0');
        y_tmp     <= (others => '0');
        wd_cnt    <= (others => '0');
        x         <= to_unsigned(128, 8);              -- stick centered
        y         <= to_unsigned(128, 8);
        ldr       <= to_unsigned(255, 8);              -- "bright" = not night
        link_lost <= '1';                              -- nothing received yet
      else

        -- 1) watchdog: count milliseconds, raise link_lost when too long
        if tick_1ms = '1' then
          if wd_cnt = to_unsigned(WATCHDOG_MS - 1, wd_cnt'length) then
            link_lost <= '1';
          else
            wd_cnt <= wd_cnt + 1;
          end if;
        end if;

        -- 2) a new byte arrived from uart_rx
        --    (this block comes AFTER the watchdog, so if a frame completes
        --     in the same clock as a tick, the frame wins: last assignment
        --     wins in a process)
        if data_valid = '1' then
          if data = x"FF" then
            idx <= 1;                                  -- header: (re)start
          else
            case idx is
              when 0 =>
                null;                                  -- no header yet: ignore
              when 1 =>
                x_tmp <= unsigned(data);
                idx   <= 2;
              when 2 =>
                y_tmp <= unsigned(data);
                idx   <= 3;
              when 3 =>
                x          <= x_tmp;                   -- publish whole frame
                y          <= y_tmp;
                ldr        <= unsigned(data);
                frame_ok_p <= '1';
                link_lost  <= '0';
                wd_cnt     <= (others => '0');
                idx        <= 0;
              when others =>
                null;
            end case;
          end if;
        end if;

      end if;
    end if;
  end process;

end architecture;
