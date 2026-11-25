
library ieee;
use ieee.std_logic_1164.all;

entity digital_clock is
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;
    seconds : out integer range 0 to 59;
    minutes : out integer range 0 to 59;
    hours   : out integer range 0 to 23
  );
end entity;

architecture rtl of digital_clock is
  signal sec_r : integer range 0 to 59 := 0;
  signal min_r : integer range 0 to 59 := 0;
  signal hr_r  : integer range 0 to 23 := 0;
begin

  seconds <= sec_r;
  minutes <= min_r;
  hours   <= hr_r;

  process (clk)
  begin
    if clk'EVENT and clk='1' then
      if rst_n = '0' then
        sec_r <= 0;
        min_r <= 0;
        hr_r  <= 0;
      else
        if sec_r = 59 then
          sec_r <= 0;
          if min_r = 59 then
            min_r <= 0;
            if hr_r = 23 then
              hr_r <= 0;
            else
              hr_r <= hr_r + 1;
            end if;
          else
            min_r <= min_r + 1;
          end if;
        else
          sec_r <= sec_r + 1;
        end if;
      end if;
    end if;
  end process;

end architecture;
