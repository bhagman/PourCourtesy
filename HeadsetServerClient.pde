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
#define HEADSET_SERIAL_SPEED 9600
#define HEADSET_STREAM_TIMEOUT 2000

int16_t a1, b1, a2, b2;

void initHeadsets()
{
  HeadsetSerial.begin(HEADSET_SERIAL_SPEED);
}

bool waitForStreamByte()
{
  uint32_t start = millis();

  while (!HeadsetSerial.available())
  {
    if ((millis() - start) > HEADSET_STREAM_TIMEOUT)
      return false;
  }

  return true;
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
  
  // We need to supply an attention value, and a score for each player:
  // attention_player_1, attention_player_2
  // score_player_1, score_player_2
  //
  // The attention values are essentially arbitrary, and increasing (i.e.
  // a larger attention value means a player is more attentive).
  // (Previous attention values were a percentage, i.e. 0 - 100)
  //
  // The score values are between 0 and 8, 0 is lowest, and 8 is highest.

  uint8_t c = 0;

  // Synchronize with headset server - '|' is the start byte
  while (c != '|')
  {
    if (waitForStreamByte())
    {
      c = HeadsetSerial.read();
    }
    else
      return false;
  }

  // We have the start byte, now read in the values
  if (waitForStreamByte())
    a1 = HeadsetSerial.read();
  else
    return false;

  if (waitForStreamByte())
    b1 = HeadsetSerial.read();
  else
    return false;

  if (waitForStreamByte())
    a2 = HeadsetSerial.read();
  else
    return false;

  if (waitForStreamByte())
    b2 = HeadsetSerial.read();
  else
    return false;

  attention_player_1 = mungeAlphaBetaIntoAttention(a1, b1);
  score_player_1 = int(8 * (float(attention_player_1) / 100));

  attention_player_2 = mungeAlphaBetaIntoAttention(a2, b2);
  score_player_2 = int(8 * (float(attention_player_2) / 100));

  return true;
}

