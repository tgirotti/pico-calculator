#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/gpio.h"

extern void pico_calc(void);

// --- Pin Definitions  ---
#define RS_PIN 16
#define E_PIN  17
#define D4_PIN 18
#define D5_PIN 19
#define D6_PIN 20
#define D7_PIN 21

// --- Low Level Pulse & Nibble Logic ---

void lcd_pulse_enable_init()
{
  gpio_put(E_PIN, 1);
  sleep_us(20);  // Matches the delay in your assembly pulse logic 
  gpio_put(E_PIN, 0);
  sleep_us(50);  // Execution time for most commands
}

void lcd_send_nibble_init(uint8_t nibble)
{
  // Clear data pins GP18-21 (Mask: 0x003C0000) 
  gpio_clr_mask(0x003C0000);

  // Shift the 4-bit nibble to start at GP18 and set those pins 
  uint32_t values = (uint32_t)(nibble & 0x0F) << 18;
  gpio_set_mask(values);

  lcd_pulse_enable_init();
}

void lcd_send_byte_init(uint8_t byte, bool is_data)
{
  // RS=1 for Data (characters), RS=0 for Commands
  gpio_put(RS_PIN, is_data);

  // Send High Nibble first, then Low Nibble
  lcd_send_nibble_init(byte >> 4);
  lcd_send_nibble_init(byte & 0x0F);

  sleep_us(500); // Standard processing delay
}

// --- Initialization & Printing ---

void lcd_init() {
  // Initialize all pins as GPIO and set to Output mode 
  for (int i = 16; i <= 21; i++) {
    gpio_init(i);
    gpio_set_dir(i, GPIO_OUT);
  }

  sleep_ms(50); // Wait for LCD power to stabilize 
  gpio_put(RS_PIN, 0); // Start in command mode 

  // The Triple Handshake: Force the LCD into 8-bit mode before switching
  lcd_send_nibble_init(0x03);
  sleep_ms(5);
  lcd_send_nibble_init(0x03);
  sleep_us(2000);
  lcd_send_nibble_init(0x03);
  sleep_us(2000);

  // Switch to 4-bit mode
  lcd_send_nibble_init(0x02);
  sleep_us(2000);

  // Configuration sequence
  lcd_send_byte_init(0x28, false); // 2 lines, 5x8 font
  lcd_send_byte_init(0x0C, false); // Display ON, Cursor OFF
  lcd_send_byte_init(0x01, false); // Clear display
  sleep_ms(5);                // Clearing needs >1.52ms
  lcd_send_byte_init(0x06, false); // Entry mode: increment cursor
}

void lcd_write_string(const char* s) {
  while (*s) {
    lcd_send_byte_init(*s++, true); // Send characters one by one
  }
}

int main() {
  stdio_init_all();

  lcd_init();
  // lcd_write_string("Hello World"); // Display the string

  // while (true) {
  //   tight_loop_contents();
  // }
  while (true) {
    pico_calc();
  }
}