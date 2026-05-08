#include <stdio.h>         //May not need this?
#include "pico/stdlib.h"   // Use Pico SDK's standard library
#include "hardware/gpio.h" // Use Pico SDK's GPIO functions

extern void pico_calc(void); // Tell the linker there exists an external function
// that retunrs nothing and takes nothing that we can call from this file
// (external function declaration)

// Pin numbers as C preprocessor constants
#define RS_PIN 16
#define E_PIN  17
#define D4_PIN 18
#define D5_PIN 19
#define D6_PIN 20
#define D7_PIN 21

// All the functions in this file have `_init` appended because some match the pico_calc.S
// file
void lcd_pulse_enable_init() // Pulse the enable pin according to data sheet
{
  gpio_put(E_PIN, 1); // Set GPIO 17 pin HI
  sleep_us(20);       // Sleep for 20 microseconds
  gpio_put(E_PIN, 0); // Turn off enable pin
  sleep_us(50);       // Sleep for 50 us
}

// Given a nibble, send it to the LCD screen's data pins
void lcd_send_nibble_init(uint8_t nibble)
{
  // Clear data pins GP18-21
  gpio_clr_mask(0x003C0000);

  // Shift the nibble to align to GPIO18
  uint32_t values = (uint32_t)(nibble & 0x0F) << 18; // Mask off the byte's lower bits to get the nibble
  // then left shift by 18. Cast to a uint32 to actually shift left 18 times
  gpio_set_mask(values); // Pico SDK function to set the GPIO_OUT_SET WO register given a mask

  lcd_pulse_enable_init(); // Pulse the enable pin so the LCD takes our data on its bus
}

void lcd_send_byte_init(uint8_t byte, bool is_data) // Send a full byte to the LCD screen
{
  // RS=1 for Data (characters), RS=0 for Commands
  gpio_put(RS_PIN, is_data); // Enable the register-select RS pin based on if we're sending commands or characters

  // Send High Nibble first, then Low Nibble
  lcd_send_nibble_init(byte >> 4);   // Left shifts the high nibble into the lower nibblem then sends it
  lcd_send_nibble_init(byte & 0x0F); // Masks off the lower nibble and sends it

  sleep_us(500); // Sleep for 500us to make sure the data is send. Maybe doesn't need to be that high?
}

// Initialize the LCD screen
void lcd_init() {
  // Initialize all pins as GPIO and set to Output mode
  for (int i = 16; i <= 21; i++)
  {                            // Loop from pins 16-21 inclusive
    gpio_init(i);              // Sets up pin `i` as input, low, and the pin type as GPIO from SIO
    gpio_set_dir(i, GPIO_OUT); // Set the pin as a GPIO output pin (since gpio_init sets it as in)
  }

  sleep_ms(50);        // Wait for LCD to power on (from Hitachi datasheet)
  gpio_put(RS_PIN, 0); // We're sending commands, not data

  // Per Hitachi datasheet, need to send these to put LCD into 4-bit mode when it's in 8-bit mode to begin with
  lcd_send_nibble_init(0x03); // Send 3
  sleep_ms(5);                // Wait 5ms
  lcd_send_nibble_init(0x03); // Send 3 again
  sleep_us(2000);             // Wait 2ms
  lcd_send_nibble_init(0x03); // Send 3 once more
  sleep_us(2000);             // Wait another 2 ms

  // Switch to 4-bit mode
  lcd_send_nibble_init(0x02); // Switch into 4 bit
  sleep_us(2000);             // Wait another 2ms

  // We're finally in 4-bit mode
  // Configuration sequence (from Hitachi datasheet flowchart under 4 bit initialization)
  lcd_send_byte_init(0x28, false); // 2 lines, 5x8 font
  lcd_send_byte_init(0x0C, false); // Display ON, Cursor OFF
  lcd_send_byte_init(0x01, false); // Clear display
  sleep_ms(5);                // Clearing needs >1.52ms
  lcd_send_byte_init(0x06, false); // Entry mode: increment cursor
}

// Given a null-terminated array of chars, send each of those chars to the screen
// TOOD: change this to accept size parameter because null-terminated strings are meh
void lcd_write_string(const char* s) {
  while (*s)
  {                                 // While the string is not the null pointer,
    lcd_send_byte_init(*s++, true); // send each character one by one, then increment pointer for next iteration
  }
}

int main()
{                   // Entrypoint of program
  stdio_init_all(); // Init the Pico SDK stuff (given by assignment)

  lcd_init(); // Initialize the LCD screen in C
  // lcd_write_string("Hello World"); // Display the string

  while (true)
  {              // Infinite loop to call our assembly
    pico_calc(); // Run our assembly code!
  }
}