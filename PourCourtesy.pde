/*
|| @author         Kate Murphy <hello@kate.io>
|| @url            http://site3.ca/
|| @contribution   Marc Reeve-Newson <marc.reevenewson@gmail.com>
|| @contribution   Brett Hagman <bhagman@wiring.org.co>
|| @contribution   Paul Shields <shields.paul@gmail.com>
||
|| @description
|| | A drink-pouring game which uses "mind-control" to pour drinks for one
|| | of two players.
|| |
|| | Wiring/Arduino Sketch
|| #
||
|| @license Please see License.txt.
||
|| @name PourCourtesy.pde
|| @type Sketch
|| @target Wiring S
*/

#include <Servo.h>
#include <Adafruit_NeoPixel.h>

#define DEBUG 0

#define SERVO_PIN 5
#define PANEL_1_PIN 6
#define PANEL_2_PIN 7
#define START_BUTTON_PIN 8
#define RESET_BUTTON_PIN 9

#define INVERT_BUTTONS 1


//#define NUM_LEDS 128
#define LEDS_IN_PANEL 64
#define LEDS_IN_PANEL_ROW 8

#define PANEL_REFRESH_TIME 1000
#define ATTENTION_REFRESH_TIME 1000
#define POUR_DRINK_TIME 5000

#define TIME_IN_ROUND 45

#define serialLog Serial
#define serialLogSpeed 115200

#define SERVO_DEGREES 14
#define SERVO_CENTER 84
#define SERVO_MIN_POS (SERVO_CENTER - SERVO_DEGREES)
#define SERVO_MAX_POS (SERVO_CENTER + SERVO_DEGREES)

#define PLAYER_1_WIN_SERVO_POS SERVO_MAX_POS
#define PLAYER_2_WIN_SERVO_POS SERVO_MIN_POS

#define PLAYER_1_WIN_POUR 109
#define PLAYER_2_WIN_POUR 59

Servo servo;
int servoPosition = SERVO_CENTER;
int lastServoPosition = SERVO_CENTER;


Adafruit_NeoPixel panel_1 = Adafruit_NeoPixel(LEDS_IN_PANEL, PANEL_1_PIN, NEO_GRB + NEO_KHZ800);
Adafruit_NeoPixel panel_2 = Adafruit_NeoPixel(LEDS_IN_PANEL, PANEL_2_PIN, NEO_GRB + NEO_KHZ800);

const uint32_t pixelOn = panel_1.Color(63, 31, 0);
const uint32_t pixelOnScore = panel_1.Color(70, 0, 70);
const uint32_t pixelOff = panel_1.Color(0, 0, 0);

int countdown = TIME_IN_ROUND;

int attentionPlayer_1 = 0;
int attentionPlayer_2 = 0;

int score = 0;  // +ve = player 1, -ve = player 2
int microWinsPlayer_1 = 0;
int microWinsPlayer_2 = 0;

uint32_t lastPanelUpdate_millis;
uint32_t lastAttentionReading_millis;

// ATTRACT is for a future attract mode... :)
enum { INGAME, PAUSED, STOPPED, ATTRACT } gameState;

void setup()
{
  serialLog.begin(serialLogSpeed);
  initHeadsets();

  servo.attach(SERVO_PIN);

  pinMode(START_BUTTON_PIN, INPUT);
  digitalWrite(START_BUTTON_PIN, HIGH);
  pinMode(RESET_BUTTON_PIN, INPUT);
  digitalWrite(RESET_BUTTON_PIN, HIGH);

  // setup and clear the panels
  panel_1.begin();
  panel_2.begin();
  showPanels();

  serialLog.println("Starting: Pour Courtesy");
  gameState = STOPPED;
  resetGame();
}

int startButtonState()
{
  return digitalRead(START_BUTTON_PIN) ^ INVERT_BUTTONS;
}

int resetButtonState()
{
  return digitalRead(RESET_BUTTON_PIN) ^ INVERT_BUTTONS;
}

int toBarValue(int attentionValue)
{
  return int(8 * (float(attentionValue) / 100));
}

