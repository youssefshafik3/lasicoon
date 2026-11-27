-- ============================================================================
-- File:    servo_pwm.vhd
-- Owner:   Person D
-- Purpose: Generic servo PWM. Frame = FRAME_CYCLES clocks (20 ms by default).
--          The requested pulse width is clamped to MIN_PULSE..MAX_PULSE and
--          latched once per frame, so it never changes in the middle of a
--          pulse. frame_tick is high for one clock at the start of each frame.
--          enable = '0' forces pwm low (the frame counter keeps running).
-- Ports:   clk, rst_n (sync, active low), enable, pulse_cycles (20 bit)
--          -> pwm, frame_tick
-- Timing:  pwm is registered: it is high during clocks 1..pulse of a frame,
--          clock 0 being the one in which frame_tick is high.
-- Assumes: MIN_PULSE <= MAX_PULSE <= FRAME_CYCLES.
-- Standard: VHDL-93
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity servo_pwm is
    generic (
        FRAME_CYCLES : natural := SERVO_FRAME_CYCLES;
        MIN_PULSE    : natural := PULSE_MIN_CYCLES;
        MAX_PULSE    : natural := PULSE_MAX_CYCLES
    );
    port (
        clk          : in  std_logic;
        rst_n        : in  std_logic;
        enable       : in  std_logic;
        pulse_cycles : in  unsigned(19 downto 0);
        pwm          : out std_logic;
        frame_tick   : out std_logic
    );
end entity servo_pwm;

architecture rtl of servo_pwm is
    signal frame_cnt     : natural range 0 to FRAME_CYCLES - 1 := 0;
    signal latched_pulse : natural range 0 to FRAME_CYCLES := MIN_PULSE;
    signal pwm_reg       : std_logic := '0';
    signal tick_reg      : std_logic := '0';

    function clamp_pulse(val : natural; lo : natural; hi : natural) return natural is
    begin
        if val < lo then
            return lo;
        elsif val > hi then
            return hi;
        else
            return val;
        end if;
    end function;
begin
    assert (MIN_PULSE <= MAX_PULSE) and (MAX_PULSE <= FRAME_CYCLES)
        report "servo_pwm: generics must satisfy MIN_PULSE <= MAX_PULSE <= FRAME_CYCLES"
        severity failure;

    pwm        <= pwm_reg;
    frame_tick <= tick_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            tick_reg <= '0';

            if rst_n = '0' then
                frame_cnt     <= 0;
                -- start with the requested width, not the minimum, so the
                -- servo does not twitch during the first frame after reset
                latched_pulse <= clamp_pulse(to_integer(pulse_cycles), MIN_PULSE, MAX_PULSE);
                pwm_reg       <= '0';
            else
                if enable = '0' then
                    pwm_reg <= '0';
                elsif frame_cnt < latched_pulse then
                    pwm_reg <= '1';
                else
                    pwm_reg <= '0';
                end if;

                if frame_cnt = FRAME_CYCLES - 1 then
                    frame_cnt     <= 0;
                    tick_reg      <= '1';
                    latched_pulse <= clamp_pulse(to_integer(pulse_cycles), MIN_PULSE, MAX_PULSE);
                else
                    frame_cnt <= frame_cnt + 1;
                end if;
            end if;
        end if;
    end process;
end architecture rtl;
