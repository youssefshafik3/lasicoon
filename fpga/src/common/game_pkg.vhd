LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

PACKAGE game_pkg IS --THIS FILE IS DEDICATED FOR THE CONSTANTS OF THE GAME

  -- General
  CONSTANT CLK_FREQ          : INTEGER := 50000000;
  CONSTANT N_TARGETS         : INTEGER := 5;
  -- Game states
  TYPE game_state_t IS (S_OFF, S_READY, S_PLAYING, S_GAME_OVER);
  -- Scoring and rules
  CONSTANT PTS_NORMAL        : INTEGER := 1;
  CONSTANT PTS_HARD          : INTEGER := 2;
  CONSTANT PTS_STREAK        : INTEGER := 3;
  CONSTANT LIVES_START       : INTEGER := 3;
  CONSTANT ROUND_SECONDS     : INTEGER := 60;   -- default, may become 45
  CONSTANT STREAK_WINDOW_S   : INTEGER := 10;   -- default, may be changed 
  CONSTANT SCORE_MAX         : INTEGER := 999;
  CONSTANT SCORE_W           : INTEGER := 10;   -- bits needed for 0..999
  -- IR burst (clocks at 50 MHz)
  CONSTANT BURST_HALF_PERIOD : INTEGER := 658;       -- ~38 kHz carrier
  CONSTANT BURST_WINDOW      : INTEGER := 7500000;   -- 150 ms
  CONSTANT BURST_COOLDOWN    : INTEGER := 20000000;  -- 400 ms
  -- Servo PWM (clocks at 50 MHz)
  CONSTANT SERVO_FRAME         : INTEGER := 1000000; -- 20 ms
  CONSTANT SERVO_PULSE_MINIMUM : INTEGER := 52000;   -- 1.04 ms
  CONSTANT SERVO_PULSE_MAXIMUM : INTEGER := 98000;   -- 1.96 ms

END PACKAGE game_pkg;