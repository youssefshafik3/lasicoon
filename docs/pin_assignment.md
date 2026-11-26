# DE10-Lite Pin Assignment & Hardware Interface Map

- **Board:** Terasic DE10-Lite (`10M50DAF484C7G`)
- **I/O Standard:** `3.3-V LVTTL` on all user pins
- **Base Assignments:** Import the Terasic DE10-Lite default `.qsf` pin assignments in Quartus (`Assignments -> Import Assignments`) for `MAX10_CLK1_50`, `KEY`, `SW`, `LEDR`, `HEX0..HEX5`, and `GPIO[35:0]`.

## 1. On-Board DE10-Lite I/O

| Top-Level Port | Direction | Function | Notes |
| :--- | :--- | :--- | :--- |
| `MAX10_CLK1_50` | Input | 50 MHz system clock | Drives all synchronous logic |
| `KEY[0]` | Input | `START` button | Active-low on board; 10 ms debounced |
| `KEY[1]` | Input | `RESET SCORE` button | Active-low on board; 10 ms debounced |
| `SW[0]` | Input | Master Power (`sw_on`) | `'0'` = `S_OFF`, `'1'` = `S_READY` / `S_PLAYING` |
| `SW[1]` | Input | Mode Select (`sw_mode`) | `'0'` = Mode 1 (Timed), `'1'` = Mode 2 (Targets shoot back) |
| `SW[2]` | Input | Display Select (`show_high`) | `'0'` = Current score on `HEX3..1`, `'1'` = High score |
| `LEDR[2:0]` | Output | Lives remaining (hearts) | Lit = life remaining (Mode 2 only) |
| `LEDR[3]` | Output | Night mode active | `'1'` when LDR darkness threshold is active |
| `LEDR[4]` | Output | Hit indicator | Stretched ~200 ms pulse on `hit_p` |
| `LEDR[5]` | Output | Miss indicator | Stretched ~200 ms pulse on `miss_p` |
| `LEDR[6]` | Output | Streak bonus indicator | Stretched ~200 ms pulse on `streak_p` |
| `HEX5..HEX4` | Output | Round countdown (`time_left`) | Active-low; shown in Mode 1, blank in Mode 2 |
| `HEX3..HEX1` | Output | `score` or `high_score` (`000`–`999`) | Active-low; blinks in `S_GAME_OVER` |
| `HEX0` | Output | Active mode number (`1` or `2`) | Active-low; blank in `S_OFF` |

## 2. External GPIO Header Mapping (`GPIO[35:0]`)

| GPIO Index | Top-Level Signal | Direction | External Hardware & Level-Shifting Notes |
| :--- | :--- | :--- | :--- |
| `GPIO[0]` | `PIN_UART_RX` | Input | Arduino Uno `D3` (`SoftwareSerial` TX, 9600 baud) via `1 kΩ / 2 kΩ` voltage divider (`3.33V`) |
| `GPIO[1]` | `PIN_FIRE_BTN_N` | Input | External arcade `FIRE` push button wired active-low to `GND` (enable internal weak pull-up or external `10 kΩ` to `3.3V`) |
| `GPIO[2]` | `PIN_IR_OUT` | Output | `1 kΩ` base resistor -> `2N2222` transistor switching 940 nm IR emitter LED on `5V` |
| `GPIO[3]` | `PIN_LASER_SIGHT` | Output | `1 kΩ` base resistor -> `2N2222` transistor switching 5V red laser sight module |
| `GPIO[4]` | `PIN_PAN_PWM` | Output | Turret horizontal pan SG90 servo signal wire (`50 Hz` PWM, powered from `5V` Rail A) |
| `GPIO[5]` | `PIN_TILT_PWM` | Output | Turret vertical tilt SG90 servo signal wire (`50 Hz` PWM, powered from `5V` Rail A) |
| `GPIO[6]` | `PIN_BUZZER` | Output | Passive piezo buzzer `+` pin (other leg to common `GND`) |
| `GPIO[10]` | `rx_sync(0)` | Input | Target 0 `TSOP1738` Pin 3 (`OUT`) + `10 kΩ` external pull-up to DE10-Lite `3.3V` |
| `GPIO[11]` | `rx_sync(1)` | Input | Target 1 `TSOP1738` Pin 3 (`OUT`) + `10 kΩ` external pull-up to DE10-Lite `3.3V` |
| `GPIO[12]` | `rx_sync(2)` | Input | Target 2 `TSOP1738` Pin 3 (`OUT`) + `10 kΩ` external pull-up to DE10-Lite `3.3V` |
| `GPIO[13]` | `rx_sync(3)` | Input | Target 3 `TSOP1738` Pin 3 (`OUT`) + `10 kΩ` external pull-up to DE10-Lite `3.3V` |
| `GPIO[14]` | `rx_sync(4)` | Input | Target 4 `TSOP1738` Pin 3 (`OUT`) + `10 kΩ` external pull-up to DE10-Lite `3.3V` |
| `GPIO[15]` | `target_pwm(0)` | Output | Target 0 SG90 rotator servo signal (`50 Hz` PWM, powered from `5V` Rail B) |
| `GPIO[16]` | `target_pwm(1)` | Output | Target 1 SG90 rotator servo signal (`50 Hz` PWM, powered from `5V` Rail B) |
| `GPIO[17]` | `target_pwm(2)` | Output | Target 2 SG90 rotator servo signal (`50 Hz` PWM, powered from `5V` Rail B) |
| `GPIO[18]` | `target_pwm(3)` | Output | Target 3 SG90 rotator servo signal (`50 Hz` PWM, powered from `5V` Rail B) |
| `GPIO[19]` | `target_pwm(4)` | Output | Target 4 SG90 rotator servo signal (`50 Hz` PWM, powered from `5V` Rail B) |

## 3. Power & Ground Rules
- **Common Ground:** DE10-Lite `GND`, Arduino Uno `GND`, `5V/2A` Adapter A `GND`, and `5V/2A` Adapter B `GND` must all share one common ground bus.
- **Isolated `5V` Rails:** Never tie Adapter A `+5V` (turret servos, optics, receivers) and Adapter B `+5V` (5 target servos) together.