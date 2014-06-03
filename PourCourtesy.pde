/*
|| @author         Paul Shields <shields.paul@gmail.com>
|| @url            http://site3.ca/
|| @contribution   Brett Hagman <bhagman@wiring.org.co>
|| @contribution   Shaun Fryer <sfryer@sourcery.ca>
|| @contribution   Marc Reeve-Newson <marc.reevenewson@gmail.com>
|| @contribution   Kate Murphy <hello@kate.io>
||
|| @description
|| | A drink-pouring game which uses "mind-control" to pour drinks for one
|| | of two players.
|| |
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

int QUALITY_THRESHOLD = 60;
double ROUND_TOTAL_TIME = 5 * 1000;

Servo servo;
const int SERVO_PIN = 9;
const int SERVO_MIN_POS = 90 - 15;
const int SERVO_MAX_POS = 90 + 15;
int servo_pos = SERVO_MIN_POS;
int servo_last_pos = SERVO_MIN_POS;
boolean servo_direction;
int last_servo_move_millis = 0; // last time the servo moved
int SERVO_MOVE_TIMEOUT = 500; // amount of time to wait before moving the servo

// when the round started
int round_start_millis = 0;

const int ledPin = WLED; // handy because it's on the board.
int ledState = LOW;

Brain brainA(Serial1);
//Brain brainB(Serial1);

void setup() {
  pinMode(ledPin, OUTPUT);

  // Start the hardware serial.
  Serial.begin(9600);
  servo.attach(SERVO_PIN);
  
  last_servo_move_millis = millis();
  round_start_millis = millis();

  Serial.println("Starting: Pour Courtesy");
}

void loop() {  
  int qualityA = -1;
  int qualityB = -1;
  int attentionA = 0;
  int attentionB = 0;

  if (brainA.update()) {
    Serial.print("Packet from A: ");
    Serial.println(brainA.readCSV());
    Serial.println(brainA.readErrors());
    
    qualityA = brainA.readSignalQuality();
    
    if (qualityA < QUALITY_THRESHOLD) {
      attentionA = brainA.readAttention();
    }
  }

//  if (brainB.update()) {
//    Serial.print("B: ");
//    Serial.println(brainB.readErrors());
//    Serial.println(brainB.readCSV());
//    qualityB = brainB.readSignalQuality();
//    
//    if (qualityB < QUALITY_THRESHOLD) {
//      attentionB = brainB.readAttention();
//    }
//  }

  // do this only if both headsets are linked? ...

//  if (attentionA > attentionB) {
//    // move the spout ...
//    pos += 5;
//  } else if (attentionB > attentionA) {
//    // move the spout ...
//    pos -= 5;
//  }

  int current_millis = millis();
  
  if ((current_millis - round_start_millis) > ROUND_TOTAL_TIME) {
    Serial.println("=== Round over");
    round_start_millis = current_millis;
  }
  
  // sweep the servo back and forth around 90°
  if ((current_millis - last_servo_move_millis) > SERVO_MOVE_TIMEOUT) {
    last_servo_move_millis = current_millis;
    
    if (servo_pos >= SERVO_MAX_POS || servo_pos <= SERVO_MIN_POS) {
      servo_direction = !servo_direction;
    }
    
    if (servo_direction) {
      servo_pos += 1;
    } else {
      servo_pos -= 1;
    }
    
    Serial.print("Moving servo to ");
    Serial.println(servo_pos);
    
    servo.write(servo_pos);
  }
}
