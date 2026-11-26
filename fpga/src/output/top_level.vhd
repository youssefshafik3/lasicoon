-- ============================================================================
-- File        : top_level.vhd
-- Owner       : Person E
-- Purpose     : Structural top-level wiring all game modules to DE10-Lite pins.
-- Assumptions : Pure structural wiring + power-on reset; no game logic.
--               VHDL-93 compliant.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity top_level is
    port (
        MAX10_CLK1_50 : in    std_logic;
        KEY           : in    std_logic_vector(1 downto 0);
        SW            : in    std_logic_vector(9 downto 0);
        LEDR          : out   std_logic_vector(9 downto 0);
        HEX0          : out   std_logic_vector(7 downto 0);
        HEX1          : out   std_logic_vector(7 downto 0);
        HEX2          : out   std_logic_vector(7 downto 0);
        HEX3          : out   std_logic_vector(7 downto 0);
        HEX4          : out   std_logic_vector(7 downto 0);
        HEX5          : out   std_logic_vector(7 downto 0);
        GPIO          : inout std_logic_vector(35 downto 0)
    );
end entity top_level;

architecture structural of top_level is
    -- Power-on reset shift register (active-low rst_n)
    signal por_cnt : unsigned(3 downto 0) := (others => '0');
    signal rst_n   : std_logic := '0';

    -- Common timing & RNG
    signal tick_1ms : std_logic;
    signal tick_1s  : std_logic;
    signal rnd      : std_logic_vector(15 downto 0);

    -- Synchronized / debounced inputs
    signal start_p       : std_logic;
    signal reset_score_p : std_logic;
    signal fire_p        : std_logic;
    signal rx_sync       : std_logic_vector(N_TARGETS - 1 downto 0);

    -- Arduino UART & sensor signals
    signal uart_data     : std_logic_vector(7 downto 0);
    signal uart_valid    : std_logic;
    signal uart_err      : std_logic;
    signal joy_x         : unsigned(7 downto 0);
    signal joy_y         : unsigned(7 downto 0);
    signal ldr_val       : unsigned(7 downto 0);
    signal frame_ok_p    : std_logic;
    signal link_lost     : std_logic;
    signal joy_left      : std_logic;
    signal joy_right     : std_logic;
    signal joy_up        : std_logic;
    signal joy_down      : std_logic;
    signal night         : std_logic;
    signal base_ready    : std_logic;

    -- Shooter & hit detection
    signal ir_out           : std_logic;
    signal laser_sight      : std_logic;
    signal window_open      : std_logic;
    signal window_expired_p : std_logic;
    signal shot_hard        : std_logic;
    signal shooter_busy     : std_logic;
    signal hit_p            : std_logic;
    signal hit_idx          : unsigned(2 downto 0);
    signal miss_p           : std_logic;

    -- Turret & targets
    signal pan_pwm     : std_logic;
    signal tilt_pwm    : std_logic;
    signal active      : std_logic_vector(N_TARGETS - 1 downto 0);
    signal up_ok       : std_logic_vector(N_TARGETS - 1 downto 0);
    signal armed       : std_logic_vector(N_TARGETS - 1 downto 0);
    signal target_pwm  : std_logic_vector(N_TARGETS - 1 downto 0);
    signal timeout_p   : std_logic;

    -- Game FSM, streak & scoring
    signal state         : game_state_t;
    signal mode          : std_logic;
    signal time_left     : unsigned(6 downto 0);
    signal lives         : unsigned(1 downto 0);
    signal new_round_p   : std_logic;
    signal game_over_p   : std_logic;
    signal clear_score_p : std_logic;
    signal streak_p      : std_logic;
    signal score         : unsigned(9 downto 0);
    signal high_score    : unsigned(9 downto 0);
    signal buzzer_sig    : std_logic;

    -- Derived state flags
    signal is_ready      : std_logic;
    signal is_playing    : std_logic;
    signal turret_en     : std_logic;

    -- GPIO pin indices (update to match docs/pin_assignment.md)
    constant PIN_UART_RX     : integer := 0;
    constant PIN_FIRE_BTN_N  : integer := 1;
    constant PIN_IR_OUT      : integer := 2;
    constant PIN_LASER_SIGHT : integer := 3;
    constant PIN_PAN_PWM     : integer := 4;
    constant PIN_TILT_PWM    : integer := 5;
    constant PIN_BUZZER      : integer := 6;
    -- Target receivers on GPIO(10..14), Target servos on GPIO(15..19)
