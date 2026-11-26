LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.numeric_std.ALL;
USE WORK.game_pkg.ALL;

ENTITY tb_scoring_engine IS
END tb_scoring_engine;

ARCHITECTURE sim OF tb_scoring_engine IS
SIGNAL clk : STD_LOGIC := '0';
SIGNAL rst_n : STD_LOGIC := '0';
SIGNAL mode : STD_LOGIC := '0';
SIGNAL hit_p : STD_LOGIC := '0';
SIGNAL shot_hard : STD_LOGIC := '0';
SIGNAL streak_p : STD_LOGIC := '0';
SIGNAL new_round_p : STD_LOGIC := '0';
SIGNAL clear_score_p : STD_LOGIC := '0';
SIGNAL game_over_p : STD_LOGIC := '0';

SIGNAL score : UNSIGNED(SCORE_W - 1 DOWNTO 0);
SIGNAL high_score : UNSIGNED(SCORE_W - 1 DOWNTO 0);
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

dut : ENTITY WORK.scoring_engine
PORT MAP(
clk => clk,
rst_n => rst_n,
mode => mode,
hit_p => hit_p,
shot_hard => shot_hard,
streak_p => streak_p,
new_round_p => new_round_p,
clear_score_p => clear_score_p,
game_over_p => game_over_p,
score => score,
high_score => high_score
);

stim : PROCESS
BEGIN
rst_n <= '0';
FOR i IN 1 TO 2 LOOP
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT score = 0 AND high_score = 0
REPORT "score and high_score must be 0 during reset" SEVERITY FAILURE;
END LOOP;
rst_n <= '1';

mode <= '0';
hit_p <= '1';
shot_hard <= '0';
streak_p <= '0';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT score = PTS_NORMAL AND high_score = 0
REPORT "normal hit (+1) failed" SEVERITY FAILURE;

shot_hard <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT score = PTS_NORMAL + PTS_HARD
REPORT "hard hit (+2) failed" SEVERITY FAILURE;

hit_p <= '0';
shot_hard <= '0';
streak_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT score = PTS_NORMAL + PTS_HARD + PTS_STREAK
REPORT "streak bonus (+3) failed" SEVERITY FAILURE;

hit_p <= '1';
shot_hard <= '1';
streak_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT score = 11 AND high_score = 0
REPORT "simultaneous hard hit + streak (+5) failed" SEVERITY FAILURE;

hit_p <= '0';
shot_hard <= '0';
streak_p <= '0';
game_over_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT high_score = 11
REPORT "Mode 1 high_score did not update on game_over_p" SEVERITY FAILURE;
game_over_p <= '0';

new_round_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT score = 0 AND high_score = 11
REPORT "new_round_p must clear score and keep high_score" SEVERITY FAILURE;
new_round_p <= '0';

hit_p <= '1';
shot_hard <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
hit_p <= '0';
shot_hard <= '0';
streak_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
streak_p <= '0';
ASSERT score = 5 REPORT "expected score 5" SEVERITY FAILURE;

game_over_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT high_score = 11
REPORT "lower score must not overwrite high_score" SEVERITY FAILURE;
game_over_p <= '0';

streak_p <= '1';
FOR i IN 1 TO 2 LOOP
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
END LOOP;
streak_p <= '0';
ASSERT score = 11 REPORT "expected score 11" SEVERITY FAILURE;

game_over_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT high_score = 11
REPORT "equal score must leave high_score unchanged" SEVERITY FAILURE;
game_over_p <= '0';

clear_score_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT score = 0 AND high_score = 11
REPORT "clear_score_p must clear score and keep high_score" SEVERITY FAILURE;
clear_score_p <= '0';

streak_p <= '1';
FOR i IN 1 TO 5 LOOP
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
END LOOP;
streak_p <= '0';
ASSERT score = 15 REPORT "expected score 15" SEVERITY FAILURE;

game_over_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT high_score = 15
REPORT "higher score did not update Mode 1 high_score" SEVERITY FAILURE;
game_over_p <= '0';

mode <= '1';
WAIT FOR 1 ns;
ASSERT high_score = 0
REPORT "Mode 2 high_score should still be 0" SEVERITY FAILURE;

new_round_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT score = 0 AND high_score = 0
REPORT "Mode 2 new_round_p failed" SEVERITY FAILURE;
new_round_p <= '0';

hit_p <= '1';
shot_hard <= '1';
FOR i IN 1 TO 2 LOOP
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
END LOOP;
hit_p <= '0';
shot_hard <= '0';
streak_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
streak_p <= '0';
ASSERT score = 7 REPORT "expected Mode 2 score 7" SEVERITY FAILURE;

game_over_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT high_score = 7
REPORT "Mode 2 high_score did not update to 7" SEVERITY FAILURE;
game_over_p <= '0';

mode <= '0';
WAIT FOR 1 ns;
ASSERT high_score = 15
REPORT "Mode 1 high_score was corrupted by Mode 2" SEVERITY FAILURE;

mode <= '1';
WAIT FOR 1 ns;
ASSERT high_score = 7
REPORT "Mode 2 high_score did not persist" SEVERITY FAILURE;

mode <= '0';
new_round_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
new_round_p <= '0';

hit_p <= '1';
shot_hard <= '1';
streak_p <= '1';
FOR i IN 1 TO 205 LOOP
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
END LOOP;
hit_p <= '0';
shot_hard <= '0';
streak_p <= '0';
ASSERT score = SCORE_MAX
REPORT "score did not saturate cleanly at SCORE_MAX" SEVERITY FAILURE;

game_over_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT high_score = SCORE_MAX
REPORT "high_score did not update to SCORE_MAX" SEVERITY FAILURE;
game_over_p <= '0';

REPORT "tb_scoring_engine PASSED" SEVERITY NOTE;
done <= TRUE;
WAIT;
END PROCESS;
END sim;