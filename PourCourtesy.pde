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

#define DEBUG 1

#define START_BUTTON_PIN 31
#define RESET_BUTTON_PIN 28

#define INVERT_BUTTONS 1


#define NUM_LEDS 128
#define LEDS_IN_PANEL 64
#define PANEL_1_PIN 6
#define PANEL_2_PIN 7
#define LEDS_IN_PANEL_ROW 8

#define PANEL_REFRESH_TIME 400
#define ATTENTION_REFRESH_TIME 10

#define TIME_IN_ROUND 30

#define POUR_DRINK_DELAY 10000

Servo servo;
const int SERVO_PIN = 5;
const int SERVO_DEGREES = 25;
const int SERVO_CENTER = 91;
const int SERVO_MIN_POS = SERVO_CENTER - SERVO_DEGREES;
const int SERVO_MAX_POS = SERVO_CENTER + SERVO_DEGREES;
int servoPosition = SERVO_CENTER;
int lastServoPosition = SERVO_CENTER;
int last_servo_move_millis = 0; // last time the servo moved
int SERVO_MOVE_TIMEOUT = 200; // amount of time to wait before moving the servo

//int servo_top_pause = 0;
//int SERVO_PAUSE_LENGTH = 50;

int GAME_STEP_TIMEOUT = 1000;
int last_game_step_millis = 0;

Adafruit_NeoPixel panel_1 = Adafruit_NeoPixel(NUM_LEDS, PANEL_1_PIN, NEO_GRB + NEO_KHZ800);
Adafruit_NeoPixel panel_2 = Adafruit_NeoPixel(NUM_LEDS, PANEL_2_PIN, NEO_GRB + NEO_KHZ800);