void loop()
{
  if (!readHeadsets())
  {
    if (attentionPlayer_1 != 0 && attentionPlayer_2 != 0)
    {
      serialLog.println("Timeout waiting for headset server");
    }
    attentionPlayer_1 = 0;
    attentionPlayer_2 = 0;
  }

  refreshDisplay();

  if (gameState == STOPPED)
  {
#if !DEBUG
//    draw_eyes();
#endif

    if (startButtonState())
    {
      // wait until the button is released
      while (startButtonState());

      // Now we start the game!
      countdown = TIME_IN_ROUND;
      gameState = INGAME;
      lastAttentionReading_millis = millis();
      serialLog.println("Starting Game!");
    }
  }
  else if (gameState == INGAME)
  {
    // Read attention values periodically, timer countdown,
    // and check if a player has won.

    static uint32_t lastTimeCheck = millis();

    if ((millis() - lastTimeCheck) > 1000)
    {
      countdown--;
      lastTimeCheck = millis();
      serialLog.print("Countdown: ");
      serialLog.println(countdown, DEC);
    }

    if (countdown <= 0)
    {
      serialLog.println("Ran out of time!");
      gameState = STOPPED;
      updateDisplay(0, 0, toBarValue(attentionPlayer_1), toBarValue(attentionPlayer_2));
      showPanels();
      endGame();
      return;
    }

    // check for Pause
    if (startButtonState())
    {
      // wait until the button is released
      while (startButtonState());

      serialLog.println("Pausing game");
      gameState = PAUSED;
      return;  // bail out
    }
    else if (resetButtonState())
    {
      // wait until the button is released
      while (resetButtonState());

      gameState = STOPPED;
      resetGame();
      return;  // bail out
    }

    // Tally micro wins, periodically, and control servo
    if ((millis() - lastAttentionReading_millis) > ATTENTION_REFRESH_TIME)
    {
      // move the spout ...
      if (attentionPlayer_1 > attentionPlayer_2)
      {
        servoPosition += 1;
        microWinsPlayer_1 += 1;
      }
      else if (attentionPlayer_2 > attentionPlayer_1)
      {
        servoPosition -= 1;
        microWinsPlayer_2 += 1;
      }

      if (servoPosition >= PLAYER_1_WIN_SERVO_POS || servoPosition <= PLAYER_2_WIN_SERVO_POS)
      {
        serialLog.println("WIN!");
        gameState = STOPPED;
        endGame();
        return;
      }

      if (servoPosition != lastServoPosition)
      {
        serialLog.print("Moving servo to ");
        serialLog.println(servoPosition);
        servo.write(servoPosition);
      }

      lastServoPosition = servoPosition;
      lastAttentionReading_millis = millis();
    }
  }
  else if (gameState == PAUSED)
  {
    // Just keep displaying the current attention values.

    if (startButtonState())
    {
      // wait until the button is released
      while (startButtonState());

      serialLog.println("Resuming game");
      gameState = INGAME;
      return;  // bail out
    }
    else if (resetButtonState())
    {
      // wait until the button is released
      while (resetButtonState());

      gameState = STOPPED;
      resetGame();
      return;  // bail out
    }
  }
  else if (gameState == ATTRACT)
  {
    // oooh what can we do here?
    gameState = STOPPED;  // for now, just bail out if we accidentally get here.
    return;
  }
}


void endGame()
{
  // check who won, and go crazy!
  // if score == 0, and microwins are equal, select random winner!

  int winner = 0;

  serialLog.println("End game, dispense drink");
  if (servoPosition > SERVO_CENTER)
  {
    // Player 1 wins - tip over +ve
    winner = 1;
  }
  else if (servoPosition < SERVO_CENTER)
  {
    // Player 2 wins - tip over -ve
    winner = -1;
  }
  else
  {
    // tie
    if (microWinsPlayer_1 > microWinsPlayer_2)
    {
      // Player 1 wins - tip over +ve
      winner = 1;
    }
    else if (microWinsPlayer_2 > microWinsPlayer_1)
    {
      // Player 2 wins - tip over -ve
      winner = -1;
    }
    else
    {
      // TIE AGAIN! - SCHMEH! Random time!
      if (random(0, 100) > 50)
      {
        // Player 1 wins - tip over +ve
        winner = 1;
      }
      else
      {
        // Player 2 wins - tip over -ve
        winner = -1;
      }
    }
  }

  if (winner > 0)
  {
    serialLog.println("Player 1 wins!");
    servo.write(PLAYER_1_WIN_POUR);
  }
  else
  {
    serialLog.println("Player 2 wins!");
    servo.write(PLAYER_2_WIN_POUR);
  }

  delay(POUR_DRINK_TIME);
  serialLog.println("Drink dispensed");
  resetGame();
}

