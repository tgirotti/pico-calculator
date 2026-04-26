#include <stdio.h>
#include "pico/stdlib.h"

uint32_t pico_calc();

int main(void)
{
  stdio_init_all();
  while (true)
  {
    pico_calc();
  }
}
