LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.numeric_std.ALL;
USE WORK.game_pkg.ALL;

ENTITY scoring_engine IS
PORT(clk, rst_n, mode, hit_p, shot_hard, streak_p,
new_round_p, clear_score_p, game_over_p : IN STD_LOGIC;
score : OUT UNSIGNED(SCORE_W - 1 DOWNTO 0);
high_score : OUT UNSIGNED(SCORE_W - 1 DOWNTO 0));
END scoring_engine;

ARCHITECTURE scoring_engine_beh OF scoring_engine IS
SIGNAL score_r : UNSIGNED(SCORE_W - 1 DOWNTO 0) := (OTHERS => '0');
SIGNAL hi_mode1 : UNSIGNED(SCORE_W - 1 DOWNTO 0) := (OTHERS => '0');
SIGNAL hi_mode2 : UNSIGNED(SCORE_W - 1 DOWNTO 0) := (OTHERS => '0');
BEGIN
PROCESS(clk)
VARIABLE add_pts : INTEGER;
VARIABLE next_score : INTEGER;
BEGIN
IF rising_edge(clk) THEN
IF rst_n = '0' THEN
score_r <= (OTHERS => '0');
hi_mode1 <= (OTHERS => '0');
hi_mode2 <= (OTHERS => '0');
ELSE
IF new_round_p = '1' OR clear_score_p = '1' THEN
score_r <= (OTHERS => '0');
ELSE
add_pts := 0;
IF hit_p = '1' THEN
IF shot_hard = '1' THEN
add_pts := PTS_HARD;
ELSE
add_pts := PTS_NORMAL;
END IF;
END IF;

IF streak_p = '1' THEN
add_pts := add_pts + PTS_STREAK;
END IF;

IF add_pts > 0 THEN
next_score := to_integer(score_r) + add_pts;
IF next_score >= SCORE_MAX THEN
score_r <= to_unsigned(SCORE_MAX, score_r'LENGTH);
ELSE
score_r <= to_unsigned(next_score, score_r'LENGTH);
END IF;
END IF;
END IF;

IF game_over_p = '1' THEN
IF mode = '0' THEN
IF score_r > hi_mode1 THEN
hi_mode1 <= score_r;
END IF;
ELSE
IF score_r > hi_mode2 THEN
hi_mode2 <= score_r;
END IF;
END IF;
END IF;
END IF;
END IF;
END PROCESS;

score <= score_r;
high_score <= hi_mode1 WHEN mode = '0' ELSE hi_mode2;
END scoring_engine_beh;