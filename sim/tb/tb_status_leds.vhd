-- ============================================================================
-- tb_status_leds.vhd  (Person D)
-- Checks: hearts for 3/2/1/0 lives, hearts hidden in Mode 1 and READY, night
--         LED, each flash LED (hit, miss, timeout, streak) lasts exactly
--         FLASH_CYCLES clocks and only lights its own LED, everything off in
--         OFF, unused LEDs stay off.
-- Scaled generic: flash = 20 clocks.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity tb_status_leds is
end entity tb_status_leds;

architecture sim of tb_status_leds is
    constant CLK_PERIOD  : time    := 20 ns;
    constant TB_FLASH_CY : natural := 20;

    signal clk       : std_logic := '0';
    signal rst_n     : std_logic := '0';
    signal state     : game_state_t := S_OFF;
    signal mode      : std_logic := '0';
    signal lives     : unsigned(1 downto 0) := (others => '0');
    signal night     : std_logic := '0';
    signal hit_p     : std_logic := '0';
    signal miss_p    : std_logic := '0';
    signal streak_p  : std_logic := '0';
    signal timeout_p : std_logic := '0';
    signal ledr      : std_logic_vector(9 downto 0);
    signal done      : boolean := false;
begin
    clk_proc : process
    begin
        while not done loop
            clk <= '0'; wait for CLK_PERIOD / 2;
            clk <= '1'; wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    dut : entity work.status_leds
        generic map (FLASH_CYCLES => TB_FLASH_CY)
        port map (
            clk       => clk,
            rst_n     => rst_n,
            state     => state,
            mode      => mode,
            lives     => lives,
            night     => night,
            hit_p     => hit_p,
            miss_p    => miss_p,
            streak_p  => streak_p,
            timeout_p => timeout_p,
            ledr      => ledr
        );

    stim : process
        variable exp_b : std_logic;

        procedure tick(constant n : in natural) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk);
            end loop;
        end procedure;

        -- Pulse one trigger for one clock; LED 'led' (4..6) must then be on
        -- for exactly TB_FLASH_CY clocks while the other two flash LEDs stay off.
        procedure check_flash(signal trig : out std_logic; constant led : in natural) is
            variable expv : std_logic_vector(2 downto 0);
        begin
            expv := "000";
            expv(led - 4) := '1';
            tick(1);
            trig <= '1';
            tick(1);
            trig <= '0';
            for i in 1 to TB_FLASH_CY loop
                tick(1);
                assert ledr(6 downto 4) = expv
                    report "flash LED wrong while the flash should be on" severity failure;
            end loop;
            tick(1);
            assert ledr(6 downto 4) = "000"
                report "flash LED did not switch off after FLASH_CYCLES" severity failure;
        end procedure;
    begin
        rst_n <= '0';
        tick(3);
        rst_n <= '1';
        tick(1);

        -- hearts, Mode 2 PLAYING
        state <= S_PLAYING;
        mode  <= '1';
        for k in 3 downto 0 loop
            lives <= to_unsigned(k, 2);
            tick(1);
            for b in 0 to 2 loop
                if b < k then
                    exp_b := '1';
                else
                    exp_b := '0';
                end if;
                assert ledr(b) = exp_b report "heart LED wrong" severity failure;
            end loop;
        end loop;
        assert ledr(9 downto 7) = "000" report "unused LEDs must be off" severity failure;

        -- hearts hidden in Mode 1
        mode  <= '0';
        lives <= to_unsigned(3, 2);
        tick(1);
        assert ledr(2 downto 0) = "000" report "no hearts in Mode 1" severity failure;

        -- hearts hidden in READY (mode/lives hold old values there)
        mode  <= '1';
        state <= S_READY;
        tick(1);
        assert ledr(2 downto 0) = "000" report "no hearts in READY" severity failure;

        -- hearts still shown in GAME_OVER
        state <= S_GAME_OVER;
        lives <= to_unsigned(1, 2);
        tick(1);
        assert ledr(2 downto 0) = "001" report "hearts shown in GAME_OVER" severity failure;

        -- night LED
        state <= S_PLAYING;
        night <= '1';
        tick(1);
        assert ledr(3) = '1' report "night LED should be on" severity failure;
        night <= '0';
        tick(1);
        assert ledr(3) = '0' report "night LED should be off" severity failure;

        -- flashes
        lives <= to_unsigned(2, 2);
        check_flash(hit_p,     4);
        check_flash(miss_p,    5);
        check_flash(timeout_p, 5);
        check_flash(streak_p,  6);

        -- everything off in S_OFF
        night <= '1';
        lives <= to_unsigned(3, 2);
        state <= S_OFF;
        tick(1);
        assert ledr = "0000000000" report "all LEDs must be off in S_OFF" severity failure;

        report "tb_status_leds: PASS" severity note;
        done <= true;
        wait;
    end process;
end architecture sim;
