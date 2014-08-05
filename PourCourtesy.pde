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
#include <Brain.h>
#include <Adafruit_NeoPixel.h>

#define BUTTON_PIN 15

#define NUM_LEDS 128
#define LEDS_IN_PANEL 64
#define PANEL_1_PIN 6
#define PANEL_2_PIN 7
#define LEDS_IN_PANEL_ROW 8

#define TIME_IN_ROUND 30

#define POUR_DRINK_DELAY 10000

Servo servo;
const int SERVO_PIN = 9;
const int SERVER_DEGREES = 25;
const int SERVO_CENTER = 91;
const int SERVO_MIN_POS = SERVO_CENTER - SERVER_DEGREES;
const int SERVO_MAX_POS = SERVO_CENTER + SERVER_DEGREES;
int servo_pos = SERVO_CENTER;
int servo_last_pos = SERVO_CENTER;
boolean servo_direction;
int last_servo_move_millis = 0; // last time the servo moved
int SERVO_MOVE_TIMEOUT = 200; // amount of time to wait before moving the servo

int servo_top_pause = 0;
int SERVO_PAUSE_LENGTH = 50;

int GAME_STEP_TIMEOUT = 1000;
int last_game_step_millis = 0;

int QUALITY_THRESHOLD = 60;
Brain brainA(Serial);
Brain brainB(Serial1);

Adafruit_NeoPixel panel_1 = Adafruit_NeoPixel(NUM_LEDS, PANEL_1_PIN, NEO_GRB + NEO_KHZ800);
Adafruit_NeoPixel panel_2 = Adafruit_NeoPixel(NUM_LEDS, PANEL_2_PIN, NEO_GRB + NEO_KHZ800);

uint32_t pixelOn = panel_1.Color(63, 31, 00);
uint32_t pixelOff = panel_1.Color(0, 0, 0);

int countdown = TIME_IN_ROUND;

int qualityA = 200;
int qualityB = 200;
int attention_player_1 = 0;
int attention_player_2 = 0;
int score_player_1 = 0;
int score_player_2 = 0;

// should we draw to the panel this loop?
boolean doPanelUpdate;

const int GAME_MODE_WAIT = 0;
const int GAME_MODE_IN_ROUND = 1;

int game_mode = GAME_MODE_IN_ROUND;

void setup() {  
  pinMode(SERVO_PIN, OUTPUT);
  servo.attach(SERVO_PIN);
  
  pinMode(BUTTON_PIN, INPUT);
  
  last_servo_move_millis = millis();
  last_game_step_millis = millis();
  
  // setup and clear the panels
  pinMode(PANEL_1_PIN, OUTPUT);
  pinMode(PANEL_2_PIN, OUTPUT);
  panel_1.begin();
  panel_2.begin();
  show_panels();

  Serial.println("Starting: Pour Courtesy");
  reset_game();
}

void loop() {
  doPanelUpdate = false;
  
  int buttonState = digitalRead(BUTTON_PIN);
  if (buttonState == GAME_MODE_IN_ROUND) {
    if (game_mode == GAME_MODE_WAIT) {
      game_mode = GAME_MODE_IN_ROUND;
      reset_game();
    } else {
      game_mode = GAME_MODE_WAIT;
    }
  }
  
  try_reading_headsets();
  
  if (game_mode == GAME_MODE_WAIT) {
    draw_eyes();
    update_display(-1, -1, score_player_1, score_player_2);
    show_panels();
  } else {
    int current_millis = millis();
    
    if ((current_millis - last_game_step_millis) > GAME_STEP_TIMEOUT) {
      doPanelUpdate = true;
      last_game_step_millis = current_millis;
      countdown--;
      
      if (countdown <= 0) {
        reset_game();
      }
    }
    
    if ((current_millis - last_servo_move_millis) > SERVO_MOVE_TIMEOUT) {
      // move the spout ...
      if (attention_player_1 > attention_player_2) {
        servo_pos += 1;
      } else if (attention_player_2 > attention_player_1) {
        servo_pos -= 1;
      }
      
      if (servo_pos >= SERVO_MAX_POS || servo_pos <= SERVO_MIN_POS) {
        end_game_state();
      }
      
      if (servo_pos != servo_last_pos) {
        Serial.print("Moving servo to ");
        Serial.println(servo_pos);
        //servo.write(servo_pos);
      }
      
      servo_last_pos = servo_pos;
      last_servo_move_millis = current_millis;
    }
  }
  
  if (doPanelUpdate) {
    Serial.print("Attention P1:");
    Serial.println(attention_player_1);
    Serial.print("Attention P2:");
    Serial.println(attention_player_2);
    
    update_display(countdown / 10, countdown % 10, score_player_1, score_player_2);
    show_panels();
  }
}

