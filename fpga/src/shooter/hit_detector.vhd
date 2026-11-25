
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hit_detector is
  generic (
    N_TARGETS : positive := 5
  );
  port (
    clk              : in  std_logic;
    rst_n            : in  std_logic;
    rx_sync          : in  std_logic_vector(N_TARGETS-1 downto 0);
    armed            : in  std_logic_vector(N_TARGETS-1 downto 0);
    window_open      : in  std_logic;
    window_expired_p : in  std_logic;
    hit_p            : out std_logic;
    hit_idx          : out unsigned(2 downto 0);
    miss_p           : out std_logic
  );
end entity;

architecture rtl of hit_detector is
  signal found     : std_logic := '0';
  signal hit_p_r   : std_logic := '0';
  signal miss_p_r  : std_logic := '0';
  signal hit_idx_r : unsigned(2 downto 0) := (others => '0');
begin

  hit_p   <= hit_p_r;
  miss_p  <= miss_p_r;
  hit_idx <= hit_idx_r;

  process (clk)
  begin
    if clk'EVENT and clk = '1' then
      hit_p_r  <= '0';                        -- pulses default to 0 every clock
      miss_p_r <= '0';

      if rst_n = '0' then
        found     <= '0';
        hit_idx_r <= (others => '0');
      else
        if window_open = '0' then
          found <= '0';                       -- new window: allow one hit again
        elsif found = '0' then
          for i in 0 to N_TARGETS-1 loop      -- lowest index wins
            if rx_sync(i) = '0' and armed(i) = '1' then
              hit_p_r   <= '1';
              hit_idx_r <= to_unsigned(i, 3);
              found     <= '1';
              exit;
            end if;
          end loop;
        end if;

        -- window ended: it is a miss only if no hit was found in this window
        if window_expired_p = '1' and found = '0' then
          miss_p_r <= '1';
        end if;
      end if;
    end if;
  end process;

end architecture;
