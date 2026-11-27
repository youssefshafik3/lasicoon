-- ============================================================================
-- File:    target_servo_ctrl.vhd
-- Owner:   Person D (one instance per target)
-- Purpose: Moves one target servo toward ANGLE_UP while active = '1' and
--          toward ANGLE_DOWN otherwise, by STEP clocks of pulse width per
--          servo frame. up_ok is high only while active = '1' AND the pulse
--          width equals ANGLE_UP, so it drops at once when active drops
--          (the target is no longer "armed" for hit_detector).
-- Ports:   clk, rst_n, active
--          enable    : optional, defaults to '1' when left unconnected. Keep
--                      it '1' so targets can still go down in OFF/GAME_OVER.
--                      NOTE: not in the original plan; tell E.
--          servo_pwm, up_ok
-- Generics: MIN_PULSE/MAX_PULSE are passed to servo_pwm (override in tests).
-- Standard: VHDL-93
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity target_servo_ctrl is
    generic (
        ANGLE_UP     : natural := 85_000;
        ANGLE_DOWN   : natural := 60_000;
        STEP         : natural := 1_000;
        MIN_PULSE    : natural := PULSE_MIN_CYCLES;
        MAX_PULSE    : natural := PULSE_MAX_CYCLES;
        FRAME_CYCLES : natural := SERVO_FRAME_CYCLES
    );
    port (
        clk       : in  std_logic;
        rst_n     : in  std_logic;
        enable    : in  std_logic := '1';
        active    : in  std_logic;
        servo_pwm : out std_logic;
        up_ok     : out std_logic
    );
end entity target_servo_ctrl;

architecture rtl of target_servo_ctrl is
    signal pos_reg : natural range 0 to 1_048_575 := ANGLE_DOWN;
    signal pulse_u : unsigned(19 downto 0);
    signal f_tick  : std_logic;
begin
    pulse_u <= to_unsigned(pos_reg, 20);
    up_ok   <= '1' when (active = '1') and (pos_reg = ANGLE_UP) else '0';

    pwm_inst : entity work.servo_pwm
        generic map (
            FRAME_CYCLES => FRAME_CYCLES,
            MIN_PULSE    => MIN_PULSE,
            MAX_PULSE    => MAX_PULSE
        )
        port map (
            clk          => clk,
            rst_n        => rst_n,
            enable       => enable,
            pulse_cycles => pulse_u,
            pwm          => servo_pwm,
            frame_tick   => f_tick
        );

    process(clk)
        variable target_pos : natural;
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                pos_reg <= ANGLE_DOWN;
            elsif f_tick = '1' then
                if active = '1' then
                    target_pos := ANGLE_UP;
                else
                    target_pos := ANGLE_DOWN;
                end if;

                if pos_reg < target_pos then
                    if (target_pos - pos_reg) <= STEP then
                        pos_reg <= target_pos;
                    else
                        pos_reg <= pos_reg + STEP;
                    end if;
                elsif pos_reg > target_pos then
                    if (pos_reg - target_pos) <= STEP then
                        pos_reg <= target_pos;
                    else
                        pos_reg <= pos_reg - STEP;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture rtl;
