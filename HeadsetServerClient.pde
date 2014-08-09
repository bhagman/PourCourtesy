/*
|| @author         Brett Hagman <bhagman@wiring.org.co>
|| @url            http://site3.ca/
|| @contribution   Marc Reeve-Newson <marc.reevenewson@gmail.com>
|| @contribution   Kate Murphy <hello@kate.io>
|| @contribution   Paul Shields <shields.paul@gmail.com>
|| @contribution   Callum Hay <callumhay@gmail.com>
||
|| @description
|| | A drink-pouring game which uses "mind-control" to pour drinks for one
|| | of two players.
|| |
|| | This Extension Sketch reads the serial stream from the headset server
|| | and performs magic to produce "attention" levels from each player.
|| |
|| | Wiring/Arduino Extension Sketch
|| #
||
|| @license Please see License.txt.
||
|| @name PourCourtesy.pde
|| @type Sketch
|| @target Wiring S
*/

#define HeadsetSerial Serial1
#define HEADSET_SERIAL_START_CHAR 0
#define HEADSET_SERIAL_SPEED 9600
#define HEADSET_STREAM_TIMEOUT 2000

enum { START, B_A1, B_B1, B_A2, B_B2 } serialState;


void initHeadsets()
{
  HeadsetSerial.begin(HEADSET_SERIAL_SPEED);
}

int mungeAlphaBetaIntoAttention(uint8_t a, uint8_t b)
{
  // Let's whack the Alpha and Beta values into something that we can use.
  // To mimic previous versions, let's make a value between 0 and 100, as
  // a pseudo-percentage.

  // a is between 0 and 255?
  // b is between 0 and 255?

  int c = a - b;
  if (c < 0)
    c = 0;
  if (c > 255)
    c = 255;

  return map(c, 0, 255, 0, 100);
}

bool readHeadsets()
{
  // Get data from the headset server.
  
  // We need to supply an attention value:
  // attentionPlayer_1, attentionPlayer_2
  //
  // The attention values are essentially arbitrary, and increasing (i.e.
  // a larger attention value means a player is more attentive).
  // (Previous attention values were a percentage, i.e. 0 - 100)

  static int16_t a1, b1, a2, b2;
  static uint32_t lastByteReceived_millis = millis();

  uint8_t ch = 0;

  // Synchronize with headset server

  while (HeadsetSerial.available() > 0)
  {
    if (HeadsetSerial.available() > 1)
    {
      Serial.print("Overflow: ");
      Serial.print(serialState, DEC);
      Serial.print(' ');
      Serial.println(HeadsetSerial.available(), DEC);
    }
    ch = HeadsetSerial.read();
//Serial.print(ch, HEX);
//Serial.print(' ');
    if (serialState != START)
    {
      lastByteReceived_millis = millis();
    }

    // Resync if we get out of whack
    if (ch == HEADSET_SERIAL_START_CHAR)
      serialState = START;
    
    switch (serialState)
    {
      case START:
        if (ch == HEADSET_SERIAL_START_CHAR)
        {
          serialState = B_A1;
          lastByteReceived_millis = millis();
        }
        break;
      case B_A1:
        a1 = ch;
        serialState = B_B1;
        break;
      case B_B1:
        b1 = ch;
        serialState = B_A2;
        break;
      case B_A2:
        a2 = ch;
        serialState = B_B2;
        break;
      case B_B2:
        b2 = ch;
        serialState = START;
        attentionPlayer_1 = mungeAlphaBetaIntoAttention(a1, b1);
        attentionPlayer_2 = mungeAlphaBetaIntoAttention(a2, b2);

//Serial.println();

//        Serial.print("GOT: ");
//        Serial.print(a1, HEX);
//        Serial.print(' ');
//        Serial.print(b1, HEX);
//        Serial.print(' ');
//        Serial.print(a2, HEX);
//        Serial.print(' ');
//        Serial.println(b2, HEX);
        break;
    }
  }
    
  if ((millis() - lastByteReceived_millis) > HEADSET_STREAM_TIMEOUT)
    return false;
  else
    return true;
}

