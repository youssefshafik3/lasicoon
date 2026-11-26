-- ============================================================================
-- File        : tb_top_level.vhd
-- Owner       : Person E
-- Purpose     : System-level integration testbench for top_level. Drives
--               switches, debounced buttons, UART frames, and IR receiver hits.
-- Assumptions : VHDL-93 compliant; requires all modules (or stubs) compiled.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.game_pkg.all;

entity tb_top_level is
end entity tb_top_level;

architecture sim of tb_top_level is
    constant CLK_PERIOD : time := 20 ns;
    constant BIT_PERIOD : time := 104167 ns; -- 9600 baud (1 / 9600 s)

    signal MAX10_CLK1_50 : std_logic := '0';
    signal KEY           : std_logic_vector(1 downto 0) := "11"; -- Active-low
    signal SW            : std_logic_vector(9 downto 0) := (others => '0');
    signal LEDR          : std_logic_vector(9 downto 0);
    signal HEX0          : std_logic_vector(7 downto 0);
    signal HEX1          : std_logic_vector(7 downto 0);
    signal HEX2          : std_logic_vector(7 downto 0);
    signal HEX3          : std_logic_vector(7 downto 0);
    signal HEX4          : std_logic_vector(7 downto 0);
    signal HEX5          : std_logic_vector(7 downto 0);
    signal GPIO          : std_logic_vector(35 downto 0) := (others => 'Z');

    -- Driven input signals mapped onto GPIO
    signal uart_tx_tb    : std_logic := '1';
    signal fire_btn_n_tb : std_logic := '1';
    signal rx_in_tb      : std_logic_vector(N_TARGETS - 1 downto 0) := (others => '1');

    signal done          : boolean := false;

    procedure send_uart_byte(
        signal tx_line : out std_logic;
        constant data  : in  std_logic_vector(7 downto 0)
    ) is
    begin
        -- Start bit
        tx_line <= '0';
        wait for BIT_PERIOD;
        -- 8 data bits (LSB first)
        for b in 0 to 7 loop
            tx_line <= data(b);
            wait for BIT_PERIOD;
        end loop;
        -- Stop bit
        tx_line <= '1';
        wait for BIT_PERIOD;
    end procedure;

begin

    -- Drive only FPGA input pins on bidirectional GPIO bus
    GPIO(0)           <= uart_tx_tb;
    GPIO(1)           <= fire_btn_n_tb;
    GPIO(14 downto 10) <= rx_in_tb;

    clk_proc : process
    begin
        while not done loop
            MAX10_CLK1_50 <= '0';
            wait for CLK_PERIOD / 2;
            MAX10_CLK1_50 <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    dut : entity work.top_level
        port map (
            MAX10_CLK1_50 => MAX10_CLK1_50,
            KEY           => KEY,
            SW            => SW,
            LEDR          => LEDR,
            HEX0          => HEX0,
            HEX1          => HEX1,
            HEX2          => HEX2,
            HEX3          => HEX3,
            HEX4          => HEX4,
            HEX5          => HEX5,
            GPIO          => GPIO
        );

    stim : process
    begin
        -- 1. Initially SW(0) = '0' (OFF state) -> HEX0 blank
        wait for 500 ns;
        assert HEX0 = x"FF"
            report "HEX0 should be blank when SW(0) = 0 (OFF)"
            severity failure;

        -- 2. Turn system ON (SW(0) = '1') -> enters READY, Mode 1 selected (SW(1) = '0')
        SW(0) <= '1';
        SW(1) <= '0';
        wait for 200 us;
        assert HEX0 = "11111001"
            report "HEX0 should show '1' in READY for Mode 1"
            severity failure;

        -- 3. Press START (KEY(0) active-low for >10 ms debounce)
        KEY(0) <= '0';
        wait for 12 ms;
        KEY(0) <= '1';
        wait for 1 ms;

        -- 4. Send one Arduino UART frame: [0xFF, x=200 (right), y=128 (center), ldr=200]
        send_uart_byte(uart_tx_tb, x"FF");
        send_uart_byte(uart_tx_tb, std_logic_vector(to_unsigned(200, 8)));
        send_uart_byte(uart_tx_tb, std_logic_vector(to_unsigned(128, 8)));
        send_uart_byte(uart_tx_tb, std_logic_vector(to_unsigned(200, 8)));

        -- 5. Press FIRE (GPIO(1) active-low for >10 ms), then simulate IR hit on target 0
        fire_btn_n_tb <= '0';
        wait for 12 ms;
        fire_btn_n_tb <= '1';

        -- Pull receiver 0 active-low while shot window is open
        wait for 100 us;
        rx_in_tb(0) <= '0';
        wait for 200 us;
        rx_in_tb(0) <= '1';
        wait for 500 us;

        -- Score should now be 001 -> HEX1 shows '1' ("11111001")
        assert HEX1 = "11111001"
            report "Score on HEX1 did not increment to 1 after target hit"
            severity failure;

        -- 6. Press RESET SCORE (KEY(1) active-low for >10 ms) -> score clears to 0
        KEY(1) <= '0';
        wait for 12 ms;
        KEY(1) <= '1';
        wait for 1 ms;

        assert HEX1 = "11000000"
            report "Score on HEX1 did not reset to 0 after KEY(1)"
            severity failure;

        done <= true;
        wait;
    end process;

end architecture sim;