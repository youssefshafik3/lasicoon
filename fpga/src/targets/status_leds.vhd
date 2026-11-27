-- ============================================================================
-- File:    status_leds.vhd
-- Owner:   Person D
-- Purpose: Maps game events to the red LEDs.
--            LEDR[2:0] hearts (lit = life left; Mode 2 in PLAYING/GAME_OVER only)
--            LEDR[3]   night mode
--            LEDR[4]   hit flash        (hit_p)
--            LEDR[5]   miss/timeout flash (miss_p or timeout_p)
--            LEDR[6]   streak flash     (streak_p)
--            LEDR[9:7] unused (off)
--          Flashes are stretched to FLASH_CYCLES clocks (about 200 ms).
--          Everything is off in S_OFF.
-- Ports:   clk, rst_n, state, mode, lives(1:0), night, hit_p, miss_p,
--          streak_p, timeout_p -> ledr(9:0)
-- Assumes: lives is unsigned(1 downto 0) (confirm with Person A).
-- Standard: VHDL-93
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity status_leds is
    generic (
        FLASH_CYCLES : natural := LED_FLASH_CYCLES
    );
    port (
        clk       : in  std_logic;
        rst_n     : in  std_logic;
        state     : in  game_state_t;
        mode      : in  std_logic;
        lives     : in  unsigned(1 downto 0);
        night     : in  std_logic;
        hit_p     : in  std_logic;
        miss_p    : in  std_logic;
        streak_p  : in  std_logic;
        timeout_p : in  std_logic;
        ledr      : out std_logic_vector(9 downto 0)
    );
end entity status_leds;

architecture rtl of status_leds is
    signal hit_cnt    : natural range 0 to FLASH_CYCLES := 0;
    signal miss_cnt   : natural range 0 to FLASH_CYCLES := 0;
    signal streak_cnt : natural range 0 to FLASH_CYCLES := 0;
begin
    -- flash stretchers
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                hit_cnt    <= 0;
                miss_cnt   <= 0;
                streak_cnt <= 0;
            else
                if hit_p = '1' then
                    hit_cnt <= FLASH_CYCLES;
                elsif hit_cnt > 0 then
                    hit_cnt <= hit_cnt - 1;
                end if;

                if miss_p = '1' or timeout_p = '1' then
                    miss_cnt <= FLASH_CYCLES;
                elsif miss_cnt > 0 then
                    miss_cnt <= miss_cnt - 1;
                end if;

                if streak_p = '1' then
                    streak_cnt <= FLASH_CYCLES;
                elsif streak_cnt > 0 then
                    streak_cnt <= streak_cnt - 1;
                end if;
            end if;
        end if;
    end process;

    -- output mapping (purely combinational; every input is in the list)
    process(state, mode, lives, night, hit_cnt, miss_cnt, streak_cnt)
        variable leds_v : std_logic_vector(9 downto 0);
    begin
        leds_v := (others => '0');

        if state /= S_OFF then
            if mode = '1' and (state = S_PLAYING or state = S_GAME_OVER) then
                if lives >= to_unsigned(1, 2) then
                    leds_v(0) := '1';
                end if;
                if lives >= to_unsigned(2, 2) then
                    leds_v(1) := '1';
                end if;
                if lives >= to_unsigned(3, 2) then
                    leds_v(2) := '1';
                end if;
            end if;

            leds_v(3) := night;

            if hit_cnt > 0 then
                leds_v(4) := '1';
            end if;
            if miss_cnt > 0 then
                leds_v(5) := '1';
            end if;
            if streak_cnt > 0 then
                leds_v(6) := '1';
            end if;
        end if;

        ledr <= leds_v;
    end process;
end architecture rtl;
