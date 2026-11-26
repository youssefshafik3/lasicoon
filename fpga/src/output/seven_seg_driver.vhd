-- ============================================================================
-- File        : seven_seg_driver.vhd
-- Owner       : Person E
-- Purpose     : Binary-to-BCD (0-999) and active-low 7-segment display driver
--               for DE10-Lite HEX5..HEX0 ([Time | Score/High | Mode]).
-- Assumptions : Active-low segments (bit 7 = DP = '1' off), VHDL-93 compliant.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity seven_seg_driver is
    port (
        clk        : in  std_logic;
        rst_n      : in  std_logic;
        tick_1ms   : in  std_logic;
        state      : in  game_state_t;
        mode       : in  std_logic; -- '0' = Mode 1, '1' = Mode 2
        time_left  : in  unsigned(6 downto 0); -- 0..99 seconds
        score      : in  unsigned(9 downto 0); -- 0..999
        high_score : in  unsigned(9 downto 0); -- 0..999
        show_high  : in  std_logic;            -- SW2: '1' shows high_score
        hex0       : out std_logic_vector(7 downto 0);
        hex1       : out std_logic_vector(7 downto 0);
        hex2       : out std_logic_vector(7 downto 0);
        hex3       : out std_logic_vector(7 downto 0);
        hex4       : out std_logic_vector(7 downto 0);
        hex5       : out std_logic_vector(7 downto 0)
    );
end entity seven_seg_driver;

architecture rtl of seven_seg_driver is
    constant SEG_BLANK : std_logic_vector(7 downto 0) := x"FF";

    type bcd3_t is record
        hundreds : unsigned(3 downto 0);
        tens     : unsigned(3 downto 0);
        ones     : unsigned(3 downto 0);
    end record;

    type bcd2_t is record
        tens : unsigned(3 downto 0);
        ones : unsigned(3 downto 0);
    end record;

    -- Active-low 7-seg lookup (DP = bit 7 = '1')
    function decode_hex(d : unsigned(3 downto 0)) return std_logic_vector is
    begin
        case d is
            when "0000" => return "11000000"; -- 0
            when "0001" => return "11111001"; -- 1
            when "0010" => return "10100100"; -- 2
            when "0011" => return "10110000"; -- 3
            when "0100" => return "10011001"; -- 4
            when "0101" => return "10010010"; -- 5
            when "0110" => return "10000010"; -- 6
            when "0111" => return "11111000"; -- 7
            when "1000" => return "10000000"; -- 8
            when "1001" => return "10010000"; -- 9
            when others => return SEG_BLANK;
        end case;
    end function;

    -- Double-dabble binary-to-BCD for 0..999 (10-bit unsigned)
    function to_bcd3(val : unsigned(9 downto 0)) return bcd3_t is
        variable shift_reg : unsigned(21 downto 0);
        variable res       : bcd3_t;
    begin
        shift_reg := (others => '0');
        shift_reg(9 downto 0) := val;
        for i in 0 to 9 loop
            if shift_reg(13 downto 10) >= 5 then
                shift_reg(13 downto 10) := shift_reg(13 downto 10) + 3;
            end if;
            if shift_reg(17 downto 14) >= 5 then
                shift_reg(17 downto 14) := shift_reg(17 downto 14) + 3;
            end if;
            if shift_reg(21 downto 18) >= 5 then
                shift_reg(21 downto 18) := shift_reg(21 downto 18) + 3;
            end if;
            shift_reg := shift_reg(20 downto 0) & '0';
        end loop;
        res.ones     := shift_reg(13 downto 10);
        res.tens     := shift_reg(17 downto 14);
        res.hundreds := shift_reg(21 downto 18);
        return res;
    end function;

    -- Double-dabble binary-to-BCD for 0..99 (7-bit unsigned)
    function to_bcd2(val : unsigned(6 downto 0)) return bcd2_t is
        variable shift_reg : unsigned(14 downto 0);
        variable res       : bcd2_t;
    begin
        shift_reg := (others => '0');
        shift_reg(6 downto 0) := val;
        for i in 0 to 6 loop
            if shift_reg(10 downto 7) >= 5 then
                shift_reg(10 downto 7) := shift_reg(10 downto 7) + 3;
            end if;
            if shift_reg(14 downto 11) >= 5 then
                shift_reg(14 downto 11) := shift_reg(14 downto 11) + 3;
            end if;
            shift_reg := shift_reg(13 downto 0) & '0';
        end loop;
        res.ones := shift_reg(10 downto 7);
        res.tens := shift_reg(14 downto 11);
        return res;
    end function;

    signal blink_cnt   : integer range 0 to 499 := 0;
    signal blink_on    : std_logic := '1';
begin

    -- 500 ms blink toggle for S_GAME_OVER score display
    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' or state /= S_GAME_OVER then
                blink_cnt <= 0;
                blink_on  <= '1';
            elsif tick_1ms = '1' then
                if blink_cnt = 499 then
                    blink_cnt <= 0;
                    blink_on  <= not blink_on;
                else
                    blink_cnt <= blink_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- Combinational display mux (all outputs assigned defaults first to avoid latches)
    process(state, mode, time_left, score, high_score, show_high, blink_on)
        variable disp_val  : unsigned(9 downto 0);
        variable score_bcd : bcd3_t;
        variable time_bcd  : bcd2_t;
    begin
        hex0 <= SEG_BLANK;
        hex1 <= SEG_BLANK;
        hex2 <= SEG_BLANK;
        hex3 <= SEG_BLANK;
        hex4 <= SEG_BLANK;
        hex5 <= SEG_BLANK;

        if state /= S_OFF then
            -- HEX0: Mode indicator ('1' for mode='0', '2' for mode='1')
            if mode = '0' then
                hex0 <= decode_hex("0001");
            else
                hex0 <= decode_hex("0010");
            end if;

            -- HEX3..HEX1: Score or High Score (SW2), blinking in S_GAME_OVER
            if show_high = '1' then
                disp_val := high_score;
            else
                disp_val := score;
            end if;

            score_bcd := to_bcd3(disp_val);
            if state /= S_GAME_OVER or blink_on = '1' then
                hex1 <= decode_hex(score_bcd.ones);
                hex2 <= decode_hex(score_bcd.tens);
                hex3 <= decode_hex(score_bcd.hundreds);
            end if;

            -- HEX5..HEX4: Time left in Mode 1; blank in Mode 2
            if mode = '0' then
                time_bcd := to_bcd2(time_left);
                hex4 <= decode_hex(time_bcd.ones);
                hex5 <= decode_hex(time_bcd.tens);
            end if;
        end if;
    end process;

end architecture rtl;