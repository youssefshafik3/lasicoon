LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE WORK.game_pkg.ALL;

ENTITY game_fsm IS
PORT(clk, rst_n, sw_on, sw_mode, start_p,
reset_score_p, tick_1s, timeout_p : IN STD_LOGIC;
state : OUT game_state_t;
mode : OUT STD_LOGIC;
time_left : OUT UNSIGNED(6 downto 0);
lives : OUT UNSIGNED(1 downto 0);
new_round_p, game_over_p, clear_score_p : OUT STD_LOGIC);
END game_fsm;

ARCHITECTURE game_fsm_beh OF game_fsm IS
SIGNAL state_r : game_state_t;
SIGNAL mode_r : STD_LOGIC;
SIGNAL time_left_r : UNSIGNED(6 downto 0);
SIGNAL lives_r : UNSIGNED(1 downto 0);
BEGIN
PROCESS(clk)
BEGIN 
IF rising_edge(clk) THEN
new_round_p <= '0';
game_over_p <= '0';
clear_score_p <= '0';

IF rst_n = '0' OR sw_on = '0' THEN
state_r <= S_OFF;
mode_r <= '0';
time_left_r <= (OTHERS => '0');
lives_r <= (OTHERS => '0');

ELSE 
CASE state_r IS
WHEN S_OFF => state_r <= S_READY;

WHEN S_READY | S_GAME_OVER => 
IF start_p = '1' THEN 
mode_r <= sw_mode;
new_round_p <= '1';
state_r <= S_PLAYING;
lives_r <= to_unsigned(LIVES_START,lives_r'length);
time_left_r <= to_unsigned(ROUND_SECONDS, time_left_r'length);
END IF;

WHEN S_PLAYING => 
IF reset_score_p = '1' THEN
clear_score_p <= '1';
lives_r <= to_unsigned(LIVES_START,lives_r'length);
time_left_r <= to_unsigned(ROUND_SECONDS, time_left_r'length);

ELSIF mode_r = '0' THEN
IF tick_1s = '1' THEN
IF time_left_r = 1 THEN
time_left_r <= (OTHERS => '0');
game_over_p <= '1';
state_r <= S_GAME_OVER;
ELSE
time_left_r <= time_left_r - 1;
END IF;
END IF;

ELSIF mode_r = '1' THEN
IF timeout_p = '1' THEN
IF lives_r = 1 THEN 
lives_r <= (OTHERS => '0');
game_over_p <= '1';
state_r <= S_GAME_OVER;
ELSE
lives_r <= lives_r - 1;
END IF;
END IF;

END IF;
END CASE;
END IF;
END IF;
END PROCESS;
state <= state_r;
mode <= mode_r;
time_left <= time_left_r;
lives <= lives_r;

END game_fsm_beh;