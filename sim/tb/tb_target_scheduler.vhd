-- ============================================================================
-- tb_target_scheduler.vhd  (Person D)
-- Checks:
--   Mode 1: all five targets active while PLAYING, none otherwise, no timeouts.
--   Mode 2: never more than one active, never the same target twice in a row
--           (monitor process, checked on EVERY clock), on-time length,
--           shrinking every SHRINK_EVERY hits down to the floor, timeouts
--           are not hits, wrong-index hits are ignored, leaving PLAYING
--           clears the target and restores the on-time, and a 1005-event run.
-- Scaled values: tick every 4 clocks. On-time 8 -> 6 -> 4 -> 3 (step 2, floor 3,
-- shrink every 2 hits). Gap 1..3 ticks.
-- The target servos are modelled by up_ok = active delayed by 3 clocks.
-- rnd comes from a fixed-seed 16-bit LFSR, so the run is repeatable.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity tb_target_scheduler is
end entity tb_target_scheduler;

architecture sim of tb_target_scheduler is
    constant CLK_PERIOD : time    := 20 ns;
    constant TICK_CLKS  : natural := 4;

    signal clk       : std_logic := '0';
    signal rst_n     : std_logic := '0';
    signal tick_1ms  : std_logic := '0';
    signal state     : game_state_t := S_OFF;
    signal mode      : std_logic := '0';
    signal up_ok     : std_logic_vector(N_TARGETS - 1 downto 0) := (others => '0');
    signal hit_p     : std_logic := '0';
    signal hit_idx   : unsigned(2 downto 0) := (others => '0');
    signal rnd       : std_logic_vector(15 downto 0) := x"ACE1";
    signal active    : std_logic_vector(N_TARGETS - 1 downto 0);
    signal timeout_p : std_logic;
    signal done      : boolean := false;

    signal a1, a2    : std_logic_vector(N_TARGETS - 1 downto 0) := (others => '0');
    signal act_count : natural := 0;   -- activations seen by the monitor
    signal to_count  : natural := 0;   -- timeouts seen by the monitor

    function popcount(v : std_logic_vector) return natural is
        variable n : natural := 0;
    begin
        for i in v'range loop
            if v(i) = '1' then
                n := n + 1;
            end if;
        end loop;
        return n;
    end function;
