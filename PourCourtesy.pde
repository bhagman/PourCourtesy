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

double QUALITY_THRESHOLD = 60;
double ROUND_TOTAL_TIME = 60000;

int SERVO_PIN = 9;
const int ledPin = WLED; // handy because it's on the board.

Servo servo;
boolean direction;

// variable to store the servo position
int pos = 0;

// variable to store the servo position
int opos = 90;

// time spend in round
int round_time = 0;

int last_servo_move_millis = 0;

int SERVO_MOVE_TIMEOUT = 100;

int ledState = LOW;

Brain brainA(Serial1);
//Brain brainB(Serial1);

void setup() {
  pinMode(ledPin, OUTPUT);

  // Start the hardware serial.
  Serial.begin(9600);
  servo.attach(SERVO_PIN);

  Serial.println("Starting: Pour Courtesy");
}

void loop() {  
  int qualityA = -1;
  int qualityB = -1;
  int attentionA = 0;
  int attentionB = 0;

  if (brainA.update()) {
    Serial.print("A: ");
    Serial.println(brainA.readErrors());
    Serial.println(brainA.readCSV());
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
  
  if (opos != pos) {
    Serial.print("pos =");
    Serial.println(pos);
  }

  opos = pos;
  
  int current_millis = millis();
  
  // round is over if we tilt completely to a side or run out of time
  if (round_time > ROUND_TOTAL_TIME) {
    Serial.println("round over");
    pos = 90;
    round_time = 0;
  }
  
  round_time++;
  
  if ((current_millis - last_servo_move_millis) > SERVO_MOVE_TIMEOUT) {
    last_servo_move_millis = current_millis;
    
    // reset the servo if needed
    if (pos >= 30 || pos <= 0) {
      direction = !direction;
    }
    
    if (direction) {
      pos++;
    } else {
      pos--;
    }
    
    servo.write(pos);
  }
}
