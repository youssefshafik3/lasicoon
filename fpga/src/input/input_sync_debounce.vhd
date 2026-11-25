
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity input_sync_debounce is
  generic (
    DEBOUNCE_MS : natural := 20;
    ACTIVE_LOW  : boolean := false
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    tick_1ms  : in  std_logic;
    raw_in    : in  std_logic;
    level_out : out std_logic;
    press_p   : out std_logic
  );
end entity;

architecture rtl of input_sync_debounce is
  signal sync1, sync2 : std_logic := '0';
  signal clean_in     : std_logic;
  signal level_r      : std_logic := '0';
  signal prev_r       : std_logic := '0';
  signal cnt          : unsigned(15 downto 0) := (others => '0');
begin

  -- invert here if the input is active-low
  clean_in <= (not sync2) when ACTIVE_LOW else sync2;

  process (clk)
  begin
    if clk'EVENT and clk = '1' then
      if rst_n = '0' then
        sync1   <= '0';
        sync2   <= '0';
        level_r <= '0';
        prev_r  <= '0';
        cnt     <= (others => '0');
      else
        -- 1) synchronizer
        sync1 <= raw_in;
        sync2 <= sync1;
	
        -- 2) debounce
        if DEBOUNCE_MS = 0 then
          level_r <= clean_in;                 -- synchronize only
        else
          if clean_in = level_r then
            cnt <= (others => '0');            -- nothing new, restart count
          elsif tick_1ms = '1' then
            if (cnt + 1) >= DEBOUNCE_MS then   -- stable long enough
              level_r <= clean_in;
              cnt     <= (others => '0');
            else
              cnt <= cnt + 1;
            end if;
          end if;
        end if;

        -- 3) remember last level for the edge detector
        prev_r <= level_r;
      end if;
    end if;
  end process;

  level_out <= level_r;
  press_p   <= level_r and (not prev_r);       -- button just pressed

end architecture;
