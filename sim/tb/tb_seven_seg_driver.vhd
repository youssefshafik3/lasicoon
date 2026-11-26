-- ============================================================================
-- File        : tb_seven_seg_driver.vhd
-- Owner       : Person E
-- Purpose     : Self-checking testbench for seven_seg_driver (BCD 0-999,
--               all digit decodes, Mode 1/2 layout, SW2 high score, blink).
-- Assumptions : VHDL-93 compliant; depends on work.game_pkg.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity tb_seven_seg_driver is
end entity tb_seven_seg_driver;

architecture sim of tb_seven_seg_driver is
    constant CLK_PERIOD : time := 20 ns;
    constant SEG_BLANK  : std_logic_vector(7 downto 0) := x"FF";

    -- Expected active-low 7-segment codes for digits 0..9
    type seg_arr_t is array (0 to 9) of std_logic_vector(7 downto 0);
    constant EXP_SEG : seg_arr_t := (
        0 => "11000000",
        1 => "11111001",
        2 => "10100100",
        3 => "10110000",
        4 => "10011001",
        5 => "10010010",
        6 => "10000010",
        7 => "11111000",
        8 => "10000000",
        9 => "10010000"
    );

    signal clk        : std_logic := '0';
    signal rst_n      : std_logic := '0';
    signal tick_1ms   : std_logic := '0';
    signal state      : game_state_t := S_OFF;
    signal mode       : std_logic := '0';
    signal time_left  : unsigned(6 downto 0) := (others => '0');
    signal score      : unsigned(9 downto 0) := (others => '0');
    signal high_score : unsigned(9 downto 0) := (others => '0');
    signal show_high  : std_logic := '0';
    signal hex0       : std_logic_vector(7 downto 0);
    signal hex1       : std_logic_vector(7 downto 0);
    signal hex2       : std_logic_vector(7 downto 0);
    signal hex3       : std_logic_vector(7 downto 0);
    signal hex4       : std_logic_vector(7 downto 0);
    signal hex5       : std_logic_vector(7 downto 0);

    signal done       : boolean := false;
begin

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

    dut : entity work.seven_seg_driver
        port map (
            clk        => clk,
            rst_n      => rst_n,
            tick_1ms   => tick_1ms,
            state      => state,
            mode       => mode,
            time_left  => time_left,
            score      => score,
            high_score => high_score,
            show_high  => show_high,
            hex0       => hex0,
            hex1       => hex1,
            hex2       => hex2,
            hex3       => hex3,
            hex4       => hex4,
            hex5       => hex5
        );

    stim : process
    begin
        rst_n <= '0';
        wait for 60 ns;
        wait until rising_edge(clk);
        rst_n <= '1';
        wait for 40 ns;

        -- 1. S_OFF must blank all 6 displays
        state <= S_OFF;
        wait for 40 ns;
        assert hex0 = SEG_BLANK and hex1 = SEG_BLANK and hex2 = SEG_BLANK and
               hex3 = SEG_BLANK and hex4 = SEG_BLANK and hex5 = SEG_BLANK
            report "S_OFF did not blank all HEX displays"
            severity failure;

        -- 2. Mode 1 (mode='0'), S_PLAYING: time=45, score=123, high_score=789
        state      <= S_PLAYING;
        mode       <= '0';
        time_left  <= to_unsigned(45, 7);
        score      <= to_unsigned(123, 10);
        high_score <= to_unsigned(789, 10);
        show_high  <= '0';
        wait for 40 ns;

        assert hex5 = EXP_SEG(4) and hex4 = EXP_SEG(5)
            report "Mode 1 time_left (45) wrong on HEX5-4" severity failure;
        assert hex3 = EXP_SEG(1) and hex2 = EXP_SEG(2) and hex1 = EXP_SEG(3)
            report "Score (123) wrong on HEX3-1" severity failure;
        assert hex0 = EXP_SEG(1)
            report "Mode 1 indicator should be 1 on HEX0" severity failure;

        -- 3. SW2 (show_high = '1') switches HEX3-1 to high_score (789)
        show_high <= '1';
        wait for 40 ns;
        assert hex3 = EXP_SEG(7) and hex2 = EXP_SEG(8) and hex1 = EXP_SEG(9)
            report "High score (789) wrong on HEX3-1 when show_high = 1"
            severity failure;

        -- 4. Check remaining digits (0 and 6) via score = 60
        show_high <= '0';
        score     <= to_unsigned(60, 10);
        wait for 40 ns;
        assert hex3 = EXP_SEG(0) and hex2 = EXP_SEG(6) and hex1 = EXP_SEG(0)
            report "Score (060) wrong on HEX3-1" severity failure;

        -- 5. Mode 2 (mode='1') blanks time_left on HEX5-4 and shows '2' on HEX0
        mode <= '1';
        wait for 40 ns;
        assert hex5 = SEG_BLANK and hex4 = SEG_BLANK
            report "Mode 2 must blank HEX5-4" severity failure;
        assert hex0 = EXP_SEG(2)
            report "Mode 2 indicator should be 2 on HEX0" severity failure;

        -- 6. S_GAME_OVER blinks score after 500 ms ticks
        state <= S_GAME_OVER;
        wait for 40 ns;
        assert hex1 = EXP_SEG(0)
            report "Score should be visible at start of S_GAME_OVER" severity failure;

        for i in 0 to 499 loop
            wait until rising_edge(clk);
            tick_1ms <= '1';
            wait until rising_edge(clk);
            tick_1ms <= '0';
        end loop;
        wait for 40 ns;
        assert hex3 = SEG_BLANK and hex2 = SEG_BLANK and hex1 = SEG_BLANK
            report "Score should blink OFF after 500 ms in S_GAME_OVER"
            severity failure;

        done <= true;
        wait;
    end process;

end architecture sim;