void resetGame()
{
  // Resets the game.
  // Resets the state machine, servo, display, etc.

  serialLog.println("Resetting game");

  // reset countdown
  countdown = TIME_IN_ROUND;

  updateDisplay(countdown / 10, countdown % 10, toBarValue(attentionPlayer_1), toBarValue(attentionPlayer_2));
  showPanels();

  servoPosition = SERVO_CENTER;
  lastServoPosition = SERVO_CENTER;

  serialLog.print("Moving servo to ");
  serialLog.println(servoPosition);
  servo.write(servoPosition);

  //updateDisplay(countdown / 10, countdown % 10, toBarValue(attentionPlayer_1), toBarValue(attentionPlayer_2));
  serialLog.println("Reset finished");
}

uint8_t led_digits[10][4*8] =
{
  {
    0, 0, 0, 0,
    0, 1, 1, 0,
    1, 0, 0, 1,
    1, 0, 0, 1,
    1, 0, 0, 1,
    1, 0, 0, 1,
    0, 1, 1, 0,
    0, 0, 0, 0,
  },
  {
    0, 0, 0, 0,
    0, 1, 1, 0,
    0, 0, 1, 0,
    0, 0, 1, 0,
    0, 0, 1, 0,
    0, 0, 1, 0,
    0, 1, 1, 1,
    0, 0, 0, 0,
  },
  {
    0, 0, 0, 0,
    0, 1, 1, 0,
    1, 0, 0, 1,
    0, 0, 0, 1,
    0, 1, 1, 0,
    1, 0, 0, 0,
    1, 1, 1, 1,
    0, 0, 0, 0,
  },
  {
    0, 0, 0, 0,
    1, 1, 1, 1,
    0, 0, 0, 1,
    0, 0, 1, 0,
    0, 0, 0, 1,
    1, 0, 0, 1,
    0, 1, 1, 0,
    0, 0, 0, 0,
  },
  {
    0, 0, 0, 0,
    1, 0, 0, 1,
    1, 0, 0, 1,
    1, 1, 1, 1,
    0, 0, 0, 1,
    0, 0, 0, 1,
    0, 0, 0, 1,
    0, 0, 0, 0,
  },
  {
    0, 0, 0, 0,
    1, 1, 1, 1,
    1, 0, 0, 0,
    1, 1, 1, 0,
    0, 0, 0, 1,
    1, 0, 0, 1,
    0, 1, 1, 0,
    0, 0, 0, 0,
  },
  {
    0, 0, 0, 0,
    0, 1, 1, 0,
    1, 0, 0, 1,
    1, 0, 0, 0,
    1, 1, 1, 0,
    1, 0, 0, 1,
    0, 1, 1, 0,
    0, 0, 0, 0,
  },
  {
    0, 0, 0, 0,
    1, 1, 1, 1,
    0, 0, 0, 1,
    0, 0, 0, 1,
    0, 0, 1, 0,
    0, 1, 0, 0,
    0, 1, 0, 0,
    0, 0, 0, 0,
  },
  {
    0, 0, 0, 0,
    0, 1, 1, 0,
    1, 0, 0, 1,
    1, 0, 0, 1,
    0, 1, 1, 0,
    1, 0, 0, 1,
    0, 1, 1, 0,
    0, 0, 0, 0,
  },
  {
    0, 0, 0, 0,
    0, 1, 1, 0,
    1, 0, 0, 1,
    0, 1, 1, 1,
    0, 0, 0, 1,
    1, 0, 0, 1,
    0, 1, 1, 0,
    0, 0, 0, 0,
  }
};

