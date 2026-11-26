LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.numeric_std.ALL;
USE WORK.game_pkg.ALL;

ENTITY tb_streak_tracker IS
END tb_streak_tracker;

ARCHITECTURE sim OF tb_streak_tracker IS
SIGNAL clk : STD_LOGIC := '0';
SIGNAL rst_n : STD_LOGIC := '0';
SIGNAL mode : STD_LOGIC := '0';
SIGNAL hit_p : STD_LOGIC := '0';
SIGNAL timeout_p : STD_LOGIC := '0';
SIGNAL new_round_p : STD_LOGIC := '0';
SIGNAL tick_1s : STD_LOGIC := '0';
SIGNAL hit_idx : UNSIGNED(2 DOWNTO 0) := (OTHERS => '0');

SIGNAL streak_p : STD_LOGIC;
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

dut : ENTITY WORK.streak_tracker
PORT MAP(
clk => clk,
rst_n => rst_n,
mode => mode,
hit_p => hit_p,
timeout_p => timeout_p,
new_round_p => new_round_p,
tick_1s => tick_1s,
hit_idx => hit_idx,
streak_p => streak_p
);

stim : PROCESS
BEGIN
rst_n <= '0';
FOR i IN 1 TO 2 LOOP
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0'
REPORT "streak_p must be 0 during reset" SEVERITY FAILURE;
END LOOP;
rst_n <= '1';

mode <= '0';
hit_idx <= to_unsigned(0, 3);
hit_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0' REPORT "unexpected streak on hit 1" SEVERITY FAILURE;

hit_idx <= to_unsigned(2, 3);
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0' REPORT "unexpected streak on hit 2" SEVERITY FAILURE;

hit_p <= '0';
tick_1s <= '1';
FOR i IN 1 TO 3 LOOP
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0' REPORT "unexpected streak during ticks" SEVERITY FAILURE;
END LOOP;
tick_1s <= '0';

hit_p <= '1';
hit_idx <= to_unsigned(4, 3);
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0' REPORT "unexpected streak on hit 3" SEVERITY FAILURE;

hit_idx <= to_unsigned(1, 3);
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0' REPORT "unexpected streak on hit 4" SEVERITY FAILURE;

hit_idx <= to_unsigned(3, 3);
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '1'
REPORT "Mode 1 streak_p did not fire on 5th unique target" SEVERITY FAILURE;

hit_p <= '0';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0'
REPORT "Mode 1 streak_p must be a 1-clock pulse" SEVERITY FAILURE;

hit_p <= '1';
hit_idx <= to_unsigned(0, 3);
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
hit_idx <= to_unsigned(1, 3);
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
hit_idx <= to_unsigned(1, 3);
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0' REPORT "repeat hit must not fire streak" SEVERITY FAILURE;

hit_idx <= to_unsigned(2, 3);
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
hit_idx <= to_unsigned(3, 3);
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
hit_idx <= to_unsigned(4, 3);
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0'
REPORT "repeat hit did not clear previous Mode 1 streak" SEVERITY FAILURE;

hit_p <= '0';
new_round_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
new_round_p <= '0';

hit_p <= '1';
FOR i IN 0 TO 3 LOOP
hit_idx <= to_unsigned(i, 3);
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0' REPORT "unexpected streak before 5th target" SEVERITY FAILURE;
END LOOP;
hit_p <= '0';

tick_1s <= '1';
FOR i IN 1 TO STREAK_WINDOW_S LOOP
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
END LOOP;
tick_1s <= '0';

hit_p <= '1';
hit_idx <= to_unsigned(4, 3);
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0'
REPORT "window expiry did not clear Mode 1 mask" SEVERITY FAILURE;
hit_p <= '0';

new_round_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
new_round_p <= '0';

hit_p <= '1';
FOR i IN 0 TO 3 LOOP
hit_idx <= to_unsigned(i, 3);
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0'
REPORT "new_round_p did not clear Mode 1 mask" SEVERITY FAILURE;
END LOOP;

hit_idx <= to_unsigned(5, 3);
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0'
REPORT "out-of-range hit_idx must be ignored" SEVERITY FAILURE;
hit_p <= '0';

mode <= '1';
new_round_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
new_round_p <= '0';

hit_p <= '1';
hit_idx <= to_unsigned(0, 3);
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0' REPORT "Mode 2 streak fired on hit 1" SEVERITY FAILURE;

WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0' REPORT "Mode 2 streak fired on hit 2" SEVERITY FAILURE;

WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '1'
REPORT "Mode 2 streak_p did not fire on 3rd consecutive hit" SEVERITY FAILURE;

hit_p <= '0';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0'
REPORT "Mode 2 streak_p must be a 1-clock pulse" SEVERITY FAILURE;

hit_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
hit_p <= '0';

timeout_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
timeout_p <= '0';

hit_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0' REPORT "timeout_p did not reset Mode 2 run (hit 1)" SEVERITY FAILURE;
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0' REPORT "timeout_p did not reset Mode 2 run (hit 2)" SEVERITY FAILURE;
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '1' REPORT "Mode 2 streak did not fire on 3rd hit after timeout" SEVERITY FAILURE;
hit_p <= '0';

hit_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
hit_p <= '0';

new_round_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
new_round_p <= '0';

hit_p <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT streak_p = '0'
REPORT "new_round_p did not reset Mode 2 run" SEVERITY FAILURE;
hit_p <= '0';

REPORT "tb_streak_tracker PASSED" SEVERITY NOTE;
done <= TRUE;
WAIT;
END PROCESS;
END sim;