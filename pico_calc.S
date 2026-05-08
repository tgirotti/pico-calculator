    // Nick Mankoski
    // Thomas Girotti
    // 5/7/2026
    // UMass Lowell EECE.3170 Microprocessors I
    // Project: RP2040-based Calculator in ARM Assembly

    // Individual contributions to code are marked before identifiers
    // NOTE: When Arias' C code is mentioned, it is referring to https://github.com/TheMadSocrates/robotarm/blob/master/lcd/hd44780.c
    //       which is Copyright (C) 2014 Orlando Arias. Used with permission

// Includes for named memory addresses from the datasheet (.S ran through C-preprocessor and I had issues trying to get .include to work
// in my hw despite me thinking it's the same)
#include "hardware/regs/addressmap.h" //Base addresses for all peripheral blocks
#include "pico/asm_helper.S" // Named memory-mapped registers
#include "hardware/regs/io_bank0.h" // IO Bank registers
#include "hardware/regs/timer.h" // Timer registers
#include "hardware/regs/sio.h" // SIO registers
#include "hardware/regs/intctrl.h" // Interrupt registers/bits
#include "hardware/regs/m0plus.h" // Cortex-M0+ registers (interrupt regs, etc.)
#include "hardware/regs/pads_bank0.h" // Pad control registers

.section .text // Code section
.global pico_calc // Global identifier (for exporting to `main.c`)
.type pico_calc, %function // Type of the global identifier is a function

.equ RS_PIN, 16     // pin 21  // Like #define in C, register-select pin for the LCD
.equ E_PIN,  17     // pin 22 // Like #define in C, enable pin for the LCD
//kbd rows gpio 0-4
//kbd cols gpio 5-9

.equ KBD_ROW_MASK, 0x0000001F//gpio 0 -4  // Bitmask corresponding to GPIO 0-4
.equ KBD_COL_MASK, 0x000003E0//gpio 5-9   // Mask for GPIO 5-9


pico_calc:                  // main   // Main label
    bl gpio_init // Call gpio_init subroutine with link (inits GPIO pins)
    bl kbd_init  // Call kbd_init subroutine wih link (sets up keypad stuff)
    bl lcd_init  // Call lcd_init subroutine with link (sets up screen)
    bl clear_display // Call clear_display subroutine with link (clears the LCD screen)
    mov r2, #0 // r2 is the counter for _send_loop

// Thomas' test code for LCD display (when it wasn't burnt to a crisp)
_send_loop: // Loop to send "Welcome!" to the screen for testing
    cmp r2, #8 // Is r2 >= 8?
    bge _send_loop_exit // If so, we should exit the loop
    ldr r0, =(welcome) // Otherwise, load the address of the first byte of our text string
    ldrb r0, [r0, r2] // Load byte-wise to not load entire string
    mov r1, #1 // Enable RS because we're sending data
    bl lcd_send_byte // Branch with link to lcd_send_byte to send the ASCII character to the LCD
    add r2, #1 // Increment loop counter
    b _send_loop // Go back to beginning of loop

_send_loop_exit: // Label for exit of loop
    // Display the number 186
    bl clear_display // Clear display before we test displaying a number
    ldr r0, =186 // Load 186 into r0, the number we will display
    bl display_number // Call display_number


// Nick's loop to scan keyboard
main_loop: // Main program loop: Continuously scan keypad for button presses and display them on LCD
    bl scan_keyboard // Call keyboard scan subroutine
    cmp r0, #0xFF //seeing if button is pressed
    beq main_loop //if not pressed keeps gong

    mov r4, r0 // If pressed, display the number
    mov r1, #1 // We're sending a character, not a command, so RS must be set when sending byte
    bl lcd_send_byte // Actually display the key we pressed

wait_for_button: // Subroutine to debounce a button
    ldr r0, =50000   //waits for button to bounce back so doesnt press twic
    bl delay_us // Delay by 50 * 10^3 us (50ms)

    bl scan_keyboard // Once delay is over, scan the keyboard again to get the currently pressed keys
    cmp r0, #0xFF // Are any buttons pressed?
    bne wait_for_button // Keep waiting for button to be released before continuing

    b main_loop // No more buttons are being pressed, so we can go back to main loop

// Nick's scan keyboard function
scan_keyboard: // Test and scan keyboard subroutine (TODO: Nick Comments)
    push {r4-r7, lr}
    ldr r4, =SIO_BASE
    mov r5, #0 

