
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lfsr_rng is
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;
    seed_load : in  std_logic;
    rnd       : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of lfsr_rng is
  constant DEFAULT_SEED : std_logic_vector(15 downto 0) := x"ACE1";  -- any non-zero value
  signal free_cnt : unsigned(15 downto 0)         := (others => '0');
  signal lfsr     : std_logic_vector(15 downto 0) := DEFAULT_SEED;
  signal feedback : std_logic;
begin

  
  feedback <= lfsr(15) xor lfsr(14) xor lfsr(12) xor lfsr(3);

  rnd <= lfsr;

  process (clk)
  begin
    if clk'EVENT and clk='1' then
      if rst_n = '0' then
        free_cnt <= (others => '0');
        lfsr     <= DEFAULT_SEED;
      else
        free_cnt <= free_cnt + 1;                 -- runs all the time

        if seed_load = '1' then
          if free_cnt = 0 then
            lfsr <= DEFAULT_SEED;                 -- never load all zeros
          else
            lfsr <= std_logic_vector(free_cnt);   -- capture the seed
          end if;
        else
          lfsr <= lfsr(14 downto 0) & feedback;   -- shift left, feedback in
        end if;
      end if;
    end if;
  end process;

end architecture;
