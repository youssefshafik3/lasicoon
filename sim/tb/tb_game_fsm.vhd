LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.numeric_std.ALL;
USE WORK.game_pkg.ALL;

ENTITY tb_game_fsm IS
END tb_game_fsm;

ARCHITECTURE sim OF tb_game_fsm IS
SIGNAL clk : STD_LOGIC := '0';
SIGNAL rst_n : STD_LOGIC := '0';
SIGNAL sw_on : STD_LOGIC := '0';
SIGNAL sw_mode : STD_LOGIC := '0';
SIGNAL start_p : STD_LOGIC := '0';
SIGNAL reset_score_p : STD_LOGIC := '0';
SIGNAL tick_1s : STD_LOGIC := '0';
SIGNAL timeout_p : STD_LOGIC := '0';

SIGNAL state : game_state_t;
SIGNAL mode : STD_LOGIC;
SIGNAL time_left : UNSIGNED(6 DOWNTO 0);
SIGNAL lives : UNSIGNED(1 DOWNTO 0);
SIGNAL new_round_p : STD_LOGIC;
SIGNAL game_over_p : STD_LOGIC;
SIGNAL clear_score_p : STD_LOGIC;
SIGNAL done : BOOLEAN := FALSE;
BEGIN
clk_proc : PROCESS
BEGIN
WHILE NOT done LOOP
clk <= '0';
WAIT FOR 10 ns;
clk <= '1';
WAIT FOR 10 ns;
END LOOP;
WAIT;
END PROCESS;

dut : ENTITY WORK.game_fsm
PORT MAP(
clk => clk,
rst_n => rst_n,
sw_on => sw_on,
sw_mode => sw_mode,
start_p => start_p,
reset_score_p => reset_score_p,
tick_1s => tick_1s,
timeout_p => timeout_p,
state => state,
mode => mode,
time_left => time_left,
lives => lives,
new_round_p => new_round_p,
game_over_p => game_over_p,
clear_score_p => clear_score_p
);

stim : PROCESS
BEGIN
rst_n <= '0';
sw_on <= '0';
FOR i IN 1 TO 2 LOOP
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_OFF AND time_left = 0 AND lives = 0
REPORT "must stay in S_OFF during reset" SEVERITY FAILURE;
ASSERT new_round_p = '0' AND game_over_p = '0' AND clear_score_p = '0'
REPORT "pulses must be 0 during reset" SEVERITY FAILURE;
END LOOP;

rst_n <= '1';
start_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_OFF AND new_round_p = '0'
REPORT "start_p must be ignored when sw_on is 0" SEVERITY FAILURE;
start_p <= '0';

sw_on <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_READY
REPORT "must enter S_READY when sw_on goes high" SEVERITY FAILURE;

sw_on <= '0';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_OFF
REPORT "dropping sw_on in S_READY must go to S_OFF" SEVERITY FAILURE;

sw_on <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_READY
REPORT "must return to S_READY when sw_on goes high again" SEVERITY FAILURE;

sw_mode <= '0';
start_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_PLAYING AND mode = '0' AND new_round_p = '1'
REPORT "Mode 1 did not start properly" SEVERITY FAILURE;
ASSERT time_left = ROUND_SECONDS AND lives = LIVES_START
REPORT "Mode 1 initial timer or lives wrong" SEVERITY FAILURE;

start_p <= '0';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT new_round_p = '0'
REPORT "new_round_p must be a 1-clock pulse" SEVERITY FAILURE;

tick_1s <= '1';
FOR i IN 1 TO 2 LOOP
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
END LOOP;
tick_1s <= '0';
ASSERT time_left = ROUND_SECONDS - 2
REPORT "Mode 1 timer did not decrement" SEVERITY FAILURE;

sw_mode <= '1';
start_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_PLAYING AND mode = '0' AND new_round_p = '0' AND time_left = ROUND_SECONDS - 2
REPORT "start_p must be ignored during S_PLAYING" SEVERITY FAILURE;
start_p <= '0';
sw_mode <= '0';

timeout_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_PLAYING AND lives = LIVES_START AND game_over_p = '0'
REPORT "timeout_p must be ignored in Mode 1" SEVERITY FAILURE;
timeout_p <= '0';

reset_score_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT clear_score_p = '1' AND state = S_PLAYING AND time_left = ROUND_SECONDS AND lives = LIVES_START
REPORT "reset_score_p failed in S_PLAYING" SEVERITY FAILURE;

reset_score_p <= '0';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT clear_score_p = '0'
REPORT "clear_score_p must be a 1-clock pulse" SEVERITY FAILURE;

tick_1s <= '1';
FOR i IN 1 TO ROUND_SECONDS - 1 LOOP
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_PLAYING AND game_over_p = '0' AND time_left = ROUND_SECONDS - i
REPORT "Mode 1 countdown wrong" SEVERITY FAILURE;
END LOOP;

WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_GAME_OVER AND game_over_p = '1' AND time_left = 0
REPORT "Mode 1 did not trigger S_GAME_OVER at 0" SEVERITY FAILURE;

tick_1s <= '0';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT game_over_p = '0' AND state = S_GAME_OVER
REPORT "game_over_p must be a 1-clock pulse" SEVERITY FAILURE;

sw_mode <= '1';
start_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_PLAYING AND mode = '1' AND new_round_p = '1' AND lives = LIVES_START
REPORT "Mode 2 did not start from S_GAME_OVER" SEVERITY FAILURE;

start_p <= '0';
tick_1s <= '1';
FOR i IN 1 TO 3 LOOP
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_PLAYING AND time_left = ROUND_SECONDS AND lives = LIVES_START AND game_over_p = '0'
REPORT "tick_1s must not affect Mode 2" SEVERITY FAILURE;
END LOOP;
tick_1s <= '0';

timeout_p <= '1';
FOR i IN 1 TO LIVES_START - 1 LOOP
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_PLAYING AND game_over_p = '0' AND lives = LIVES_START - i
REPORT "Mode 2 lives did not decrement properly" SEVERITY FAILURE;
END LOOP;

WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_GAME_OVER AND game_over_p = '1' AND lives = 0
REPORT "Mode 2 did not trigger S_GAME_OVER at 0 lives" SEVERITY FAILURE;

timeout_p <= '0';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT game_over_p = '0' AND state = S_GAME_OVER
REPORT "Mode 2 game_over_p must be a 1-clock pulse" SEVERITY FAILURE;

sw_on <= '0';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_OFF
REPORT "dropping sw_on in S_GAME_OVER must go to S_OFF" SEVERITY FAILURE;

sw_on <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
start_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_PLAYING
REPORT "failed to re-enter S_PLAYING" SEVERITY FAILURE;

start_p <= '0';
sw_on <= '0';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT state = S_OFF
REPORT "dropping sw_on in S_PLAYING must go to S_OFF" SEVERITY FAILURE;

REPORT "tb_game_fsm PASSED" SEVERITY NOTE;
done <= TRUE;
WAIT;
END PROCESS;
END sim;