-- ============================================================================
-- tb_turret_ctrl.vhd  (Person D)
-- Checks: reset centre, single steps on each axis (axes independent),
--         opposite directions cancel, clamps, enable = 0 freezes position and
--         switches PWM off, is_ready recentres (and beats the joystick).
-- Scaled generics: frame 40 clocks, limits 10..30, centre 20, step 5.
-- A direction held for exactly one frame (40 clocks) gives exactly one step.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_turret_ctrl is
end entity tb_turret_ctrl;

architecture sim of tb_turret_ctrl is
    constant CLK_PERIOD   : time    := 20 ns;
    constant TB_FRAME_CYC : natural := 40;
    constant TB_MIN       : natural := 10;
    constant TB_MAX       : natural := 30;
    constant TB_CENTER    : natural := 20;
    constant TB_STEP      : natural := 5;

    signal clk      : std_logic := '0';
    signal rst_n    : std_logic := '0';
    signal enable   : std_logic := '0';
    signal is_ready : std_logic := '0';
    signal left     : std_logic := '0';
    signal right    : std_logic := '0';
    signal up       : std_logic := '0';
    signal down     : std_logic := '0';
    signal pan_pwm  : std_logic;
    signal tilt_pwm : std_logic;
    signal done     : boolean := false;
begin
    clk_proc : process
    begin
        while not done loop
            clk <= '0'; wait for CLK_PERIOD / 2;
            clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    dut : entity work.turret_ctrl
        generic map (
            STEP         => TB_STEP,
            MIN_PULSE    => TB_MIN,
            MAX_PULSE    => TB_MAX,
            CENTER_PULSE => TB_CENTER,
            FRAME_CYCLES => TB_FRAME_CYC
        )
        port map (
            clk      => clk,
            rst_n    => rst_n,
            enable   => enable,
            is_ready => is_ready,
            left     => left,
            right    => right,
            up       => up,
            down     => down,
            pan_pwm  => pan_pwm,
            tilt_pwm => tilt_pwm
        );

    stim : process
        variable p : natural;
        variable t : natural;

        procedure wait_frames(constant n : in natural) is
        begin
            for f in 1 to n loop
                for c in 1 to TB_FRAME_CYC loop
                    wait until rising_edge(clk);
                end loop;
            end loop;
        end procedure;

        -- Count pwm-high clocks over one frame-long window (any alignment
        -- gives the pulse width when the width is stable).
        procedure measure(variable pan_h : out natural; variable tilt_h : out natural) is
        begin
            pan_h := 0; tilt_h := 0;
            for c in 1 to TB_FRAME_CYC loop
                wait until rising_edge(clk);
                if pan_pwm = '1' then
                    pan_h := pan_h + 1;
                end if;
                if tilt_pwm = '1' then
                    tilt_h := tilt_h + 1;
                end if;
            end loop;
        end procedure;
    begin
        rst_n <= '0';
        wait for 3 * CLK_PERIOD;
        rst_n  <= '1';
        enable <= '1';

        -- 1. centred after reset
        wait_frames(3);
        measure(p, t);
        assert p = TB_CENTER and t = TB_CENTER
            report "turret should be centred after reset" severity failure;

        -- 2. single steps, axes independent
        right <= '1'; wait_frames(1); right <= '0';
        wait_frames(3); measure(p, t);
        assert p = TB_CENTER + TB_STEP and t = TB_CENTER
            report "right: one pan step up, tilt unchanged" severity failure;

        up <= '1'; wait_frames(1); up <= '0';
        wait_frames(3); measure(p, t);
        assert p = TB_CENTER + TB_STEP and t = TB_CENTER + TB_STEP
            report "up: one tilt step up, pan unchanged" severity failure;

        left <= '1'; wait_frames(1); left <= '0';
        wait_frames(3); measure(p, t);
        assert p = TB_CENTER and t = TB_CENTER + TB_STEP
            report "left: one pan step down" severity failure;

        down <= '1'; wait_frames(1); down <= '0';
        wait_frames(3); measure(p, t);
        assert p = TB_CENTER and t = TB_CENTER
            report "down: one tilt step down" severity failure;

        -- 3. opposite directions cancel
        left <= '1'; right <= '1'; up <= '1'; down <= '1';
        wait_frames(2);
        left <= '0'; right <= '0'; up <= '0'; down <= '0';
        wait_frames(3); measure(p, t);
        assert p = TB_CENTER and t = TB_CENTER
            report "left+right and up+down should cancel" severity failure;

        -- 4. upper clamp
        right <= '1'; up <= '1';
        wait_frames(10);
        right <= '0'; up <= '0';
        wait_frames(3); measure(p, t);
        assert p = TB_MAX and t = TB_MAX
            report "upper clamp failed" severity failure;

        -- 5. lower clamp
        left <= '1'; down <= '1';
        wait_frames(10);
        left <= '0'; down <= '0';
        wait_frames(3); measure(p, t);
        assert p = TB_MIN and t = TB_MIN
            report "lower clamp failed" severity failure;

        -- 6. enable = 0: PWM off and position frozen
        enable <= '0';
        wait_frames(2);
        measure(p, t);
        assert p = 0 and t = 0
            report "PWM must be off while enable = 0" severity failure;

        right <= '1'; up <= '1';
        wait_frames(5);
        right <= '0'; up <= '0';
        enable <= '1';
        wait_frames(3); measure(p, t);
        assert p = TB_MIN and t = TB_MIN
            report "joystick must be ignored while enable = 0" severity failure;

        -- 7. is_ready recentres and wins over the joystick
        right <= '1';
        is_ready <= '1';
        wait_frames(3);
        right <= '0';
        measure(p, t);
        assert p = TB_CENTER and t = TB_CENTER
            report "is_ready must recentre the turret" severity failure;
        is_ready <= '0';

        report "tb_turret_ctrl: PASS" severity note;
        done <= true;
        wait;
    end process;
end architecture sim;