void try_reading_headsets() {
  if (brainA.update()) {
    doPanelUpdate = true;
    Serial.print("Packet from A: ");
    Serial.println(brainA.readCSV());
    qualityA = brainA.readSignalQuality();
    
    if (qualityA < QUALITY_THRESHOLD) {
      attention_player_1 = brainA.readAttention();
      score_player_1 = int(8 * (float(attention_player_1) / 100));
    } else {
      attention_player_1 = 0;
      score_player_1 = 0;
    }
  }
  
  if (brainB.update()) {
    doPanelUpdate = true;
    Serial.print("Packet from B: ");
    Serial.println(brainB.readCSV());
    
    qualityB = brainB.readSignalQuality();
    if (qualityB < QUALITY_THRESHOLD) {
      attention_player_2 = brainB.readAttention();
      score_player_2 = int(8 * (float(attention_player_2) / 100));
    } else {
      attention_player_2 = 0;
      score_player_2 = 0;
    }
  }
}

void end_game_state() {
  Serial.println("End game, dispensing drink");
  delay(POUR_DRINK_DELAY);
  Serial.println("Drink dispensed");
  reset_game();
}

void reset_game() {
  Serial.println("Reseting game");
  int current_millis = millis();
  last_game_step_millis = current_millis;
  
  // reset countdown
  countdown = TIME_IN_ROUND;
  
  // reset attention values
  attention_player_1 = 0;
  attention_player_2 = 0;
  
  servo_pos = SERVO_CENTER;
  Serial.print("Moving servo to ");
  Serial.println(servo_pos);
  //servo.write(servo_pos);
  delay(100);
  
  update_display(countdown / 10, countdown % 10, score_player_1, score_player_2);
  Serial.println("Reset finished");
}

int led_digits[10][LEDS_IN_PANEL] = {
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

void update_display(int first_digit, int second_digit, int score_player_1, int score_player_2) {
  int *leds_on;
  
  if (first_digit != -1) {
      // digit on first panel
    leds_on = &led_digits[first_digit][0];
    for (int i = 0; i < LEDS_IN_PANEL; i++) {
      if (leds_on[i] == 1) {
        panel_1.setPixelColor(i + 1, pixelOn);
      } else {
        panel_1.setPixelColor(i + 1, pixelOff);
      }
    }
    
    // total hack
    panel_1.setPixelColor(0, pixelOff);
  }
  
  // player one score
  for (int i = 1; i <= score_player_1; i++) {
    panel_1.setPixelColor((LEDS_IN_PANEL_ROW - i) * LEDS_IN_PANEL_ROW, pixelOn);
    panel_1.setPixelColor((LEDS_IN_PANEL_ROW - i) * LEDS_IN_PANEL_ROW + 1, pixelOn);
  }
  
  if (first_digit != -1) {
    // digit on second panel
    leds_on = &led_digits[second_digit][0];
    for (int i = 0; i < LEDS_IN_PANEL; i++) {
      if (leds_on[i] == 1) {
        panel_2.setPixelColor(i - 1, pixelOn);
      } else {
        panel_2.setPixelColor(i - 1, pixelOff);
      }
    }
  }
  
  // player two score
  for (int i = 1; i <= score_player_2; i++) {
    panel_2.setPixelColor((LEDS_IN_PANEL_ROW - i) * LEDS_IN_PANEL_ROW + (LEDS_IN_PANEL_ROW - 2), pixelOn);
    panel_2.setPixelColor((LEDS_IN_PANEL_ROW - i) * LEDS_IN_PANEL_ROW + (LEDS_IN_PANEL_ROW - 1), pixelOn);
  }
}

void draw_eyes() {
  int eye_pattern[LEDS_IN_PANEL] = {
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 1, 1, 0, 0, 0,
    0, 0, 1, 0, 0, 1, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
  };
  
  for (int i = 0; i < LEDS_IN_PANEL; i++) {
    if (eye_pattern[i] == 1) {
      panel_1.setPixelColor(i, pixelOn);
    } else {
      panel_1.setPixelColor(i, pixelOff);
    }
  }
  
  for (int i = 0; i < LEDS_IN_PANEL; i++) {
    if (eye_pattern[i] == 1) {
      panel_2.setPixelColor(i, pixelOn);
    } else {
      panel_2.setPixelColor(i, pixelOff);
    }
  }
  
  show_panels();
}

void show_panels() {
  panel_1.show();
  panel_2.show();
}
