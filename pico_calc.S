	// Nick Mankoski
	// Thomas Girotti
	// 4/26/2026
	// UMass Lowell EECE.3170 Microprocessors I
	// Project: RP2040-based Calculator in ARM Assembly


#include "hardware/regs/addressmap.h" //Base addresses for all peripheral blocks
#include "pico/asm_helper.S" // Named memory-mapped registers
#include "hardware/regs/io_bank0.h" // IO Bank registers
#include "hardware/regs/timer.h" // Timer registers
#include "hardware/regs/sio.h" // SIO registers
#include "hardware/regs/intctrl.h" // Interrupt registers/bits
#include "hardware/regs/m0plus.h" // Cortex-M0+ registers (interrupt regs, etc.)
#include "hardware/regs/pads_bank0.h" // Pad control registers

.section .text
.global pico_calc
.type pico_calc, %function

.equ RS_PIN, 16     // pin 21 
.equ E_PIN,  17     // pin 22



pico_calc:                  // main   
    bl gpio_init
    mov r2, #0
_send_loop:
    cmp r2, #8
    bge _send_loop_exit
    ldr r0, =(welcome)
    ldrb r0, [r0, r2] // Load byte-wise to not load entire string
    mov r1, #1 // Enable RS because we're sending data
    bl lcd_send_byte
    add r2, #1
    b _send_loop

_send_loop_exit:
    // Display the number 186
    bl clear_display
    ldr r0, =186
    bl display_number

idle:
    b idle

