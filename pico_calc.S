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

idle:
    b idle

// Initialize GPIO pins
gpio_init:
    push {lr}
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
    pop {pc}

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
    push {r0-r2}

    // Set Enable HI
    mov r0, #1
    lsl r0, #E_PIN
    ldr r1, =(SIO_BASE + SIO_GPIO_SET_OFFSET)
    str r0, [r1] // Set pin HI
    // Sleep 20us
    mov r0, #20
    bl delay_us
    // Set Enable LO
    mov r0, #1
    lsl r0, #E_PIN
    ldr r1, =(SIO_BASE + SIO_GPIO_CLR_OFFSET)
    str r0, [r1] // Set pin LO
    // Sleep 50us
    mov r0, #20
    bl delay_us

    pop {r0-r1}
    bx lr

// R0 - Contains the nibble to send. LO bits are discarded.
lcd_send_nibble:
    push {r1-r2, lr}
    // Clear GPIO18-21 (4-bit LCD data pins)
    mov r2, #0x00_3C_00_00
    ldr r1, =(SIO_BASE + SIO_GPIO_CLR_OFFSET)
    str r2, [r1]
    // Mask off nibble
    mov r1, #0x0F
    and r0, r1
    // Shift nibble to start at GPIO18
    lsl r0, #18
    ldr r1, =(SIO_BASE + SIO_GPIO_SET_OFFSET)
    str r0, [r1] // Set data pins
    // Strobe enable pin
    bl lcd_pulse_enable


    pop {r0-r2, pc}