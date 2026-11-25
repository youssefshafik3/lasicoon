
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ir_burst_tx is
  generic (
    HALF_PERIOD   : positive := 658;
    WINDOW_CLKS   : positive := 7_500_000;
    COOLDOWN_CLKS : positive := 20_000_000
  );
  port (
    clk              : in  std_logic;
    rst_n            : in  std_logic;
    playing          : in  std_logic;
    night            : in  std_logic;
    fire_p           : in  std_logic;
    hit_seen         : in  std_logic;
    ir_out           : out std_logic;
    laser_sight      : out std_logic;
    window_open      : out std_logic;
    window_expired_p : out std_logic;
    shot_hard        : out std_logic;
    busy             : out std_logic
  );
end entity;

architecture rtl of ir_burst_tx is
  type state_t is (IDLE, BURST, COOLDOWN);
  signal state       : state_t := IDLE;
  signal win_cnt     : unsigned(24 downto 0) := (others => '0');  -- window / cooldown counter
  signal half_cnt    : unsigned(15 downto 0) := (others => '0');  -- 38 kHz half-period counter
  signal ir_r        : std_logic := '0';
  signal shot_hard_r : std_logic := '0';
  signal expired_r   : std_logic := '0';
begin

  -- these never depend on the FSM state machine logic
  laser_sight      <= playing and (not night);
  window_open      <= '1' when state = BURST else '0';
  busy             <= '0' when state = IDLE  else '1';
  ir_out           <= ir_r;
  shot_hard        <= shot_hard_r;
  window_expired_p <= expired_r;

  process (clk)
  begin
    if clk'EVENT and clk='1' then
      expired_r <= '0';                       -- pulses default to 0 every clock

      if rst_n = '0' then
        state       <= IDLE;
        win_cnt     <= (others => '0');
        half_cnt    <= (others => '0');
        ir_r        <= '0';
        shot_hard_r <= '0';
      else
        case state is

          when IDLE =>
            ir_r <= '0';
            if fire_p = '1' and playing = '1' then
              shot_hard_r <= night;           -- remember: night shot = hard = more points
              win_cnt     <= (others => '0');
              half_cnt    <= (others => '0');
              ir_r        <= '1';             -- first high half of the 38 kHz wave
              state       <= BURST;
            end if;

          when BURST =>
            if hit_seen = '1' then            -- a target was hit: stop early
              ir_r    <= '0';
              win_cnt <= (others => '0');
              state   <= COOLDOWN;
            elsif win_cnt = WINDOW_CLKS - 1 then   -- window over, nothing hit
              ir_r       <= '0';
              win_cnt    <= (others => '0');
              expired_r  <= '1';              -- tell hit_detector: miss
              state      <= COOLDOWN;
            else
              win_cnt <= win_cnt + 1;
              if half_cnt = HALF_PERIOD - 1 then
                half_cnt <= (others => '0');
                ir_r     <= not ir_r;         -- flip the 38 kHz wave
              else
                half_cnt <= half_cnt + 1;
              end if;
            end if;

          when COOLDOWN =>
            ir_r <= '0';
            if win_cnt = COOLDOWN_CLKS - 1 then
              win_cnt <= (others => '0');
              state   <= IDLE;
            else
              win_cnt <= win_cnt + 1;
            end if;

        end case;
      end if;
    end if;
  end process;

end architecture;