// Initialize GPIO pins
gpio_init:
    push {r0-r4, lr}
    ldr r2, =SIO_BASE

    // Enable GPIOs as output
    //gipo 16-21 rs, E, d4, d5, d6, d7 as outputs for screen
    // GPIO 0-9 for button matrix
    ldr r1, =0x003F02FF
    str r1, [r2, #SIO_GPIO_OE_SET_OFFSET]

    // counter at pin 0 
    mov r3, #0
    mov r4, #9 // Loop until 9
    bl gpio_loop_data

    mov r3, #16
    mov r4, #22
    bl gpio_loop_data
    pop {r0-r4, pc}

// R3 - Pin to start
// R4 - Pin to end at (inclusive)
gpio_loop_data:
    push {lr}
    bl set_pin_sio
    add r3, #1
    cmp r3, r4  //check if finished at pin 9
    ble gpio_loop_data
    pop {pc}

// Select Function 5 (SIO) for GPIO pins
set_pin_sio:
    push {r0-r1}
    ldr r0, =(IO_BANK0_BASE + IO_BANK0_GPIO0_CTRL_OFFSET)
    lsl r1, r3, #3
    add r0, r1
    mov r1, #5
    str r1, [r0]
    pop {r0-r1}
    bx lr

// Delay for number of microseconds
// r0 - Contains the number of microseconds to stall 
delay_us:
    push {r1-r3}
    ldr r2, =TIMER_BASE
    ldr r1, [r2, #TIMER_TIMELR_OFFSET]  // grab start time 
    add r1, r0
delay_wait:
    ldr r3, [r2, #TIMER_TIMELR_OFFSET]
    cmp r3, r1
    blo delay_wait
    pop {r1-r3}
    bx lr

lcd_pulse_enable:
    push {r0-r2, lr}

    // Set Enable HI
    mov r0, #1
    lsl r0, #E_PIN
    ldr r1, =(SIO_BASE + SIO_GPIO_OUT_SET_OFFSET)
    str r0, [r1] // Set pin HI
    // Sleep 20us
    mov r0, #20
    bl delay_us
    // Set Enable LO
    mov r0, #1
    lsl r0, #E_PIN
    ldr r1, =(SIO_BASE + SIO_GPIO_OUT_CLR_OFFSET)
    str r0, [r1] // Set pin LO
    // Sleep 50us
    mov r0, #20
    bl delay_us

    pop {r0-r2, pc}

// R0 - Contains the nibble to send. LO bits are discarded.
lcd_send_nibble:
    push {r1-r2, lr}
    // Clear GPIO18-21 (4-bit LCD data pins)
    ldr r2, =0x003C0000
    ldr r1, =(SIO_BASE + SIO_GPIO_OUT_CLR_OFFSET)
    str r2, [r1]
    // Mask off nibble
    mov r1, #0x0F
    and r0, r1
    // Shift nibble to start at GPIO18
    lsl r0, #18
    ldr r1, =(SIO_BASE + SIO_GPIO_OUT_SET_OFFSET)
    str r0, [r1] // Set data pins
    // Strobe enable pin
    bl lcd_pulse_enable


    pop {r1-r2, pc}

// R0 - Byte to send
// R1 - 0 for commands, 1 for data
lcd_send_byte:
    mov r4, r1 // Copy is_data to r4
    push {r1-r4, lr}
    // Clear RS
    mov r1, #1
    lsl r1, #RS_PIN
    ldr r2, =(SIO_BASE + SIO_GPIO_OUT_CLR_OFFSET)
    str r1, [r2]

    cmp r4, #0 // Is data (characters)?
    beq _lcd_send_byte_send_nibbles // This beq from the cmp from the start of the function before we push r1
    // Is data, set RS
    mov r1, #1
    lsl r1, #RS_PIN
    ldr r2, =(SIO_BASE + SIO_GPIO_OUT_SET_OFFSET)
    str r1, [r2]
_lcd_send_byte_send_nibbles:
    // Send high nibble
    mov r3, r0 // r3 has original byte
    lsr r0, #4 // Align high nibble
    bl lcd_send_nibble

    mov r0, r3 // Copy original byte back into r0
    mov r1, #0x0F
    and r0, r1 // Mask off low nibble
    bl lcd_send_nibble

    ldr r0, =500
    bl delay_us

    pop {r1-r4, pc}

// R0 has divisor
// R1 has dividend
// When complete, R0 will have quotient, R1 will have remainder
hw_divide: // From datasheet, p.32
    push {r2-r3}

    ldr r3, =(SIO_BASE)
    // Unsigned
    str r0, [r3, #SIO_DIV_UDIVIDEND_OFFSET]
    str r1, [r3, #SIO_DIV_UDIVISOR_OFFSET] // Division will start immediately
    // Wait 8 cycles for division to complete (per datasheet)
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    // Result available
    ldr r0, [r3, #SIO_DIV_QUOTIENT_OFFSET]
    ldr r1, [r3, #SIO_DIV_REMAINDER_OFFSET]

    pop {r2-r3}
    bx lr

// Precondition: r0 contains the number to display
//               The number is 16 decimal digits or less
// NOTE: It is the CALLEE's responsibility to clear the display before executing
display_number:
    // Reverse the order for display on screen
    push {r1-r4, lr}
    // Get largest digit (1 * (10^i))
    mov r2, r0 // Original num in r2
    mov r3, #15 // display_digit loop counter (starts from 15 to decrement, 15-0 inclusive = 16 cols)
_display_number_digit_display_loop:
    // Exit if we're larger than 16 columns of display
    cmp r3, #0
    ble _display_number_ret
    
    mov r1, #1 // divisor = 1
    mov r4, #0 // power_of_ten (oop counter)
_power_ten_loop:
    cmp r4, r3
    bge _power_ten_loop_exit
    // power_of_ten < display_digit
    mov r5, #10
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
    mov r1, #10
    bl hw_divide // digit % 10 = extracted_digit
    // Send '0' + extracted_digit to display
    mov r0, r1 // r0 is our digit
    add r0, #'0'
    mov r1, #1
    bl lcd_send_byte
    // display_digit--
    sub r3, #1
    b _display_number_digit_display_loop
_display_number_ret:
    pop {r1-r4, pc}

// Clears the display
clear_display:
    push {r0-r1, lr}

    mov r0, #0x01 // Clear display instruction
    mov r1, #0x00 // Command
    bl lcd_send_byte
    // Wait >1.52ms
    ldr r0, =1520
    bl delay_us

    pop {r0-r1, pc}


.data
welcome: .ascii "Welcome!"
