LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY tb_tick_gen IS
END tb_tick_gen;

ARCHITECTURE sim OF tb_tick_gen IS
CONSTANT SIM_CLK_FREQ : INTEGER := 2000;
CONSTANT SIM_CLK_PER_MS : INTEGER := SIM_CLK_FREQ / 1000;

SIGNAL clk : STD_LOGIC := '0';
SIGNAL rst_n : STD_LOGIC := '0';
SIGNAL tick_1ms : STD_LOGIC;
SIGNAL tick_1s : STD_LOGIC;
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

dut : ENTITY WORK.tick_gen
GENERIC MAP(CLK_FREQ => SIM_CLK_FREQ)
PORT MAP(
clk => clk,
rst_n => rst_n,
tick_1ms => tick_1ms,
tick_1s => tick_1s
);

stim : PROCESS
VARIABLE ms_count : INTEGER := 0;
VARIABLE s_count : INTEGER := 0;
BEGIN
rst_n <= '0';
FOR i IN 1 TO 3 LOOP
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT tick_1ms = '0' AND tick_1s = '0'
REPORT "ticks must stay 0 during reset" SEVERITY FAILURE;
END LOOP;

rst_n <= '1';
FOR sec IN 1 TO 2 LOOP
FOR i IN 1 TO SIM_CLK_FREQ LOOP
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;

IF i MOD SIM_CLK_PER_MS = 0 THEN
ASSERT tick_1ms = '1'
REPORT "tick_1ms missing on expected clock" SEVERITY FAILURE;
ms_count := ms_count + 1;
ELSE
ASSERT tick_1ms = '0'
REPORT "tick_1ms high on wrong clock" SEVERITY FAILURE;
END IF;

IF i = SIM_CLK_FREQ THEN
ASSERT tick_1s = '1'
REPORT "tick_1s missing on expected clock" SEVERITY FAILURE;
s_count := s_count + 1;
ELSE
ASSERT tick_1s = '0'
REPORT "tick_1s high on wrong clock" SEVERITY FAILURE;
END IF;
END LOOP;
END LOOP;

ASSERT ms_count = 2000 AND s_count = 2
REPORT "wrong total tick count" SEVERITY FAILURE;

WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
rst_n <= '0';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT tick_1ms = '0' AND tick_1s = '0'
REPORT "mid-run reset did not clear ticks" SEVERITY FAILURE;

rst_n <= '1';
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT tick_1ms = '0'
REPORT "counter did not restart from 0 after reset" SEVERITY FAILURE;
WAIT UNTIL rising_edge(clk);
WAIT FOR 1 ns;
ASSERT tick_1ms = '1'
REPORT "tick_1ms did not fire on 2nd cycle after reset" SEVERITY FAILURE;

REPORT "tb_tick_gen PASSED" SEVERITY NOTE;
done <= TRUE;
WAIT;
END PROCESS;
END sim;