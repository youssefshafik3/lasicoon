-------------------------------------------------------------------------------
-- File    : uart_rx.vhd
-- Owner   : Person B
-- Purpose : 8N1 UART receiver. Turns the serial line from the Arduino into
--           bytes. It does NOT know what the bytes mean.
--
-- Generics: CLK_FREQ : integer := 50_000_000   (board clock in Hz)
--           BAUD     : integer := 9600
--
-- Ports   : clk           in  std_logic   50 MHz board clock
--           rst_n         in  std_logic   synchronous, active-low reset
--           rx            in  std_logic   RAW pin from the Arduino (idle = '1')
--           data          out std_logic_vector(7 downto 0)  last good byte
--           data_valid    out std_logic   1-clock pulse: "data" holds a new byte
--           framing_error out std_logic   1-clock pulse: stop bit was not '1'
--
-- Assumptions:
--   * Format is 8 data bits, no parity, 1 stop bit, LSB first.
--   * CLK_FREQ / BAUD >= 4 (true for 50 MHz / 9600 = 5208 clocks per bit).
--   * VHDL-93 only. Counters use unsigned (ieee.numeric_std).
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
  generic (
    CLK_FREQ : integer := 50_000_000;
    BAUD     : integer := 9600
  );
  port (
    clk           : in  std_logic;
    rst_n         : in  std_logic;                      -- sync, active low
    rx            : in  std_logic;                      -- raw pin, idle high
    data          : out std_logic_vector(7 downto 0);
    data_valid    : out std_logic;                      -- pulse, 1 clock
    framing_error : out std_logic                       -- pulse, 1 clock
  );
end entity;

architecture rtl of uart_rx is

  constant CLKS_PER_BIT : integer := CLK_FREQ / BAUD;   -- 5208 at 50MHz/9600
  constant HALF_BIT     : integer := CLKS_PER_BIT / 2;

  type uart_state_t is (IDLE, START, DATA_BITS, STOP, RECOVER);
  signal state : uart_state_t := IDLE;

  signal rx_s1, rx_s2 : std_logic := '1';               -- 2-FF synchronizer
  signal cnt          : unsigned(15 downto 0) := (others => '0');
  signal bit_idx      : integer range 0 to 7 := 0;
  signal shreg        : std_logic_vector(7 downto 0) := (others => '0');

begin

  process (clk)
  begin
    if rising_edge(clk) then

      -- pulses default to 0 every clock
      data_valid    <= '0';
      framing_error <= '0';

      -- synchronizer: the raw pin is asynchronous to our clock
      rx_s1 <= rx;
      rx_s2 <= rx_s1;

      if rst_n = '0' then
        state    <= IDLE;
        cnt      <= (others => '0');
        bit_idx  <= 0;
        shreg    <= (others => '0');
        data     <= (others => '0');
        rx_s1    <= '1';
        rx_s2    <= '1';
      else
        case state is

          -- waiting for the line to fall (start bit)
          when IDLE =>
            cnt     <= (others => '0');
            bit_idx <= 0;
            if rx_s2 = '0' then
              state <= START;
            end if;

          -- wait half a bit, then re-check the line is still low
          -- (rejects short glitches). After this we sit in the MIDDLE
          -- of the start bit, so a full bit later is the middle of bit 0.
          when START =>
            if cnt = to_unsigned(HALF_BIT - 1, cnt'length) then
              cnt <= (others => '0');
              if rx_s2 = '0' then
                state <= DATA_BITS;
              else
                state <= IDLE;                          -- it was a glitch
              end if;
            else
              cnt <= cnt + 1;
            end if;

          -- sample each data bit in the middle of its bit time, LSB first
          when DATA_BITS =>
            if cnt = to_unsigned(CLKS_PER_BIT - 1, cnt'length) then
              cnt          <= (others => '0');
              shreg(bit_idx) <= rx_s2;
              if bit_idx = 7 then
                state <= STOP;
              else
                bit_idx <= bit_idx + 1;
              end if;
            else
              cnt <= cnt + 1;
            end if;

          -- sample the stop bit, it must be '1'
          when STOP =>
            if cnt = to_unsigned(CLKS_PER_BIT - 1, cnt'length) then
              cnt <= (others => '0');
              if rx_s2 = '1' then
                data       <= shreg;
                data_valid <= '1';
                state      <= IDLE;
              else
                framing_error <= '1';
                state         <= RECOVER;
              end if;
            else
              cnt <= cnt + 1;
            end if;

          -- after a framing error, wait for the line to go high again
          -- so we do not start decoding garbage from the middle of a byte
          when RECOVER =>
            if rx_s2 = '1' then
              state <= IDLE;
            end if;

        end case;
      end if;

    end if;
  end process;

end architecture;