void refreshDisplay()
{
  if ((millis() - lastPanelUpdate_millis) > PANEL_REFRESH_TIME)
  {
    if (gameState == INGAME || gameState == PAUSED)
      updateDisplay(countdown / 10, countdown % 10, toBarValue(attentionPlayer_1), toBarValue(attentionPlayer_2));
    else
      updateDisplay(-1, -1, toBarValue(attentionPlayer_1), toBarValue(attentionPlayer_2));
    showPanels();
    lastPanelUpdate_millis = millis();
  }
}


#if DEBUG
void updateDisplay(int firstDigit, int secondDigit, int bar1, int bar2)
{
  if (gameState == INGAME)
  {
    serialLog.print("Score: ");
    serialLog.println(score, DEC);
    serialLog.print("micro wins: ");
    serialLog.print(microWinsPlayer_1, DEC);
    serialLog.print(' ');
    serialLog.println(microWinsPlayer_2, DEC);
  }

  // clear the bars
  for (int i = 0; i < 8; i++)
  {
    panel_1.setPixelColor(i, 0);
    panel_2.setPixelColor(i, 0);
  }

  // player one score
  for (int i = 0; i < bar1; i++)
  {
    panel_1.setPixelColor(i, pixelOnScore);
  }

  // player two score
  for (int i = 0; i < bar2; i++)
  {
    panel_2.setPixelColor(i, pixelOnScore);
  }

  showPanels();
}
#else
void updateDisplay(int firstDigit, int secondDigit, int bar1, int bar2)
{
  uint8_t *leds_on;

  if (firstDigit != -1)
  {
    // digit on first panel
    leds_on = &led_digits[firstDigit][0];
    for (int i = 0; i < 8; i++)  // 8 = number of rows
    {
      for (int j = 0; j < 4; j++)
      {
        if (leds_on[(i * 4) + j] == 1)
        {
          panel_1.setPixelColor((i * 8) + j + 4, pixelOn);
        }
        else
        {
          panel_1.setPixelColor((i * 8) + j + 4, pixelOff);
        }
      }
    }

    // total hack
    panel_1.setPixelColor(0, pixelOff);
  }

  // player one score
  for (int i = 1; i <= bar1; i++)
  {
    panel_1.setPixelColor((LEDS_IN_PANEL_ROW - i) * LEDS_IN_PANEL_ROW, pixelOnScore);
    panel_1.setPixelColor((LEDS_IN_PANEL_ROW - i) * LEDS_IN_PANEL_ROW + 1, pixelOnScore);
  }

  if (secondDigit != -1)
  {
    // digit on second panel
    leds_on = &led_digits[secondDigit][0];
    for (int i = 0; i < 8; i++)
    {
      for (int j = 0; j < 4; j++)
      {
        if (leds_on[(i * 4) + j] == 1)
        {
          panel_2.setPixelColor((i * 8) + j + 0, pixelOn);
        }
        else
        {
          panel_2.setPixelColor((i * 8) + j + 0, pixelOff);
        }
      }
    }
  }

  // player two score
  for (int i = 1; i <= bar2; i++)
  {
    panel_2.setPixelColor((LEDS_IN_PANEL_ROW - i) * LEDS_IN_PANEL_ROW + (LEDS_IN_PANEL_ROW - 2), pixelOnScore);
    panel_2.setPixelColor((LEDS_IN_PANEL_ROW - i) * LEDS_IN_PANEL_ROW + (LEDS_IN_PANEL_ROW - 1), pixelOnScore);
  }
}
#endif

void draw_eyes()
{
  uint8_t eye_pattern[LEDS_IN_PANEL] =
  {
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 0, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
  };

  for (int i = 0; i < LEDS_IN_PANEL; i++)
  {
    if (eye_pattern[i] == 1)
    {
      panel_1.setPixelColor(i, pixelOn);
    }
    else
    {
      panel_1.setPixelColor(i, pixelOff);
    }
  }

  for (int i = 0; i < LEDS_IN_PANEL; i++)
  {
    if (eye_pattern[i] == 1)
    {
      panel_2.setPixelColor(i, pixelOn);
    }
    else
    {
      panel_2.setPixelColor(i, pixelOff);
    }
  }

  showPanels();
}

void showPanels()
{
  // Detach the servo, to eliminate jitter.
  servo.detach();
  panel_1.show();
  panel_2.show();
  servo.attach(SERVO_PIN);
}

