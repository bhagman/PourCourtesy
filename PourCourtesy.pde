/*
|| @author         Paul Shields <shields.paul@gmail.com>
|| @url            http://site3.ca/
|| @contribution   Brett Hagman <bhagman@wiring.org.co>
|| @contribution   Shaun Fryer <sfryer@sourcery.ca>
|| @contribution   Marc Reeve-Newson <marc.reevenewson@gmail.com>
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
//#include <SBrain.h>

const int ledPin = WLED; // handy because it's on the board.
const int servoPin = 7;

Servo myservo;  // create servo object to control a servo
// a maximum of eight servo objects can be created
int pos = 90;    // variable to store the servo position
int opos = 90;    // variable to store the servo position
int timeout = 0 ;
int ledState = LOW;

// Set up the brain parser, pass it the hardware serial object you want to listen on.
// i think we want soft serial for two EEG units, but for now use the hardware serial..
//SoftwareSerial mySerialA(10, 11); // RX, TX
//SoftwareSerial mySerialB(12, 13); // RX, TX

Brain brainA(Serial);
Brain brainB(Serial1);

// possible interference between motor pwm and soft serial interrupt handling causes motor jitter
//

void setup()
{
  pinMode(ledPin, OUTPUT);

  // Start the hardware serial.
  Serial.begin(9600);
  myservo.attach(servoPin);  // attaches the servo on pin 9 to the servo object

  //Serial.println("Goodnight moon!");

  // set the data rate for the SoftwareSerial port
  Serial1.begin(9600);
}
/*
char hex[]="0123456789abcdef";
char *getHex(int v, int digits, char *s){
  if(s==NULL) return s; // error
  int lnib=0;
  s[digits]=0;
  for(int i=0; i<digits; i++){
   lnib=v & 0x0f;
   s[digits -i -1] = hex[lnib];
   v >>= 4;
  }
  return s;
}
*/

void loop()
{
  /*
    // read and forward raw serial data; conclusion appears to be: if we parse this, it may work
    int c=0;
    char s[]="00";

    while (mySerialB.available()){
      Serial.print(getHex(mySerialB.read(),2,s));
      Serial.print(" ");
      c++;
    }
    if(c>0){
        Serial.println("");
        c=0;
      }
  */
  // Expect packets about once per second.
  // The .readCSV() function returns a string (well, char*) listing the most recent brain data, in the following format:
  // "signal strength, attention, meditation, delta, theta, low alpha, high alpha, low beta, high beta, low gamma, high gamma"

  int qualityA = -1;
  int qualityB = -1;
  int attentionA = 0;
  int attentionB = 0;

  if (brainA.update())
  {
    Serial.print("A: ");
    Serial.println(brainA.readErrors());
    Serial.println(brainA.readCSV());
    qualityA = brainA.readSignalQuality();
    if (qualityA < 60) // link threshold
    {
      attentionA = brainA.readAttention();
    }
    else
      attentionA = 0;

  }

  if (brainB.update())
  {
    Serial.print("B: ");
    Serial.println(brainB.readErrors());
    Serial.println(brainB.readCSV());
    qualityB = brainB.readSignalQuality();
    if (qualityB < 60) // link threshold
    {
      attentionB = brainB.readAttention();
    }
    else
      attentionB = 0;
  }

  // do this only if both headsets are linked? ...

  if (attentionA > attentionB)
  {
    // move the spout ...
    pos += 5;
  }
  if (attentionB > attentionA)
  {
    // move the spout ...
    pos -= 5;
  }

  if (opos != pos)
  {
    Serial.print("pos =");
    Serial.println(pos);
  }
  else
    timeout++;

  opos = pos;
  // upon timeout, move back to 90 degrees

  if (timeout > 65000 || pos < 0 || pos > 180)
  {
    pos = 90;
    timeout = 0;
  }

  myservo.write(pos);              // tell servo to go to position in variable 'pos'
  delay(1);
}
/*
  // motor sweep appears to work

  for(pos = 0; pos < 180; pos += 1)  // goes from 0 degrees to 180 degrees
  {                                  // in steps of 1 degree
    myservo.write(pos);              // tell servo to go to position in variable 'pos'
    delay(35);                       // waits 15ms for the servo to reach the position
  }
  digitalWrite(ledPin, HIGH);

  for(pos = 180; pos>=1; pos-=1)     // goes from 180 degrees to 0 degrees
  {
    myservo.write(pos);              // tell servo to go to position in variable 'pos'
    delay(35);                       // waits 15ms for the servo to reach the position
  }
  digitalWrite(ledPin, LOW);
}
*/

