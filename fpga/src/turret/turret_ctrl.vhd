-- ============================================================================
-- File:    turret_ctrl.vhd
-- Owner:   Person D
-- Purpose: Pan/tilt turret. On every servo frame the pulse widths are nudged
--          by STEP according to left/right/up/down and clamped to
--          MIN_PULSE..MAX_PULSE. In READY the turret goes back to centre.
-- Ports:   clk, rst_n
--          enable   : state is READY or PLAYING. When '0' the PWM is off AND
--                     the position is frozen (joystick input is ignored).
--          is_ready : '1' while state = S_READY (recentre). NOTE: this port is
--                     not in the original plan; add it to docs/interfaces.md
--                     and tell E to wire it as (state = S_READY).
--          left, right, up, down : joystick levels
--          pan_pwm, tilt_pwm
-- Assumes: MIN_PULSE <= CENTER_PULSE <= MAX_PULSE.
--          Joystick direction signs are fixed here: right/up increase the
--          pulse; swap them if the real servos move the wrong way.
-- Standard: VHDL-93
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity turret_ctrl is
    generic (
        STEP         : natural := 500;
        MIN_PULSE    : natural := PULSE_MIN_CYCLES;
        MAX_PULSE    : natural := PULSE_MAX_CYCLES;
        CENTER_PULSE : natural := PULSE_CENTER_CYCLES;
        FRAME_CYCLES : natural := SERVO_FRAME_CYCLES
    );
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;
        enable   : in  std_logic;
        is_ready : in  std_logic;
        left     : in  std_logic;
        right    : in  std_logic;
        up       : in  std_logic;
        down     : in  std_logic;
        pan_pwm  : out std_logic;
        tilt_pwm : out std_logic
    );
end entity turret_ctrl;

architecture rtl of turret_ctrl is
    signal pan_pos      : natural range MIN_PULSE to MAX_PULSE := CENTER_PULSE;
    signal tilt_pos     : natural range MIN_PULSE to MAX_PULSE := CENTER_PULSE;
    signal pan_pulse_u  : unsigned(19 downto 0);
    signal tilt_pulse_u : unsigned(19 downto 0);
    signal frame_tick   : std_logic;
begin
    assert (MIN_PULSE <= CENTER_PULSE) and (CENTER_PULSE <= MAX_PULSE)
        report "turret_ctrl: CENTER_PULSE must lie between MIN_PULSE and MAX_PULSE"
        severity failure;

    pan_pulse_u  <= to_unsigned(pan_pos, 20);
    tilt_pulse_u <= to_unsigned(tilt_pos, 20);

    pan_servo : entity work.servo_pwm
        generic map (
            FRAME_CYCLES => FRAME_CYCLES,
            MIN_PULSE    => MIN_PULSE,
            MAX_PULSE    => MAX_PULSE
        )
        port map (
            clk          => clk,
            rst_n        => rst_n,
            enable       => enable,
            pulse_cycles => pan_pulse_u,
            pwm          => pan_pwm,
            frame_tick   => frame_tick
        );

    -- Both servos share the same frame timing, so the tilt frame_tick is unused.
    tilt_servo : entity work.servo_pwm
        generic map (
            FRAME_CYCLES => FRAME_CYCLES,
            MIN_PULSE    => MIN_PULSE,
            MAX_PULSE    => MAX_PULSE
        )
        port map (
            clk          => clk,
            rst_n        => rst_n,
            enable       => enable,
            pulse_cycles => tilt_pulse_u,
            pwm          => tilt_pwm,
            frame_tick   => open
        );

    process(clk)
        variable next_pan  : integer;
        variable next_tilt : integer;
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                pan_pos  <= CENTER_PULSE;
                tilt_pos <= CENTER_PULSE;
            elsif frame_tick = '1' then
                if is_ready = '1' then
                    pan_pos  <= CENTER_PULSE;
                    tilt_pos <= CENTER_PULSE;
                elsif enable = '1' then
                    next_pan  := pan_pos;
                    next_tilt := tilt_pos;

                    if left = '1' then
                        next_pan := next_pan - STEP;
                    end if;
                    if right = '1' then
                        next_pan := next_pan + STEP;
                    end if;
                    if up = '1' then
                        next_tilt := next_tilt + STEP;
                    end if;
                    if down = '1' then
                        next_tilt := next_tilt - STEP;
                    end if;

                    if next_pan < MIN_PULSE then
                        next_pan := MIN_PULSE;
                    elsif next_pan > MAX_PULSE then
                        next_pan := MAX_PULSE;
                    end if;

                    if next_tilt < MIN_PULSE then
                        next_tilt := MIN_PULSE;
                    elsif next_tilt > MAX_PULSE then
                        next_tilt := MAX_PULSE;
                    end if;

                    pan_pos  <= next_pan;
                    tilt_pos <= next_tilt;
                end if;
            end if;
        end if;
    end process;
end architecture rtl;