begin
    clk_proc : process
    begin
        while not done loop
            clk <= '0'; wait for CLK_PERIOD / 2;
            clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    dut : entity work.target_scheduler
        generic map (
            GAP_MIN_MS     => 1,
            GAP_SPAN_MS    => 3,
            ONTIME_INIT_MS => 8,
            ONTIME_MIN_MS  => 3,
            ONTIME_STEP_MS => 2,
            SHRINK_EVERY   => 2
        )
        port map (
            clk       => clk,
            rst_n     => rst_n,
            tick_1ms  => tick_1ms,
            state     => state,
            mode      => mode,
            up_ok     => up_ok,
            hit_p     => hit_p,
            hit_idx   => hit_idx,
            rnd       => rnd,
            active    => active,
            timeout_p => timeout_p
        );

    -- one tick pulse every TICK_CLKS clocks
    tick_proc : process(clk)
        variable c : natural := 0;
    begin
        if rising_edge(clk) then
            if c = TICK_CLKS - 1 then
                tick_1ms <= '1';
                c := 0;
            else
                tick_1ms <= '0';
                c := c + 1;
            end if;
        end if;
    end process;

    -- fixed-seed LFSR, taps 16,15,13,4
    rnd_proc : process(clk)
        variable l  : std_logic_vector(15 downto 0) := x"ACE1";
        variable fb : std_logic;
    begin
        if rising_edge(clk) then
            fb := l(15) xor l(14) xor l(12) xor l(3);
            l  := l(14 downto 0) & fb;
            rnd <= l;
        end if;
    end process;

    -- target servo model: up_ok rises 3 clocks after active, falls at once
    servo_model : process(clk)
    begin
        if rising_edge(clk) then
            a1    <= active;
            a2    <= a1;
            up_ok <= active and a1 and a2;
        end if;
    end process;

    -- Monitor, every clock, Mode 2 while PLAYING
    monitor : process(clk)
        variable prev : integer := -1;
        variable was  : boolean := false;
        variable idx  : integer;
    begin
        if rising_edge(clk) then
            if state /= S_PLAYING then
                prev := -1;
                was  := false;
            elsif mode = '1' then
                assert popcount(active) <= 1
                    report "more than one target active in Mode 2" severity failure;

                if timeout_p = '1' then
                    to_count <= to_count + 1;
                    assert popcount(active) = 0
                        report "target must be cleared when timeout_p fires" severity failure;
                end if;

                if popcount(active) = 1 then
                    if not was then
                        idx := -1;
                        for i in 0 to N_TARGETS - 1 loop
                            if active(i) = '1' then
                                idx := i;
                            end if;
                        end loop;
                        assert idx /= prev
                            report "same target chosen twice in a row" severity failure;
                        prev := idx;
                        act_count <= act_count + 1;
                    end if;
                    was := true;
                else
                    was := false;
                end if;
            else
                was := false;
            end if;
        end if;
    end process;

    stim : process
        variable idx : integer;

        procedure edges(constant n : in natural) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        -- wait until some target is active and report which one
        procedure wait_active(variable which : out integer) is
        begin
            if active = "00000" then
                wait until active /= "00000" for 200 * CLK_PERIOD;
            end if;
            assert active /= "00000"
                report "scheduler never activated a target" severity failure;
            which := -1;
            for i in 0 to N_TARGETS - 1 loop
                if active(i) = '1' then
                    which := i;
                end if;
            end loop;
        end procedure;

        -- hit the active target once it is LIVE
        procedure do_hit is
            variable which : integer;
        begin
            wait_active(which);
            wait until up_ok /= "00000" for 50 * CLK_PERIOD;
            assert up_ok /= "00000" report "up_ok never rose" severity failure;
            edges(2);
            hit_idx <= to_unsigned(which, 3);
            hit_p   <= '1';
            edges(1);
            hit_p   <= '0';
            edges(2);
            assert active = "00000"
                report "a hit must retire the target" severity failure;
            assert timeout_p = '0'
                report "a hit must not cause timeout_p" severity failure;
        end procedure;

        -- let the active target expire; its on-time must be n ticks
        -- (n * TICK_CLKS plus 1..4 clocks of tick phase, with 1 clock slack)
        procedure do_timeout(constant n : in natural) is
            variable which : integer;
            variable t0    : time;
            variable dur   : time;
        begin
            wait_active(which);
            t0 := now;
            wait until timeout_p = '1' for (n + 6) * TICK_CLKS * CLK_PERIOD;
            assert timeout_p = '1' report "target never timed out" severity failure;
            dur := now - t0;
            assert dur >= (n * TICK_CLKS) * CLK_PERIOD
                report "on-time shorter than expected" severity failure;
            assert dur <= (n * TICK_CLKS + 5) * CLK_PERIOD
                report "on-time longer than expected" severity failure;
            edges(2);
            assert timeout_p = '0' report "timeout_p must last one clock" severity failure;
            assert active = "00000" report "timeout must retire the target" severity failure;
        end procedure;

        -- same as do_timeout but without the length check (stress run)
        procedure just_timeout is
        begin
            wait until timeout_p = '1' for 400 * CLK_PERIOD;
            assert timeout_p = '1' report "target never timed out" severity failure;
            edges(2);
        end procedure;
    begin
        rst_n <= '0';
        edges(3);
        rst_n <= '1';
        edges(2);

        -- ---------------- Mode 1 ----------------
        assert active = "00000" report "nothing active in S_OFF" severity failure;
        mode  <= '0';
        state <= S_PLAYING;
        edges(5);
        for i in 1 to 100 loop
            edges(1);
            assert active = "11111" report "Mode 1: all targets must be active" severity failure;
            assert timeout_p = '0' report "Mode 1: no timeouts allowed" severity failure;
        end loop;

        state <= S_READY;
        edges(4);
        assert active = "00000" report "targets must clear outside PLAYING" severity failure;

        -- ---------------- Mode 2 ----------------
        mode  <= '1';
        state <= S_PLAYING;

        do_timeout(8);                 -- initial on-time
        do_hit;                        -- hit 1: no shrink yet
        do_timeout(8);                 -- a timeout is not a hit
        do_hit;                        -- hit 2: shrink 8 -> 6
        do_timeout(6);
        do_hit; do_hit;                -- 6 -> 4
        do_timeout(4);
        do_hit; do_hit;                -- 4 -> 3 (floor)
        do_timeout(3);
        do_hit; do_hit;                -- stays at the floor
        do_timeout(3);

        -- a hit on another target is ignored
        wait_active(idx);
        wait until up_ok /= "00000" for 50 * CLK_PERIOD;
        edges(2);
        hit_idx <= to_unsigned((idx + 1) mod N_TARGETS, 3);
        hit_p   <= '1';
        edges(1);
        hit_p   <= '0';
        edges(1);
        assert active(idx) = '1' report "hit on a wrong target must be ignored" severity failure;
        wait until timeout_p = '1' for 100 * CLK_PERIOD;
        assert timeout_p = '1' report "target should still time out" severity failure;
        edges(2);

        -- leaving PLAYING mid-target clears it, no timeout, and restores on-time
        wait_active(idx);
        state <= S_GAME_OVER;
        edges(3);
        assert active = "00000" report "GAME_OVER must clear the target" severity failure;
        assert timeout_p = '0' report "no timeout when the game ends" severity failure;
        edges(4);
        state <= S_PLAYING;
        do_timeout(8);                 -- on-time is back to the initial value

        -- ---------------- 1005 events ----------------
        for i in 1 to 1005 loop
            if (i mod 2) = 1 then
                do_hit;
            else
                just_timeout;
            end if;
        end loop;

        assert act_count >= 1005 report "fewer than 1005 activations seen" severity failure;
        assert to_count  >= 500  report "too few timeouts seen" severity failure;

        report "tb_target_scheduler: PASS" severity note;
        done <= true;
        wait;
    end process;
end architecture sim;
