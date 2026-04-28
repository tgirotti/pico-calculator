	// Nick Mankoski
	// Thomas Girotti
	// 4/26/2026
	// UMass Lowell EECE.3170 Microprocessors I
	// Project: RP2040-based Calculator in ARM Assembly
	
	.global pico_calc
    .type pico_calc, %function
#include "pico/asm_helper.S" // Named memory-mapped registers
#include "hardware/regs/io_bank0.h" // IO Bank registers
#include "hardware/regs/timer.h" // Timer registers
#include "hardware/regs/sio.h" // SIO registers
#include "hardware/regs/intctrl.h" // Interrupt registers/bits
#include "hardware/regs/m0plus.h" // Cortex-M0+ registers (interrupt regs, etc.)
#include "hardware/regs/pads_bank0.h" // Pad control registers
#define LCD_ADDR 0x3f

pico_calc:
	bl setup_i2c
	bl setup_led
	bl send_test_data

idle:
	b idle


setup_led:
	movs	r4, #1
	lsl		r4, r4, #18
	// r5: mask for on-board LED (GP25)
	movs	r5, #1
	lsl		r5, r5, #25
	
	// GPIO25 -> SIO output
	ldr		r0, =(IO_BANK0_BASE+IO_BANK0_GPIO25_CTRL_OFFSET)
	movs	r1, #5			// Func5 => SIO
	str		r1, [r0, #0]
// Enable GP25 (r5 mask) as output
	ldr		r0, =(SIO_BASE+SIO_GPIO_OE_SET_OFFSET)
	str		r5, [r0, #0]
toggle_led:
	// r5 = GP25 mask 
	push {r2}
	ldr r2, =(SIO_BASE+SIO_GPIO_OUT_XOR_OFFSET)
	str	r5, [r2, #0] // Toggle LED
	pop {r2}
	bx lr

delay:
	push	{r0-r3, r6}
	ldr     r1, =(TIMER_BASE+TIMER_TIMERAWL_OFFSET)    // TIMERAWL = TIMER_BASE (0x40054000) + offset (0x28) 
	ldr     r2, [r1, #0]    // read the time value
	ldr r6, =delay_setting
	ldr r6, [r6]
delay_loop:
	ldr     r3, [r1, #0]
	sub     r3, r3, r2      // r3 = delta
    cmp     r3, r6          // see r3 is the desired delay value in r0
	blt     delay_loop
	pop	{r0-r3, r6}

.data
clear_disp: .word 0x01
delay_setting: .word 25000