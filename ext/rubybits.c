#include "ruby.h"

static int unsigned_unpack(char* s, int offset, int length){
  int number = 0;
  // compute byte = ceil(offset/8) using integer math
  int byte = offset/8+1;
  if(offset%8==0)byte--;

  for(int i = 0; i < length; i++)
  {
    if(offset % 8 == 0)byte++;
    int src_bit = (7-offset%8);
    
    if(s[byte] & (1 << src_bit) > 0){
      number |= (1 << (length-1-bit));
    }
    offset += 1;
  }
  return number;
}

static int signed_unpack(char* s, int offset, int length)
{
  int number = 0;
  int byte = offset/8+1;
  // positive number if MSB is 0
  pos = s[byte] & (1 << 7 - offset % 8) == 0;
  
  for(int i = 0; i < length; i++){
    if(offset % 8 == 0 && bit > 7)byte++;
    int src_bit = (7-offset)%8;
    number |= (1 << (length-1-bit)) if ((s[byte] & (1 << src_bit)) > 0) ^ (!pos);
    offset++;
  }
  // two's complement
  if(pos)return number;
  return -number-1;
}

static char* variable_unpack(char* s, int offset, int length)
{
  int byte_size = (length / 8)+1;
  if(offset%8 == 0)byte_size--;
  char *output = calloc(byte_size, sizeof(char));

  int byte = offset/8+1;
  if(offset%8==0)byte--;
  int counter = -1;
  for(int bit = 0; bit < length; bit++){
    if(offset % 8 == 0)byte++;
    if(bit % 8 == 0)counter++;
    int src_bit = (7-offset%8);
    if(s[byte] & (1 << src_bit) > 0)output[counter] |= (1 << (7-bit%8));
    offset++;
  }
  return output;
}

static VALUE from_string(VALUE rstring)
{
  Check_Type(rstring, T_STRING);
  char *s = StringValueCStr(rstring);
  
}