begin

    -- Power-on reset generation
    process(MAX10_CLK1_50)
    begin
        if rising_edge(MAX10_CLK1_50) then
            if por_cnt /= "1111" then
                por_cnt <= por_cnt + 1;
                rst_n   <= '0';
            else
                rst_n   <= '1';
            end if;
        end if;
    end process;

    is_ready   <= '1' when state = S_READY else '0';
    is_playing <= '1' when state = S_PLAYING else '0';
    turret_en  <= '1' when (state = S_READY or state = S_PLAYING) else '0';
    armed      <= up_ok;

    -- Common clock ticks & RNG
    u_tick_gen : entity work.tick_gen
        generic map (CLK_FREQ => CLK_FREQ)
        port map (
            clk      => MAX10_CLK1_50,
            rst_n    => rst_n,
            tick_1ms => tick_1ms,
            tick_1s  => tick_1s
        );

    u_lfsr : entity work.lfsr_rng
        port map (
            clk       => MAX10_CLK1_50,
            rst_n     => rst_n,
            seed_load => start_p,
            rnd       => rnd
        );

    -- Buttons & receiver synchronizers
    u_sync_start : entity work.input_sync_debounce
        generic map (DEBOUNCE_MS => 10, ACTIVE_LOW => true)
        port map (
            clk       => MAX10_CLK1_50,
            rst_n     => rst_n,
            tick_1ms  => tick_1ms,
            raw_in    => KEY(0),
            level_out => open,
            press_p   => start_p
        );

    u_sync_reset_score : entity work.input_sync_debounce
        generic map (DEBOUNCE_MS => 10, ACTIVE_LOW => true)
        port map (
            clk       => MAX10_CLK1_50,
            rst_n     => rst_n,
            tick_1ms  => tick_1ms,
            raw_in    => KEY(1),
            level_out => open,
            press_p   => reset_score_p
        );

    u_sync_fire : entity work.input_sync_debounce
        generic map (DEBOUNCE_MS => 10, ACTIVE_LOW => true)
        port map (
            clk       => MAX10_CLK1_50,
            rst_n     => rst_n,
            tick_1ms  => tick_1ms,
            raw_in    => GPIO(PIN_FIRE_BTN_N),
            level_out => open,
            press_p   => fire_p
        );

    gen_rx_sync : for i in 0 to N_TARGETS - 1 generate
        u_sync_rx : entity work.input_sync_debounce
            generic map (DEBOUNCE_MS => 0, ACTIVE_LOW => false)
            port map (
                clk       => MAX10_CLK1_50,
                rst_n     => rst_n,
                tick_1ms  => tick_1ms,
                raw_in    => GPIO(10 + i),
                level_out => rx_sync(i),
                press_p   => open
            );
    end generate;

    -- Arduino UART link, joystick decoder & night mode
    u_uart_rx : entity work.uart_rx
        generic map (CLK_FREQ => CLK_FREQ, BAUD => 9600)
        port map (
            clk           => MAX10_CLK1_50,
            rst_n         => rst_n,
            rx            => GPIO(PIN_UART_RX),
            data          => uart_data,
            data_valid    => uart_valid,
            framing_error => uart_err
        );

    u_frame_parser : entity work.sensor_frame_parser
        port map (
            clk        => MAX10_CLK1_50,
            rst_n      => rst_n,
            tick_1ms   => tick_1ms,
            data       => uart_data,
            data_valid => uart_valid,
            x          => joy_x,
            y          => joy_y,
            ldr        => ldr_val,
            frame_ok_p => frame_ok_p,
            link_lost  => link_lost
        );

    u_joy_dec : entity work.joystick_decoder
        port map (
            x         => joy_x,
            y         => joy_y,
            link_lost => link_lost,
            left      => joy_left,
            right     => joy_right,
            up        => joy_up,
            down      => joy_down
        );

    u_night_mode : entity work.night_mode
        port map (
            clk            => MAX10_CLK1_50,
            rst_n          => rst_n,
            tick_1ms       => tick_1ms,
            calibrate      => is_ready,
            ldr            => ldr_val,
            frame_ok_p     => frame_ok_p,
            link_lost      => link_lost,
            night          => night,
            baseline_ready => base_ready
        );

    -- IR shooter & hit detector
    u_ir_tx : entity work.ir_burst_tx
        port map (
            clk              => MAX10_CLK1_50,
            rst_n            => rst_n,
            playing          => is_playing,
            night            => night,
            fire_p           => fire_p,
            hit_seen         => hit_p,
            ir_out           => ir_out,
            laser_sight      => laser_sight,
            window_open      => window_open,
            window_expired_p => window_expired_p,
            shot_hard        => shot_hard,
            busy             => shooter_busy
        );

    u_hit_det : entity work.hit_detector
        port map (
            clk              => MAX10_CLK1_50,
            rst_n            => rst_n,
            rx_sync          => rx_sync,
            armed            => armed,
            window_open      => window_open,
            window_expired_p => window_expired_p,
            hit_p            => hit_p,
            hit_idx          => hit_idx,
            miss_p           => miss_p
        );

    -- Turret & 5 rotating targets
    u_turret : entity work.turret_ctrl
        port map (
            clk      => MAX10_CLK1_50,
            rst_n    => rst_n,
            enable   => turret_en,
            left     => joy_left,
            right    => joy_right,
            up       => joy_up,
            down     => joy_down,
            pan_pwm  => pan_pwm,
            tilt_pwm => tilt_pwm
        );

    u_target_sched : entity work.target_scheduler
        port map (
            clk       => MAX10_CLK1_50,
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

    gen_target_servos : for i in 0 to N_TARGETS - 1 generate
        u_target_srv : entity work.target_servo_ctrl
            port map (
                clk       => MAX10_CLK1_50,
                rst_n     => rst_n,
                active    => active(i),
                servo_pwm => target_pwm(i),
                up_ok     => up_ok(i)
            );
    end generate;

    -- Core game FSM, streak tracker & scoring
    u_game_fsm : entity work.game_fsm
        port map (
            clk           => MAX10_CLK1_50,
            rst_n         => rst_n,
            sw_on         => SW(0),
            sw_mode       => SW(1),
            start_p       => start_p,
            reset_score_p => reset_score_p,
            tick_1s       => tick_1s,
            timeout_p     => timeout_p,
            state         => state,
            mode          => mode,
            time_left     => time_left,
            lives         => lives,
            new_round_p   => new_round_p,
            game_over_p   => game_over_p,
            clear_score_p => clear_score_p
        );

    u_streak : entity work.streak_tracker
        port map (
            clk         => MAX10_CLK1_50,
            rst_n       => rst_n,
            mode        => mode,
            hit_p       => hit_p,
            hit_idx     => hit_idx,
            timeout_p   => timeout_p,
            new_round_p => new_round_p,
            tick_1s     => tick_1s,
            streak_p    => streak_p
        );

    u_scoring : entity work.scoring_engine
        port map (
            clk           => MAX10_CLK1_50,
            rst_n         => rst_n,
            mode          => mode,
            hit_p         => hit_p,
            shot_hard     => shot_hard,
            streak_p      => streak_p,
            new_round_p   => new_round_p,
            clear_score_p => clear_score_p,
            game_over_p   => game_over_p,
            score         => score,
            high_score    => high_score
        );

    -- Outputs: 7-seg displays, status LEDs & buzzer
    u_seven_seg : entity work.seven_seg_driver
        port map (
            clk        => MAX10_CLK1_50,
            rst_n      => rst_n,
            tick_1ms   => tick_1ms,
            state      => state,
            mode       => mode,
            time_left  => time_left,
            score      => score,
            high_score => high_score,
            show_high  => SW(2),
            hex0       => HEX0,
            hex1       => HEX1,
            hex2       => HEX2,
            hex3       => HEX3,
            hex4       => HEX4,
            hex5       => HEX5
        );

    u_status_leds : entity work.status_leds
        port map (
            clk       => MAX10_CLK1_50,
            rst_n     => rst_n,
            state     => state,
            mode      => mode,
            lives     => lives,
            night     => night,
            hit_p     => hit_p,
            miss_p    => miss_p,
            streak_p  => streak_p,
            timeout_p => timeout_p,
            ledr      => LEDR
        );

    u_audio : entity work.audio_gen
        port map (
            clk         => MAX10_CLK1_50,
            rst_n       => rst_n,
            tick_1ms    => tick_1ms,
            hit_p       => hit_p,
            miss_p      => miss_p,
            streak_p    => streak_p,
            timeout_p   => timeout_p,
            game_over_p => game_over_p,
            buzzer      => buzzer_sig
        );

    -- Drive GPIO outputs (unused GPIO lines left high-Z)
    GPIO <= (others => 'Z');
    GPIO(PIN_IR_OUT)      <= ir_out;
    GPIO(PIN_LASER_SIGHT) <= laser_sight;
    GPIO(PIN_PAN_PWM)     <= pan_pwm;
    GPIO(PIN_TILT_PWM)    <= tilt_pwm;
    GPIO(PIN_BUZZER)      <= buzzer_sig;

    gen_target_gpio : for i in 0 to N_TARGETS - 1 generate
        GPIO(15 + i) <= target_pwm(i);
    end generate;

end architecture structural;