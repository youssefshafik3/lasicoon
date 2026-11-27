-- ============================================================================
-- tb_servo_pwm.vhd  (Person D)
-- Checks: enable low = pwm low, frame_tick is 1 clock wide, frame period,
--         pulse width, lower and upper clamp, latching at frame start.
-- Scaled generics: frame 100 clocks, limits 10..30.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_servo_pwm is
end entity tb_servo_pwm;

architecture sim of tb_servo_pwm is
    constant CLK_PERIOD   : time    := 20 ns;
    constant TB_FRAME_CYC : natural := 100;
    constant TB_MIN       : natural := 10;
    constant TB_MAX       : natural := 30;

    signal clk          : std_logic := '0';
    signal rst_n        : std_logic := '0';
    signal enable       : std_logic := '0';
    signal pulse_cycles : unsigned(19 downto 0) := to_unsigned(20, 20);
    signal pwm          : std_logic;
    signal frame_tick   : std_logic;
    signal done         : boolean := false;
begin
    clk_proc : process
    begin
        while not done loop
            clk <= '0'; wait for CLK_PERIOD / 2;
            clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    dut : entity work.servo_pwm
        generic map (
            FRAME_CYCLES => TB_FRAME_CYC,
            MIN_PULSE    => TB_MIN,
            MAX_PULSE    => TB_MAX
        )
        port map (
            clk          => clk,
            rst_n        => rst_n,
            enable       => enable,
            pulse_cycles => pulse_cycles,
            pwm          => pwm,
            frame_tick   => frame_tick
        );

    stim : process
        variable t0  : time;
        variable cnt : natural;

        -- Wait for a frame start, then count pwm-high clocks over one frame.
        procedure measure_frame(variable high : out natural) is
        begin
            wait until rising_edge(frame_tick);
            high := 0;
            for i in 1 to TB_FRAME_CYC loop
                wait until rising_edge(clk);
                if pwm = '1' then
                    high := high + 1;
                end if;
            end loop;
        end procedure;

        -- Request a width, let it latch (first frame may still be the old one),
        -- then measure the following frame.
        procedure set_and_measure(constant req : in natural; variable high : out natural) is
            variable dummy : natural;
        begin
            pulse_cycles <= to_unsigned(req, 20);
            measure_frame(dummy);
            measure_frame(high);
        end procedure;
    begin
        rst_n <= '0'; enable <= '0';
        wait for 3 * CLK_PERIOD;
        rst_n <= '1';

        -- 1. disabled: pwm stays low for two frames (one clock of lag allowed)
        wait until rising_edge(clk);
        for i in 1 to 2 * TB_FRAME_CYC loop
            wait until rising_edge(clk);
            assert pwm = '0' report "pwm must be low while enable = 0" severity failure;
        end loop;

        -- 2. frame_tick is exactly one clock wide
        wait until rising_edge(frame_tick);
        t0 := now;
        wait until falling_edge(frame_tick);
        assert (now - t0) = CLK_PERIOD
            report "frame_tick must be exactly one clock wide" severity failure;

        -- 3. frame period
        wait until rising_edge(frame_tick);
        t0 := now;
        wait until rising_edge(frame_tick);
        assert (now - t0) = TB_FRAME_CYC * CLK_PERIOD
            report "unexpected PWM frame period" severity failure;

        -- 4. pulse widths
        enable <= '1';
        set_and_measure(20, cnt);
        assert cnt = 20 report "width 20 expected" severity failure;

        set_and_measure(15, cnt);
        assert cnt = 15 report "width 15 expected" severity failure;

        set_and_measure(2, cnt);
        assert cnt = TB_MIN report "lower clamp failed" severity failure;

        set_and_measure(95, cnt);
        assert cnt = TB_MAX report "upper clamp failed" severity failure;

        set_and_measure(TB_MIN, cnt);
        assert cnt = TB_MIN report "min limit exact value failed" severity failure;

        set_and_measure(TB_MAX, cnt);
        assert cnt = TB_MAX report "max limit exact value failed" severity failure;

        -- 5. a change in the middle of a frame must not affect that frame
        set_and_measure(20, cnt);
        wait until rising_edge(frame_tick);
        cnt := 0;
        for i in 1 to TB_FRAME_CYC loop
            wait until rising_edge(clk);
            if pwm = '1' then
                cnt := cnt + 1;
            end if;
            if i = 5 then
                pulse_cycles <= to_unsigned(28, 20);
            end if;
        end loop;
        assert cnt = 20 report "width must be latched at frame start" severity failure;
        measure_frame(cnt);
        assert cnt = 28 report "new width should apply in the next frame" severity failure;

        -- 6. enable low forces pwm low straight away
        enable <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        assert pwm = '0' report "pwm must drop when enable falls" severity failure;

        report "tb_servo_pwm: PASS" severity note;
        done <= true;
        wait;
    end process;
end architecture sim;
