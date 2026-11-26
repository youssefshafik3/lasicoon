LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.numeric_std.ALL;
USE WORK.game_pkg.ALL;

ENTITY streak_tracker IS
PORT(clk, rst_n, mode, hit_p, timeout_p,
new_round_p, tick_1s : IN STD_LOGIC;
hit_idx : IN UNSIGNED(2 DOWNTO 0);
streak_p : OUT STD_LOGIC);
END streak_tracker;

ARCHITECTURE streak_tracker_beh OF streak_tracker IS
CONSTANT MASK_ZEROS : STD_LOGIC_VECTOR(N_TARGETS - 1 DOWNTO 0) := (OTHERS => '0');
CONSTANT MASK_ONES : STD_LOGIC_VECTOR(N_TARGETS - 1 DOWNTO 0) := (OTHERS => '1');
SIGNAL mask : STD_LOGIC_VECTOR(N_TARGETS - 1 DOWNTO 0) := (OTHERS => '0');
SIGNAL window : UNSIGNED(5 DOWNTO 0) := (OTHERS => '0');
SIGNAL run : UNSIGNED(1 DOWNTO 0) := (OTHERS => '0');
BEGIN
PROCESS(clk)
VARIABLE next_mask : STD_LOGIC_VECTOR(N_TARGETS - 1 DOWNTO 0);
VARIABLE idx : INTEGER;
BEGIN
IF rising_edge(clk) THEN
streak_p <= '0';

IF rst_n = '0' OR new_round_p = '1' THEN
mask <= (OTHERS => '0');
window <= (OTHERS => '0');
run <= (OTHERS => '0');
ELSE
IF mode = '0' THEN
IF hit_p = '1' THEN
idx := to_integer(hit_idx);
IF idx < N_TARGETS THEN
IF mask(idx) = '1' THEN
mask <= (OTHERS => '0');
window <= (OTHERS => '0');
ELSE
next_mask := mask;
next_mask(idx) := '1';
IF next_mask = MASK_ONES THEN
streak_p <= '1';
mask <= (OTHERS => '0');
window <= (OTHERS => '0');
ELSE
mask <= next_mask;
IF mask = MASK_ZEROS THEN
window <= to_unsigned(STREAK_WINDOW_S, window'LENGTH);
END IF;
END IF;
END IF;
END IF;

ELSIF tick_1s = '1' THEN
IF window > 0 THEN
IF window = 1 THEN
window <= (OTHERS => '0');
mask <= (OTHERS => '0');
ELSE
window <= window - 1;
END IF;
END IF;
END IF;

ELSIF mode = '1' THEN
IF timeout_p = '1' THEN
run <= (OTHERS => '0');
ELSIF hit_p = '1' THEN
IF run = 2 THEN
streak_p <= '1';
run <= (OTHERS => '0');
ELSE
run <= run + 1;
END IF;
END IF;
END IF;
END IF;
END IF;
END PROCESS;
END streak_tracker_beh;