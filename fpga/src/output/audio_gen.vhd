-- ============================================================================
-- File        : audio_gen.vhd
-- Owner       : Person E
-- Purpose     : Multi-tone square-wave pattern player for passive piezo buzzer.
--               Priority: game_over > streak > timeout > hit > miss.
-- Assumptions : 50 MHz clk, synchronous active-low rst_n, 1-cycle _p pulses,
--               VHDL-93 compliant.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity audio_gen is
    generic (
        HALF_PERIOD_DIV : positive := 1 -- Keep 1 for hardware; increase in sim if needed
    );
    port (
        clk         : in  std_logic;
        rst_n       : in  std_logic;
        tick_1ms    : in  std_logic;
        hit_p       : in  std_logic;
        miss_p      : in  std_logic;
        streak_p    : in  std_logic;
        timeout_p   : in  std_logic;
        game_over_p : in  std_logic;
        buzzer      : out std_logic
    );
end entity audio_gen;

architecture rtl of audio_gen is
    type pat_id_t is (PAT_NONE, PAT_MISS, PAT_HIT, PAT_TIMEOUT, PAT_STREAK, PAT_GAME_OVER);

    type step_rec_t is record
        half_period : natural; -- 50 MHz clock cycles per half-wave (0 = silence)
        dur_ms      : natural; -- Step duration in milliseconds
    end record;

    type step_table_t is array (0 to 15) of step_rec_t;

    -- Pattern table:
    --   0      : Miss (low buzz)
    --   1..2   : Hit (two rising tones)
    --   3..4   : Timeout / Player hit (two falling warning tones)
    --   5..8   : Streak (4-note special fanfare)
    --   9..11  : Game over (three descending tones)
    constant PAT_TABLE : step_table_t := (
        0  => (half_period => 100000, dur_ms => 180), -- ~250 Hz low buzz
        1  => (half_period => 28409,  dur_ms => 60),  -- ~880 Hz
        2  => (half_period => 18939,  dur_ms => 80),  -- ~1320 Hz
        3  => (half_period => 50000,  dur_ms => 100), -- ~500 Hz
        4  => (half_period => 75758,  dur_ms => 150), -- ~330 Hz
        5  => (half_period => 23878,  dur_ms => 70),  -- ~1047 Hz (C6)
        6  => (half_period => 18954,  dur_ms => 70),  -- ~1319 Hz (E6)
        7  => (half_period => 15944,  dur_ms => 70),  -- ~1568 Hz (G6)
        8  => (half_period => 11945,  dur_ms => 110), -- ~2093 Hz (C7)
        9  => (half_period => 37879,  dur_ms => 150), -- ~660 Hz
        10 => (half_period => 48077,  dur_ms => 150), -- ~520 Hz
        11 => (half_period => 67568,  dur_ms => 300), -- ~370 Hz
        others => (half_period => 0,  dur_ms => 0)
    );

    signal cur_pat     : pat_id_t := PAT_NONE;
    signal step_idx    : integer range 0 to 15 := 0;
    signal step_end    : integer range 0 to 15 := 0;
    signal ms_rem      : natural range 0 to 1023 := 0;
    signal tone_cnt    : natural range 0 to 200000 := 0;
    signal buz_reg     : std_logic := '0';

    function pat_rank(p : pat_id_t) return integer is
    begin
        case p is
            when PAT_NONE      => return 0;
            when PAT_MISS      => return 1;
            when PAT_HIT       => return 2;
            when PAT_TIMEOUT   => return 3;
            when PAT_STREAK    => return 4;
            when PAT_GAME_OVER => return 5;
        end case;
    end function;

begin

    process(clk)
        variable req_pat   : pat_id_t;
        variable start_idx : integer range 0 to 15;
        variable end_idx   : integer range 0 to 15;
        variable hp_scaled : natural;
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                cur_pat  <= PAT_NONE;
                step_idx <= 0;
                step_end <= 0;
                ms_rem   <= 0;
                tone_cnt <= 0;
                buz_reg  <= '0';
            else
                -- Priority encoder for incoming 1-cycle event pulses
                req_pat := PAT_NONE;
                if game_over_p = '1' then
                    req_pat := PAT_GAME_OVER;
                elsif streak_p = '1' then
                    req_pat := PAT_STREAK;
                elsif timeout_p = '1' then
                    req_pat := PAT_TIMEOUT;
                elsif hit_p = '1' then
                    req_pat := PAT_HIT;
                elsif miss_p = '1' then
                    req_pat := PAT_MISS;
                end if;

                -- Preempt if incoming event has strictly higher priority (or idle)
                if req_pat /= PAT_NONE and pat_rank(req_pat) > pat_rank(cur_pat) then
                    case req_pat is
                        when PAT_MISS      => start_idx := 0; end_idx := 0;
                        when PAT_HIT       => start_idx := 1; end_idx := 2;
                        when PAT_TIMEOUT   => start_idx := 3; end_idx := 4;
                        when PAT_STREAK    => start_idx := 5; end_idx := 8;
                        when PAT_GAME_OVER => start_idx := 9; end_idx := 11;
                        when others        => start_idx := 0; end_idx := 0;
                    end case;

                    cur_pat  <= req_pat;
                    step_idx <= start_idx;
                    step_end <= end_idx;
                    ms_rem   <= PAT_TABLE(start_idx).dur_ms;
                    tone_cnt <= 0;
                    buz_reg  <= '0';

                elsif cur_pat /= PAT_NONE then
                    -- Square-wave tone divider
                    hp_scaled := PAT_TABLE(step_idx).half_period / HALF_PERIOD_DIV;
                    if hp_scaled = 0 then
                        buz_reg <= '0';
                    elsif tone_cnt >= hp_scaled - 1 then
                        tone_cnt <= 0;
                        buz_reg  <= not buz_reg;
                    else
                        tone_cnt <= tone_cnt + 1;
                    end if;

                    -- Advance note duration on 1 ms ticks
                    if tick_1ms = '1' then
                        if ms_rem > 1 then
                            ms_rem <= ms_rem - 1;
                        elsif step_idx < step_end then
                            step_idx <= step_idx + 1;
                            ms_rem   <= PAT_TABLE(step_idx + 1).dur_ms;
                            tone_cnt <= 0;
                            buz_reg  <= '0';
                        else
                            cur_pat  <= PAT_NONE;
                            ms_rem   <= 0;
                            tone_cnt <= 0;
                            buz_reg  <= '0';
                        end if;
                    end if;
                else
                    buz_reg  <= '0';
                    tone_cnt <= 0;
                end if;
            end if;
        end if;
    end process;

    buzzer <= buz_reg;

end architecture rtl;