row_check:
    mov r1, #0x1F           //setting high
    str r1, [r4, #SIO_GPIO_OUT_SET_OFFSET]

    mov r1, #1
    lsl r1, r1, r5
    str r1, [r4, #SIO_GPIO_OUT_CLR_OFFSET]
    //current row low

    mov r0, #10
    bl delay_us  //adding delay inbetween sweeps

    //read columns
    ldr r6, [r4, #SIO_GPIO_IN_OFFSET]
    ldr r7, =0x3E0         
    and r6, r6, r7
    
    //check if col went low
    cmp r6, r7              
    beq next_row
    // find what col went low
    mov r2, #5    

col_check:
    mov r3, #1
    lsl r3, r3, r2
    tst r6, r3
    beq key_pressed  // r0 contains the key that is pressed  
    add r2, r2, #1
    cmp r2, #10
    blt col_check

next_row:
    add r5, #1
    cmp r5, #5
    blt row_check
    mov r0, #0xFF          //nothting prssed
    pop {r4-r7, pc}

key_pressed:
    // index     (row * 5) + (col - 5)
    mov r1, #0x1F
    str r1, [r4, #SIO_GPIO_OUT_SET_OFFSET] 
    mov r0, r5
    mov r1, #5
    mul r0, r1
    sub r2, r2, #5
    add r0, r0, r2
    ldr r1, =key_map//inset where we have all asci values
    ldrb r0, [r1, r0]
    movs r1, #1 // Send character
    bl clear_display
    bl lcd_send_byte // Send ASCII code that was pressed
    pop {r4-r7, pc}

kbd_init:
    push {lr}
    ldr r2, =PADS_BANK0_BASE
    mov r3, #5               
kbd_loop:
    mov r0, r3
    lsl r0, #2             
    add r0, #4             
    add r0, r2
    mov r1, #0x48            
    str r1, [r0]
    add r3, #1
    cmp r3, #9              
    ble kbd_loop
    pop {pc}

// Nick + Thomas
// Initialize GPIO pins
gpio_init:
    push {r0-r4, lr} // Push any registers we use to the stack (no enforced calling convention)

    mov r3, #0 // Start with GPIO 0
    mov r4, #9 // End with GPIO 9
    bl gpio_loop_data // Set up all the pads for GPIO 0-9 inclusive

    mov r3, #16 // Start with GPIO 16
    mov r4, #21 // End with GPIO 21
    bl gpio_loop_data // Pad setup for 16-21 inclusive
 
    ldr r2, =SIO_BASE // r2 has the address of SIO_BASE memory-mapped register

    mov r1, #KBD_ROW_MASK // r1 has the GPIO pins used for the rows in the keypad
    str r1, [r2, #SIO_GPIO_OUT_SET_OFFSET] // TODO: This might be a bug, 

    ldr r1, =0x003F001F // TODO: What is this mask?
    str r1, [r2, #SIO_GPIO_OE_SET_OFFSET] // 

    ldr r1, =KBD_COL_MASK // r1 has the mask for the GPIO pins used for columns
    str r1, [r2, #SIO_GPIO_OE_CLR_OFFSET] // Clear all the column pins

    pop {r0-r4, pc} // Pop r0-r4 off the stack and pop pc, which will set pc = lr from when we pushed it

// Nick
// R3 - Pin to start
// R4 - Pin to end at inclusive
gpio_loop_data:
    push {lr}

gpio_loop_data_loop:
    bl set_pin_sio
    add r3, r3, #1
    cmp r3, r4
    ble gpio_loop_data_loop

    pop {pc}

// Nick
// Select Function 5 (SIO) for GPIO pins
set_pin_sio:
    push {r0-r1}

    ldr r0, =(IO_BANK0_BASE + IO_BANK0_GPIO0_CTRL_OFFSET)
    lsl r1, r3, #3
    add r0, r0, r1

    mov r1, #5
    str r1, [r0]

    pop {r0-r1}
    bx lr

// Thomas ported from his HW6, original from Lecture
// Delay for number of microseconds
// r0 - Contains the number of microseconds to stall 
// NOTE: This code is from Lecture ## TODO
delay_us:
    push {r1-r3} // Push r1-r3 onto the stack (we will overwrite them)
    ldr r2, =TIMER_BASE // r2 has the address of TIMER_BASE from datasheet
    ldr r1, [r2, #TIMER_TIMELR_OFFSET]  // grab start time 
    add r1, r0 // Grab end time from caller's passed arguments
delay_wait: // Loop to wait until the timer exceeds the 
    ldr r3, [r2, #TIMER_TIMELR_OFFSET]
    cmp r3, r1
    blo delay_wait // blo is synonym for blt
    pop {r1-r3}
    bx lr

// Translated by Thomas, original code in C from Arias (used with permission)
// NOTE: This code was translated from Arias' C code (TODO: specify lines)
// Pulses the enable pin
lcd_pulse_enable:
    push {r0-r2, lr}

    // Set Enable HI
    mov r0, #1 // Starting mask
    lsl r0, #E_PIN // Left shift the binary 1 to the GPIO pin for LCD enable
    ldr r1, =(SIO_BASE + SIO_GPIO_OUT_SET_OFFSET) // r1 has the address of the GPIO output set register (so we can actually enable the pin)
    str r0, [r1] // Set pin HI. This is an atomic write-only register, so it only _sets_ enable on E_PIN, and won't affect other pins
    // Sleep 20us (per LCD datasheet)
    mov r0, #20 // r0 has the amount of microseconds to sleep
    bl delay_us // Call the microsecond delay
    // Set Enable LO
    mov r0, #1 // Starting mask
    lsl r0, #E_PIN // Left shift binary 1 to GPIO pin for enable
    ldr r1, =(SIO_BASE + SIO_GPIO_OUT_CLR_OFFSET) // Same behavior as output set WO register, but this one clears our pin!
    str r0, [r1] // Set the pin low
    // Sleep 50us (from datasheet)
    mov r0, #50
    bl delay_us

    pop {r0-r2, pc}

// Translated by Thomas, original code in C from Arias (used with permission)
// R0 - Contains the nibble to send. LO bits are discarded.
// NOTE: This code translated from Arias TODO
lcd_send_nibble:
    push {r1-r2, lr} // Push our used registers r1-r2 onto the stack, and push lr since we're an intermediate function (non-leaf)
    // Clear GPIO18-21 of any old data (4-bit LCD data pins)
    ldr r2, =0x003C0000 // r2 has mask for GPIO pins 18-21
    ldr r1, =(SIO_BASE + SIO_GPIO_OUT_CLR_OFFSET) // r1 has the GPIO_OUT_CLR register
    str r2, [r1] // Clear GPIO 18-21
    // Mask off nibble
    mov r1, #0x0F // Mask to only keep the LOW part of the byte
    and r0, r1 // Bitwise AND, and now r0 only has the LOW part of the original byte
    
    lsl r0, #18 // Left-shift nibble to start at GPIO18
    ldr r1, =(SIO_BASE + SIO_GPIO_OUT_SET_OFFSET) 
    str r0, [r1] // Set the data pins we wanted to send to the LCD screen
    // Strobe enable pin
    bl lcd_pulse_enable // Pulses the enable pin so the screen takes our data


    pop {r1-r2, pc} // Pop our used registers r1-r2 off the stack, and return to our caller

// Translated by Thomas, original code in C from Arias (used with permission)
// R0 - Byte to send
// R1 - 0 for commands, 1 for data
// NOTE: This was translated from Arias' C code function lcd_send_byte
lcd_send_byte:
    push {r1-r4, lr} // TODO: Don't push r1 here

    mov r4, r1 // Copy is_data to r4
    // Clear RS (may be high from last send)
    mov r1, #1 // Start with 1 so we can shift it into a bitmask
    lsl r1, #RS_PIN // Create the RS_PIN bitmask
    ldr r2, =(SIO_BASE + SIO_GPIO_OUT_CLR_OFFSET) // Address of WO clear GPIO register to clear any existing data
    str r1, [r2] // Actually clear the RS pin

    cmp r4, #0 // Is data (characters)?
    beq _lcd_send_byte_send_nibbles // We're sending command, so just send it
    // Else we have data, set the RS pin first before sending
    mov r1, #1 // Starting bitmask
    lsl r1, #RS_PIN // Align with the RS_PIN
    ldr r2, =(SIO_BASE + SIO_GPIO_OUT_SET_OFFSET) // Address of WO GPIO set register
    str r1, [r2] // Actually turn on the RS pin
_lcd_send_byte_send_nibbles:
    // Send high nibble
    mov r3, r0 // r3 has original byte
    lsr r0, #4 // Align high nibble
    bl lcd_send_nibble // Actually send nibble

    mov r0, r3 // Copy original byte back into r0
    mov r1, #0x0F // Mask to keep lower bits
    and r0, r1 // Mask off low nibble
    bl lcd_send_nibble // actually send nibble

    ldr r0, =500 // Delay for 500us
    bl delay_us // Call our delay function

    pop {r1-r4, pc} // Pop r1-r4 off the stack, and return by popping the program counter

// Copied by Thomas from datasheet with minor edits
// R0 has dividend
// R1 has divisor
// When complete, R0 will have quotient, R1 will have remainder
// NOTE: This code adapted from RP2040 datasheet, p.32
hw_divide: // From datasheet, p.32
    push {r2-r3} // We're using r2-r3 as local vars so push them to stack

    ldr r3, =(SIO_BASE) // Load the SIO base
    // Unsigned
    str r0, [r3, #SIO_DIV_UDIVIDEND_OFFSET] // Put the dividend (# we want to divide) into the unsigned dividend reg
    str r1, [r3, #SIO_DIV_UDIVISOR_OFFSET] // Put divisor in unsigned divisor reg, and now the divider will take 8 cycles
    // Wait 8 cycles for division to complete (per datasheet)
    nop // No operation (do nothing)
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    // Result now available
    ldr r0, [r3, #SIO_DIV_QUOTIENT_OFFSET] // Load r0 with the quotient from the divider
    ldr r1, [r3, #SIO_DIV_REMAINDER_OFFSET] // Load r0 with the remainder from the divider

    pop {r2-r3} // Done with r2-r3, pop them from the stack
    bx lr // Return to the caller

// Thomas' code to extract decimal digits from a number to display using the screen
// Precondition: r0 contains the number to display
//               The number is 16 decimal digits or less
// NOTE: It is the CALLEE's responsibility to clear the display before executing
display_number:
    // Reverse the order for display on screen
    push {r1-r5, lr} // Push r1-r5 to the stack so we can use them as locals, and lr since we call hw_divide later
    // Get largest digit (1 * (10^i))
    mov r2, r0 // Original num in r2
    mov r3, #15 // display_digit loop counter (starts from 15 to decrement, 15-0 inclusive = 16 cols)
// The idea of this loop is to perform the following:
// `extracted_digit = (original_number / tens_place) % 10`
// for all digits
_display_number_digit_display_loop:
    cmp r3, #0 // Are we at the end of the loop?
    blt _display_number_ret // Acts like `for (i = 15; i >= 0, i--)` in C, we exit the loop once !(i >= 0) is true i.e. i < 0
    
    mov r1, #1 // Start with 1 as our divisor
    mov r4, #0 // power_of_ten (loop counter)
_power_ten_loop: // Loop to find out which power of 10 (tens_place) we need to divide by
                 // based on the digit we're trying to display
    cmp r4, r3 // We've found the power of 10 to divide by, so we should exit
    bge _power_ten_loop_exit // Positive incrementing loop, so acts like `for (i = 0; i < display_digit; i++)` to find power of 10
    // power_of_ten < display_digit
    mov r5, #10 // Multiplying by 10
    mul r1, r5 // r1 = r1 * 10
    add r4, #1 // power_of_ten++
    b _power_ten_loop // continue loop
_power_ten_loop_exit:
    // Copy r2 into r0 now that we know what to divide by
    mov r0, r2
    // Divisor still in r1, original digit still in r0
    bl hw_divide
    // r0 = quotient
    // r1 = remainder
    mov r1, #10 // Need to perform the `% 10` to get the actual digit
    bl hw_divide // digit % 10 = extracted_digit
    // We finally have our extracted digit. Now we send it to the display by adding the digit to '0' (48) in ASCII
    // which will display the number we want.
    // Send '0' + extracted_digit to display
    mov r0, r1 // r0 is our digit
    add r0, #'0'
    mov r1, #1
    bl lcd_send_byte
    // display_digit--
    sub r3, #1 // Decrement so we get the next place to display
    b _display_number_digit_display_loop
_display_number_ret:
    pop {r1-r5, pc}

// Translated by Thomas, original code in C from Arias (used with permission)
// Clears the display
// NOTE: From Arias' C code TODO: find attribution
clear_display:
    push {r0-r1, lr} // Push r0-r1 (used as locals), and lr since we're not a leaf function

    mov r0, #0x01 // Clear display instruction from datasheet
    mov r1, #0x00 // Sending a command
    bl lcd_send_byte
    // Wait >1.52ms
    ldr r0, =1520
    bl delay_us // 

    pop {r0-r1, pc} // Pop r0-r1 and rerturn to caller by popping pc


.data // Data section for variables we store in the binary
welcome: .ascii "Welcome!" // .ascii is a NOT null-terminated array of characters

// Nick
.align 2
key_map:
.ascii "789  "      //row 1
.ascii "456  "      //row 2
.ascii "123- "      //row 3
.ascii "0=+  "      //roe 4
.ascii "     "      //row 5     
