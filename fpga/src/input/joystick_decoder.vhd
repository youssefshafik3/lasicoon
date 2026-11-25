-------------------------------------------------------------------------------
-- File    : joystick_decoder.vhd
-- Owner   : Person B
-- Purpose : Turns the joystick numbers x and y (0..254, centre about 128)
--           into four direction levels: left, right, up, down.
--           Uses a deadzone around the centre and a little hysteresis so a
--           value hovering near a threshold does not flicker.
--           It does NOT move any servo (that is turret_ctrl's job).
--
-- Generics: LOW_ON   : integer := 100   below this a direction turns ON
--           HIGH_ON  : integer := 155   above this a direction turns ON
--           HYST     : integer := 8     how far back inside the deadzone the
--                                       value must come before it turns OFF
--           INVERT_X : boolean := false swap left/right  (fix on real hardware)
--           INVERT_Y : boolean := false swap up/down     (fix on real hardware)
--
-- Ports   : clk, rst_n    clock and synchronous active-low reset
--           x, y          unsigned 8-bit, from sensor_frame_parser
--           link_lost     '1' = Arduino silent: all four outputs forced low
--           left, right, up, down   levels (not pulses)
--
-- NOTE    : the team plan lists only x, y, link_lost as inputs. Hysteresis
--           needs a memory, so clk and rst_n were added. Tell E to update
--           docs/interfaces.md.
--
-- Default mapping (to be checked on the real joystick):
--           x low = left,  x high = right,  y low = up,  y high = down.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity joystick_decoder is
  generic (
    LOW_ON   : integer := 100;
    HIGH_ON  : integer := 155;
    HYST     : integer := 8;
    INVERT_X : boolean := false;
    INVERT_Y : boolean := false
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;                        -- sync, active low
    x         : in  unsigned(7 downto 0);
    y         : in  unsigned(7 downto 0);
    link_lost : in  std_logic;
    left      : out std_logic;
    right     : out std_logic;
    up        : out std_logic;
    down      : out std_logic
  );
end entity;

architecture rtl of joystick_decoder is

  -- one flag per physical direction of each axis
  signal x_lo : std_logic := '0';   -- x is low  (default: left)
  signal x_hi : std_logic := '0';   -- x is high (default: right)
  signal y_lo : std_logic := '0';   -- y is low  (default: up)
  signal y_hi : std_logic := '0';   -- y is high (default: down)

begin

  process (clk)
  begin
    if rising_edge(clk) then

      if rst_n = '0' or link_lost = '1' then
        x_lo <= '0';
        x_hi <= '0';
        y_lo <= '0';
        y_hi <= '0';
      else

        -- x axis, low side: ON below LOW_ON, OFF again from LOW_ON+HYST up
        if to_integer(x) < LOW_ON then
          x_lo <= '1';
        elsif to_integer(x) >= LOW_ON + HYST then
          x_lo <= '0';
        end if;

        -- x axis, high side: ON above HIGH_ON, OFF again from HIGH_ON-HYST down
        if to_integer(x) > HIGH_ON then
          x_hi <= '1';
        elsif to_integer(x) <= HIGH_ON - HYST then
          x_hi <= '0';
        end if;

        -- y axis, low side
        if to_integer(y) < LOW_ON then
          y_lo <= '1';
        elsif to_integer(y) >= LOW_ON + HYST then
          y_lo <= '0';
        end if;

        -- y axis, high side
        if to_integer(y) > HIGH_ON then
          y_hi <= '1';
        elsif to_integer(y) <= HIGH_ON - HYST then
          y_hi <= '0';
        end if;

      end if;
    end if;
  end process;

  -- the INVERT generics swap the two sides of an axis, nothing else
  left  <= x_hi when INVERT_X else x_lo;
  right <= x_lo when INVERT_X else x_hi;
  up    <= y_hi when INVERT_Y else y_lo;
  down  <= y_lo when INVERT_Y else y_hi;

end architecture;