const uint32_t pixelOn = panel_1.Color(63, 31, 00);
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
  Serial.begin(115200);
  initHeadsets();

  servo.attach(SERVO_PIN);

  pinMode(START_BUTTON_PIN, INPUT);
  pinMode(RESET_BUTTON_PIN, INPUT);

  last_servo_move_millis = millis();
  last_game_step_millis = millis();

  // setup and clear the panels
  panel_1.begin();
  panel_2.begin();
  showPanels();

  Serial.println("Starting: Pour Courtesy");
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
      Serial.println("Timeout waiting for headset server");
    }
    attentionPlayer_1 = 0;
    attentionPlayer_2 = 0;
  }

  if (gameState == STOPPED)
  {
#if !DEBUG
    draw_eyes();
#endif
    // Display the current scores for the players, just for fun.
    //updateDisplay(-1, -1, toBarValue(attentionPlayer_1), toBarValue(attentionPlayer_2));
    //showPanels();
    refreshDisplay();

    if (startButtonState())
    {
      // wait until the button is released
      while (startButtonState());
      
      // Now we start the game!
      countdown = TIME_IN_ROUND;
      gameState = INGAME;
      Serial.println("Starting Game!");
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
      Serial.print("Countdown: ");
      Serial.println(countdown, DEC);
    }

    if (countdown <= 0)
    {
      // check who won, and go crazy!
      // TODO: score check
      // TODO: if score == 0, and microwins are equal, select random winner!
      // TODO: pour to the "loser"
      Serial.println("Ran out of time!");
      gameState = STOPPED;
      resetGame();
      return;
    }

    // check for Pause
    if (startButtonState())
    {
      // wait until the button is released
      while (startButtonState());
      
      Serial.println("Pausing game");
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

    // TODO: tally micro wins, periodically, and control servo
  }
  else if (gameState == PAUSED)
  {
    // Just keep displaying the current attention values.
    // TODO: display, check for start/reset
    // check for Pause
    if (startButtonState())
    {
      // wait until the button is released
      while (startButtonState());
      
      Serial.println("Resuming game");
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

  



  
  

/*
  if (!readHeadsets())
  {
    Serial.println("Timeout waiting for headset server");
    score_player_1 = 0;
    score_player_2 = 0;
    attention_player_1 = 0;
    attention_player_2 = 0;
  }

  if (game_mode == GAME_MODE_WAIT)
  {
    draw_eyes();
    updateDisplay(-1, -1, toBarValue(attentionPlayer_1), toBarValue(attentionPlayer_2));
    showPanels();
  }
  else
  {
    int current_millis = millis();

    if ((current_millis - last_game_step_millis) > GAME_STEP_TIMEOUT)
    {
      doPanelUpdate = true;
      last_game_step_millis = current_millis;
      countdown--;

      if (countdown <= 0)
      {
        reset_game();
      }
    }

    if ((current_millis - last_servo_move_millis) > SERVO_MOVE_TIMEOUT)
    {
      // move the spout ...
      if (attention_player_1 > attention_player_2)
      {
        servoPosition += 1;
      }
      else if (attention_player_2 > attention_player_1)
      {
        servoPosition -= 1;
      }

      if (servoPosition >= SERVO_MAX_POS || servoPosition <= SERVO_MIN_POS)
      {
        end_game_state();
      }

      if (servoPosition != lastServoPosition)
      {
        Serial.print("Moving servo to ");
        Serial.println(servoPosition);
        servo.write(servoPosition);
      }

      lastServoPosition = servoPosition;
      last_servo_move_millis = current_millis;
    }
  }

  if (doPanelUpdate)
  {
    Serial.print("Attention P1:");
    Serial.println(attention_player_1);
    Serial.print("Attention P2:");
    Serial.println(attention_player_2);

    updateDisplay(countdown / 10, countdown % 10, toBarValue(attentionPlayer_1), toBarValue(attentionPlayer_2));
    showPanels();
  }
*/
}


void end_game_state()
{
  Serial.println("TODO: End game, dispense drink");
  delay(POUR_DRINK_DELAY);
  Serial.println("Drink dispensed");
  resetGame();
}

void resetGame()
{
  // Resets the game.
  // Resets the state machine, servo, display, etc.

  Serial.println("Resetting game");

  int current_millis = millis();
  last_game_step_millis = current_millis;

  // reset countdown
  countdown = TIME_IN_ROUND;

  // reset attention values
  attentionPlayer_1 = 0;
  attentionPlayer_2 = 0;

  servoPosition = SERVO_CENTER;

  Serial.print("Moving servo to ");
  Serial.println(servoPosition);
  servo.write(servoPosition);
  delay(100);

  //updateDisplay(countdown / 10, countdown % 10, toBarValue(attentionPlayer_1), toBarValue(attentionPlayer_2));
  Serial.println("Reset finished");
}

int led_digits[10][LEDS_IN_PANEL] =
{
  {
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 0, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 0, 1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
  },
  {
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 0, 0, 0,
    0, 0, 0, 0, 1, 0, 0, 0,
    0, 0, 0, 0, 1, 0, 0, 0,
    0, 0, 0, 0, 1, 0, 0, 0,
    0, 0, 0, 0, 1, 0, 0, 0,
    0, 0, 0, 1, 1, 1, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
  },
  {
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 0, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 0, 0, 0, 1, 0, 0,
    0, 0, 0, 1, 1, 0, 0, 0,
    0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 1, 1, 1, 1, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
  },
  {
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 1, 1, 1, 1, 0, 0,
    0, 0, 0, 0, 0, 1, 0, 0,
    0, 0, 0, 0, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 1, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 0, 1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
  },
  {
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 1, 1, 1, 1, 0, 0,
    0, 0, 0, 0, 0, 1, 0, 0,
    0, 0, 0, 0, 0, 1, 0, 0,
    0, 0, 0, 0, 0, 1, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
  },
  {
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 1, 1, 1, 1, 0, 0,
    0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 1, 1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 1, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 0, 1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
  },
  {
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 0, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 1, 1, 1, 0, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 0, 1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
  },
  {
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 1, 1, 1, 1, 0, 0,
    0, 0, 0, 0, 0, 1, 0, 0,
    0, 0, 0, 0, 0, 1, 0, 0,
    0, 0, 0, 0, 1, 0, 0, 0,
    0, 0, 0, 1, 0, 0, 0, 0,
    0, 0, 0, 1, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
  },
  {
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 0, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 0, 1, 1, 0, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 0, 1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
  },
  {
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 0, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 0, 1, 1, 1, 0, 0,
    0, 0, 0, 0, 0, 1, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 0, 1, 1, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
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
    Serial.print("Score: ");
    Serial.println(score, DEC);
    Serial.print("micro wins: ");
    Serial.print(microWinsPlayer_1, DEC);
    Serial.print(' ');
    Serial.println(microWinsPlayer_2, DEC);
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
    panel_1.setPixelColor(i, pixelOn);
  }

  // player two score
  for (int i = 0; i < bar2; i++)
  {
    panel_2.setPixelColor(i, pixelOn);
  }
  
  showPanels();
}
#else
void updateDisplay(int firstDigit, int secondDigit, int bar1, int bar2)
{
  int *leds_on;

  if (firstDigit != -1)
  {
    // digit on first panel
    leds_on = &led_digits[firstDigit][0];
    for (int i = 0; i < LEDS_IN_PANEL; i++)
    {
      if (leds_on[i] == 1)
      {
        panel_1.setPixelColor(i + 1, pixelOn);
      }
      else
      {
        panel_1.setPixelColor(i + 1, pixelOff);
      }
    }

    // total hack
    panel_1.setPixelColor(0, pixelOff);
  }

  // player one score
  for (int i = 1; i <= bar1; i++)
  {
    panel_1.setPixelColor((LEDS_IN_PANEL_ROW - i) * LEDS_IN_PANEL_ROW, pixelOn);
    panel_1.setPixelColor((LEDS_IN_PANEL_ROW - i) * LEDS_IN_PANEL_ROW + 1, pixelOn);
  }

  if (secondDigit != -1)
  {
    // digit on second panel
    leds_on = &led_digits[secondDigit][0];
    for (int i = 0; i < LEDS_IN_PANEL; i++)
    {
      if (leds_on[i] == 1)
      {
        panel_2.setPixelColor(i - 1, pixelOn);
      }
      else
      {
        panel_2.setPixelColor(i - 1, pixelOff);
      }
    }
  }

  // player two score
  for (int i = 1; i <= bar2; i++)
  {
    panel_2.setPixelColor((LEDS_IN_PANEL_ROW - i) * LEDS_IN_PANEL_ROW + (LEDS_IN_PANEL_ROW - 2), pixelOn);
    panel_2.setPixelColor((LEDS_IN_PANEL_ROW - i) * LEDS_IN_PANEL_ROW + (LEDS_IN_PANEL_ROW - 1), pixelOn);
  }
}
#endif

void draw_eyes()
{
  int eye_pattern[LEDS_IN_PANEL] =
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

