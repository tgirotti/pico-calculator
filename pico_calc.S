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
//pinout
.equ RS_PIN, 16     // pin 21 
.equ E_PIN,  17     // pin 22

// d4 - 18
// d5 - 19
// d6 - 20
// d7 - 21
.section .text
.global pico_calc
.type pico_calc, %function

pico_calc:                  // main   
    bl gpio_init
    bl lcd_init
    mov r0, #'7'  //writing 7 to screen
    bl lcd_write_char
loop:
    b loop

// gpio injt 
gpio_init:
    push {lr}
    ldr r2, =SIO_BASE

    //gipo 16-21 rs, E, d4, d5, d6, d7 as outputs for screen
    ldr r1, =0x003F0000
    str r1, [r2, #SIO_GPIO_OE_SET_OFFSET]

    // counter at pin 16 
    mov r3, #16
gpio_loop_data:
    bl set_pin_sio
    add r3, #1
    cmp r3, #22  //check if finished at pin 22
    blt gpio_loop_data

    pop {pc}


// set function 5 on pin r3
set_pin_sio:
    push {r0, r1, lr}
    ldr r0, =(IO_BANK0_BASE + IO_BANK0_GPIO0_CTRL_OFFSET)
    lsl r1, r3, #3
    add r0, r1
    mov r1, #5
    str r1, [r0]
    pop {r0, r1, pc}

// delay fuction, this fucn overwaires reg 1 2 3, delay is needed to wait for screen to turn on 
delay_us:
    ldr r2, =TIMER_BASE
    ldr r1, [r2, #TIMER_TIMELR_OFFSET]  // grab start time 
    add r1, r0
delay_wait:
    ldr r3, [r2, #TIMER_TIMELR_OFFSET]
    cmp r3, r1
    blo delay_wait
    bx lr

// lcd logic
lcd_pulse_enable:
    // push r4 and r5 so delay doesnt fuck with our pin mask

    push {r4, r5, lr}
    ldr r4, =SIO_BASE
    ldr r5, =(1 << E_PIN)
    
  // e high 
    str r5, [r4, #SIO_GPIO_OUT_SET_OFFSET]  
    mov r0, #2
    bl delay_us
    
  // e low
    str r5, [r4, #SIO_GPIO_OUT_CLR_OFFSET]  
    mov r0, #50
    bl delay_us
    
    pop {r4, r5, pc}

// Send 4 bits to GPIO18-21
// r0 - Nibble to send to the LCD screen
lcd_send_nibble:
    push {r4, lr}
    ldr r2, =SIO_BASE

    // Clear GPIO18-21 inclusive
    ldr r3, =0x003C0000
    str r3, [r2, #SIO_GPIO_OUT_CLR_OFFSET]

    // Nibble mask
    mov r4, #0x0F
    and r0, r4

    // Align with GPIO18
    lsl r0, r0, #18
    str r0, [r2, #SIO_GPIO_OUT_SET_OFFSET]

	// Pulse LCD so it takes the data we put on 18-21
    bl lcd_pulse_enable
    pop {r4, pc}

// Send one byte to the LCD screen
// r0 - Byte to send
lcd_send_byte:
	push {r4, lr}
	mov r4, r0
	lsl r0, r4, #4 // High nibble
	bl lcd_send_nibble

	mov r0, r4
	mov r4, #0x0F
	and r0, r4 // Low nibble
	bl lcd_send_nibble

	pop {r4, pc}


lcd_init:
    push {lr}

    ldr r2, =SIO_BASE
    ldr r3, =(1 << RS_PIN)
    str r3, [r2, #SIO_GPIO_OUT_CLR_OFFSET]

    // wair 50 ms after power up
    ldr r0, =50000
    bl delay_us

    // sending 0x03 to send back to 8 Bit mode
    mov r1, #0
    mov r0, #0x03
    bl lcd_send_nibble
    ldr r0, =5000          
    bl delay_us

    // sending 0x03 to send back to 8 Bit mode
    mov r0, #0x03
    bl lcd_send_nibble
    ldr r0, =200           
    bl delay_us

    // sending 0x03 to send back to 8 Bit mode
    mov r0, #0x03
    bl lcd_send_nibble
    ldr r0, =200
    bl delay_us

    // makes 4 bit mode waits 
    mov r0, #0x02
    bl lcd_send_nibble
    ldr r0, =200
    bl delay_us

    // send full bytes wait 50us after
    mov r1, #0
    mov r0, #0x28          
    bl lcd_send_byte
    ldr r0, =50
    bl delay_us

  // display on cusror off, blink off
    mov r0, #0x0C          
    bl lcd_send_byte
    ldr r0, =50
    bl delay_us


    // clear, data sheet says needs more than 1.52 ms
    mov r0, #0x01          
    bl lcd_send_byte
     ldr r0, =2000                                                    
    bl delay_us

    mov r0, #0x06          
    bl lcd_send_byte
    ldr r0, =50
    bl delay_us

    pop {pc}

lcd_write_char:
    push {lr}
    mov r1, #1
    bl lcd_send_byte
    pop {pc}
