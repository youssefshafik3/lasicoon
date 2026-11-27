-- ============================================================================
-- tb_target_servo_ctrl.vhd  (Person D)
-- Checks: starts down, rises when active and only then raises up_ok,
--         up_ok drops as soon as active drops, returns down, an aborted rise
--         never raises up_ok, enable = 0 switches the PWM off.
-- Scaled generics: frame 40 clocks, limits 5..35, down 10, up 30, step 5.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_target_servo_ctrl is
end entity tb_target_servo_ctrl;

architecture sim of tb_target_servo_ctrl is
    constant CLK_PERIOD   : time    := 20 ns;
    constant TB_FRAME_CYC : natural := 40;
    constant TB_UP        : natural := 30;
    constant TB_DOWN      : natural := 10;
    constant TB_STEP      : natural := 5;
    constant TB_MIN       : natural := 5;
    constant TB_MAX       : natural := 35;

    signal clk     : std_logic := '0';
    signal rst_n   : std_logic := '0';
    signal enable  : std_logic := '1';
    signal active  : std_logic := '0';
    signal tgt_pwm : std_logic;
    signal up_ok   : std_logic;
    signal done    : boolean := false;
begin
    clk_proc : process
    begin
        while not done loop
            clk <= '0'; wait for CLK_PERIOD / 2;
            clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    dut : entity work.target_servo_ctrl
        generic map (
            ANGLE_UP     => TB_UP,
            ANGLE_DOWN   => TB_DOWN,
            STEP         => TB_STEP,
            MIN_PULSE    => TB_MIN,
            MAX_PULSE    => TB_MAX,
            FRAME_CYCLES => TB_FRAME_CYC
        )
        port map (
            clk       => clk,
            rst_n     => rst_n,
            enable    => enable,
            active    => active,
            servo_pwm => tgt_pwm,
            up_ok     => up_ok
        );

    stim : process
        variable t0 : time;
        variable w  : natural;

        procedure wait_frames(constant n : in natural) is
        begin
            for f in 1 to n loop
                for c in 1 to TB_FRAME_CYC loop
                    wait until rising_edge(clk);
                end loop;
            end loop;
        end procedure;

        procedure measure_width(variable w : out natural) is
        begin
            w := 0;
            for c in 1 to TB_FRAME_CYC loop
                wait until rising_edge(clk);
                if tgt_pwm = '1' then
                    w := w + 1;
                end if;
            end loop;
        end procedure;
    begin
        rst_n <= '0'; active <= '0'; enable <= '1';
        wait for 3 * CLK_PERIOD;
        rst_n <= '1';

        -- 1. starts down
        assert up_ok = '0' report "up_ok must be low after reset" severity failure;
        wait_frames(3);
        measure_width(w);
        assert w = TB_DOWN report "target should start at ANGLE_DOWN" severity failure;

        -- 2. rise: 4 steps are needed (10 -> 30), so 3 to 5 frames
        active <= '1';
        t0 := now;
        wait until up_ok = '1' for 8 * TB_FRAME_CYC * CLK_PERIOD;
        assert up_ok = '1' report "up_ok never rose" severity failure;
        assert (now - t0) >= 3 * TB_FRAME_CYC * CLK_PERIOD
            report "up_ok rose before ANGLE_UP was reached" severity failure;
        assert (now - t0) <= 5 * TB_FRAME_CYC * CLK_PERIOD
            report "up_ok rose too late" severity failure;

        wait_frames(3);
        assert up_ok = '1' report "up_ok must stay high while active" severity failure;
        measure_width(w);
        assert w = TB_UP report "target should be at ANGLE_UP" severity failure;

        -- 3. up_ok drops immediately when active drops
        active <= '0';
        wait until rising_edge(clk);
        assert up_ok = '0' report "up_ok must drop when active drops" severity failure;

        -- 4. goes back down
        wait_frames(8);
        assert up_ok = '0' report "up_ok must stay low while going down" severity failure;
        measure_width(w);
        assert w = TB_DOWN report "target should return to ANGLE_DOWN" severity failure;

        -- 5. aborted rise: never reaches up, up_ok never rises
        active <= '1';
        wait_frames(2);
        assert up_ok = '0' report "up_ok must be low before ANGLE_UP" severity failure;
        active <= '0';
        wait_frames(1);
        assert up_ok = '0' report "up_ok must be low after an aborted rise" severity failure;
        wait_frames(6);
        measure_width(w);
        assert w = TB_DOWN report "target should return down after abort" severity failure;

        -- 6. enable = 0 switches the PWM off
        enable <= '0';
        wait_frames(2);
        measure_width(w);
        assert w = 0 report "PWM must be off while enable = 0" severity failure;
        enable <= '1';

        report "tb_target_servo_ctrl: PASS" severity note;
        done <= true;
        wait;
    end process;
end architecture sim;
