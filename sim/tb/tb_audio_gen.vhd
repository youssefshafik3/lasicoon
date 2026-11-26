-- ============================================================================
-- File        : tb_audio_gen.vhd
-- Owner       : Person E
-- Purpose     : Self-checking testbench for audio_gen (tone generation and
--               priority preemption: game_over > streak > timeout > hit > miss).
-- Assumptions : VHDL-93 compliant; uses HALF_PERIOD_DIV = 1000 for fast sim.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_audio_gen is
end entity tb_audio_gen;

architecture sim of tb_audio_gen is
    constant CLK_PERIOD : time := 20 ns; -- 50 MHz

    signal clk         : std_logic := '0';
    signal rst_n       : std_logic := '0';
    signal tick_1ms    : std_logic := '0';
    signal hit_p       : std_logic := '0';
    signal miss_p      : std_logic := '0';
    signal streak_p    : std_logic := '0';
    signal timeout_p   : std_logic := '0';
    signal game_over_p : std_logic := '0';
    signal buzzer      : std_logic;

    signal done        : boolean := false;
    signal toggle_cnt  : natural := 0;
begin

    -- 50 MHz clock generator (stops when done = true)
    clk_proc : process
    begin
        while not done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Fast 1 ms tick generator (1 pulse every 40 clocks for fast simulation)
    tick_proc : process
        variable cnt : integer range 0 to 39 := 0;
    begin
        while not done loop
            wait until rising_edge(clk);
            if rst_n = '0' then
                cnt      := 0;
                tick_1ms <= '0';
            elsif cnt = 39 then
                cnt      := 0;
                tick_1ms <= '1';
            else
                cnt      := cnt + 1;
                tick_1ms <= '0';
            end if;
        end loop;
        wait;
    end process;

    -- Count buzzer rising transitions to verify audio activity
    mon_proc : process(buzzer, rst_n)
    begin
        if rst_n = '0' then
            toggle_cnt <= 0;
        elsif rising_edge(buzzer) then
            toggle_cnt <= toggle_cnt + 1;
        end if;
    end process;

    -- Device Under Test
    dut : entity work.audio_gen
        generic map (
            HALF_PERIOD_DIV => 1000
        )
        port map (
            clk         => clk,
            rst_n       => rst_n,
            tick_1ms    => tick_1ms,
            hit_p       => hit_p,
            miss_p      => miss_p,
            streak_p    => streak_p,
            timeout_p   => timeout_p,
            game_over_p => game_over_p,
            buzzer      => buzzer
        );

    -- Stimulus and assertions
    stim : process
        variable prev_toggles : natural;
    begin
        -- Apply synchronous reset
        rst_n <= '0';
        wait for 100 ns;
        wait until rising_edge(clk);
        rst_n <= '1';
        wait for 100 ns;
        assert buzzer = '0' report "Buzzer should be low after reset" severity failure;

        -- 1. Trigger MISS (lowest priority)
        prev_toggles := toggle_cnt;
        wait until rising_edge(clk);
        miss_p <= '1';
        wait until rising_edge(clk);
        miss_p <= '0';

        wait for 20 us;
        assert toggle_cnt > prev_toggles
            report "Buzzer did not oscillate during miss pattern"
            severity failure;

        -- 2. Interrupt MISS mid-pattern with HIT (higher priority)
        prev_toggles := toggle_cnt;
        wait until rising_edge(clk);
        hit_p <= '1';
        wait until rising_edge(clk);
        hit_p <= '0';

        wait for 10 us;
        assert toggle_cnt > prev_toggles
            report "Hit pattern failed to preempt miss pattern"
            severity failure;

        -- 3. Interrupt HIT with STREAK fanfare
        prev_toggles := toggle_cnt;
        wait until rising_edge(clk);
        streak_p <= '1';
        wait until rising_edge(clk);
        streak_p <= '0';

        wait for 15 us;
        assert toggle_cnt > prev_toggles
            report "Streak pattern failed to preempt hit pattern"
            severity failure;

        -- 4. Interrupt with TIMEOUT, then GAME_OVER (highest priority)
        wait until rising_edge(clk);
        timeout_p <= '1';
        wait until rising_edge(clk);
        timeout_p <= '0';
        wait for 5 us;

        prev_toggles := toggle_cnt;
        wait until rising_edge(clk);
        game_over_p <= '1';
        wait until rising_edge(clk);
        game_over_p <= '0';

        wait for 20 us;
        assert toggle_cnt > prev_toggles
            report "Game over pattern failed to preempt timeout pattern"
            severity failure;

        -- 5. Wait for game_over pattern (600 simulated ms = 24,000 clocks) to finish
        wait for 520 us;
        assert buzzer = '0'
            report "Buzzer should return to 0 after pattern finishes"
            severity failure;

        done <= true;
        wait;
    end process;

end architecture sim;