-- ============================================================================
-- File:    target_scheduler.vhd
-- Owner:   Person D
-- Purpose: Decides which targets are active.
--          Mode 1 (mode = '0'): all targets active while state = S_PLAYING.
--          Mode 2 (mode = '1'): one target at a time.
--                GAP  : wait a random time (GAP_MIN_MS + rnd mod GAP_SPAN_MS)
--                RISE : pick a random target (never the same as the previous
--                       one), set active(idx), wait for up_ok(idx)
--                LIVE : count down ontime_ms. A hit on idx retires the target
--                       and counts toward shrinking ontime_ms. Expiry retires
--                       the target and pulses timeout_p (one clock).
--          Outside S_PLAYING everything resets (active = 0, on-time restored,
--          previous target forgotten), so each new game starts fresh.
-- Ports:   clk, rst_n, tick_1ms, state, mode, up_ok(4:0), hit_p,
--          hit_idx(2:0), rnd(15:0) -> active(4:0), timeout_p
-- Assumes: all ms values <= 65_535; N_TARGETS >= 2.
--          rnd is a std_logic_vector(15 downto 0) (confirm with Person C).
-- Standard: VHDL-93
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity target_scheduler is
    generic (
        GAP_MIN_MS      : natural := SCHED_GAP_MIN_MS;
        GAP_SPAN_MS     : natural := SCHED_GAP_SPAN_MS;
        ONTIME_INIT_MS  : natural := SCHED_ONTIME_INIT_MS;
        ONTIME_MIN_MS   : natural := SCHED_ONTIME_MIN_MS;
        ONTIME_STEP_MS  : natural := SCHED_ONTIME_STEP_MS;
        SHRINK_EVERY    : natural := SCHED_SHRINK_EVERY   -- 0 = never shrink
    );
    port (
        clk       : in  std_logic;
        rst_n     : in  std_logic;
        tick_1ms  : in  std_logic;
        state     : in  game_state_t;
        mode      : in  std_logic;
        up_ok     : in  std_logic_vector(N_TARGETS - 1 downto 0);
        hit_p     : in  std_logic;
        hit_idx   : in  unsigned(2 downto 0);
        rnd       : in  std_logic_vector(15 downto 0);
        active    : out std_logic_vector(N_TARGETS - 1 downto 0);
        timeout_p : out std_logic
    );
end entity target_scheduler;

architecture rtl of target_scheduler is
    type sched_state_t is (ST_GAP, ST_RISE, ST_LIVE);
    signal st         : sched_state_t := ST_GAP;
    signal active_reg : std_logic_vector(N_TARGETS - 1 downto 0) := (others => '0');
    signal timeout_r  : std_logic := '0';
    signal cur_idx    : natural range 0 to N_TARGETS - 1 := 0;
    signal last_idx   : natural range 0 to N_TARGETS := N_TARGETS;  -- N_TARGETS = none yet
    signal ms_cnt     : natural range 0 to 65535 := 1;
    signal ontime_ms  : natural range 0 to 65535 := ONTIME_INIT_MS;
    signal hit_cnt    : natural range 0 to 65535 := 0;

    -- Uses all 16 random bits so a 1000 ms span is really covered.
    function calc_gap_ms(rnd_vec : std_logic_vector(15 downto 0)) return natural is
    begin
        if GAP_SPAN_MS = 0 then
            return GAP_MIN_MS;
        end if;
        return GAP_MIN_MS + (to_integer(unsigned(rnd_vec)) mod GAP_SPAN_MS);
    end function;

    -- Never returns prev. With prev = N_TARGETS (none yet) any target is allowed.
    -- Otherwise a number in 0..N-2 is drawn and values >= prev are shifted up by
    -- one, which keeps all remaining targets equally likely.
    function pick_target(rnd_vec : std_logic_vector(15 downto 0);
                         prev    : natural) return natural is
        variable raw  : natural;
        variable cand : natural;
    begin
        raw := to_integer(unsigned(rnd_vec(7 downto 0)));
        if prev >= N_TARGETS then
            return raw mod N_TARGETS;
        end if;
        cand := raw mod (N_TARGETS - 1);
        if cand >= prev then
            return cand + 1;
        else
            return cand;
        end if;
    end function;
begin
    active    <= active_reg;
    timeout_p <= timeout_r;

    process(clk)
        variable picked : natural range 0 to N_TARGETS - 1;
    begin
        if rising_edge(clk) then
            timeout_r <= '0';

            if rst_n = '0' or state /= S_PLAYING then
                -- idle / reset: restore everything for the next game
                active_reg <= (others => '0');
                st         <= ST_GAP;
                last_idx   <= N_TARGETS;
                ontime_ms  <= ONTIME_INIT_MS;
                hit_cnt    <= 0;
                ms_cnt     <= calc_gap_ms(rnd);

            elsif mode = '0' then
                -- Mode 1: every target is up for the whole round
                active_reg <= (others => '1');
                st         <= ST_GAP;
                ms_cnt     <= calc_gap_ms(rnd);

            else
                -- Mode 2
                case st is
                    when ST_GAP =>
                        active_reg <= (others => '0');
                        if ms_cnt = 0 then
                            picked := pick_target(rnd, last_idx);
                            cur_idx    <= picked;
                            last_idx   <= picked;
                            active_reg(picked) <= '1';
                            st <= ST_RISE;
                        elsif tick_1ms = '1' then
                            ms_cnt <= ms_cnt - 1;
                        end if;

                    when ST_RISE =>
                        active_reg <= (others => '0');
                        active_reg(cur_idx) <= '1';
                        if up_ok(cur_idx) = '1' then
                            ms_cnt <= ontime_ms;
                            st     <= ST_LIVE;
                        end if;

                    when ST_LIVE =>
                        active_reg <= (others => '0');
                        active_reg(cur_idx) <= '1';

                        if hit_p = '1' and to_integer(hit_idx) = cur_idx then
                            -- hit: retire target, maybe shorten the on-time
                            active_reg <= (others => '0');
                            if SHRINK_EVERY > 0 then
                                if hit_cnt + 1 >= SHRINK_EVERY then
                                    hit_cnt <= 0;
                                    if ontime_ms > ONTIME_MIN_MS + ONTIME_STEP_MS then
                                        ontime_ms <= ontime_ms - ONTIME_STEP_MS;
                                    else
                                        ontime_ms <= ONTIME_MIN_MS;
                                    end if;
                                else
                                    hit_cnt <= hit_cnt + 1;
                                end if;
                            end if;
                            ms_cnt <= calc_gap_ms(rnd);
                            st     <= ST_GAP;

                        elsif tick_1ms = '1' then
                            if ms_cnt <= 1 then
                                -- target ran out of time
                                active_reg <= (others => '0');
                                timeout_r  <= '1';
                                ms_cnt     <= calc_gap_ms(rnd);
                                st         <= ST_GAP;
                            else
                                ms_cnt <= ms_cnt - 1;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture rtl;
