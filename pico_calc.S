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
#include "hardware/regs/i2c.h" // I2C block registers and bits
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

// Set up I2C registers and enable its functionality
setup_i2c:
	push {r0-r3}
	// Set I2C pins
	ldr r0, =(IO_BANK0_BASE + IO_BANK0_GPIO4_CTRL_OFFSET)
	ldr r1, =(IO_BANK0_GPIO4_CTRL_FUNCSEL_BITS & (IO_BANK0_GPIO4_CTRL_FUNCSEL_VALUE_I2C0_SDA << IO_BANK0_GPIO4_CTRL_FUNCSEL_MSB))
	str r1, [r0]

	ldr r0, =(IO_BANK0_BASE + IO_BANK0_GPIO5_CTRL_OFFSET)
	ldr r1, =(IO_BANK0_GPIO5_CTRL_FUNCSEL_BITS & (IO_BANK0_GPIO5_CTRL_FUNCSEL_VALUE_I2C0_SCL << IO_BANK0_GPIO5_CTRL_FUNCSEL_MSB))
	str r1, [r0]
	// Enable pull-up resistors
	ldr r2, =(PADS_BANK0_BASE + PADS_BANK0_GPIO0_OFFSET)
	ldr r0, [r2]
	ldr r1, =(PADS_BANK0_GPIO0_PDE_BITS)
	mvn r1, r1
	and r0, r1 // Turn off PDE
	ldr r1, =(PADS_BANK0_GPIO0_PUE_BITS)
	orr r0, r1 // Turn on PUE
	str r0, [r2]


	// 4.3.10.2 Master Operation
	// Make sure IP block disabled before configuring
	ldr r0, =(I2C0_BASE + I2C_IC_ENABLE_OFFSET)
	ldr r1, =(I2C_IC_ENABLE_ENABLE_BITS | I2C_IC_ENABLE_ENABLE_VALUE_DISABLED)
	str r1, [r0]

	// Configure I2C
	// Per datasheet, slave master must be enabled and slave must be disabled (diff bits)
	ldr r0, =(I2C0_BASE + I2C_IC_CON_OFFSET)
	ldr r1, =(I2C_IC_CON_RESET)
	str r1, [r0]
	ldr r1, =(I2C_IC_CON_MASTER_MODE_BITS & I2C_IC_CON_MASTER_MODE_VALUE_ENABLED)
	add r1, #(I2C_IC_CON_SPEED_VALUE_STANDARD << I2C_IC_CON_SPEED_MSB)
	add r1, #(I2C_IC_CON_IC_SLAVE_DISABLE_VALUE_SLAVE_DISABLED << I2C_IC_CON_IC_SLAVE_DISABLE_MSB)
	@ ldr r1, =( \
	@ 	() | \
	@ 	(I2C_IC_CON_SPEED_BITS & ()) |  \
	@ 	(I2C_IC_CON_IC_SLAVE_DISABLE_BITS & (I2C_IC_CON_IC_SLAVE_DISABLE_VALUE_SLAVE_DISABLED << I2C_IC_CON_IC_SLAVE_DISABLE_MSB)))
	str r1, [r0]

	// Set our own address and target address
	ldr r0, =(I2C0_BASE + I2C_IC_TAR_OFFSET)
	ldr r1, =(I2C_IC_TAR_IC_TAR_BITS & (LCD_ADDR << I2C_IC_TAR_IC_TAR_MSB))

	// Enable I2C
	ldr r0, =(I2C0_BASE + I2C_IC_ENABLE_OFFSET)
	ldr r1, =(I2C_IC_ENABLE_ENABLE_BITS & I2C_IC_ENABLE_ENABLE_VALUE_ENABLED)
	str r1, [r0]

	pop {r0-r3}
	bx lr

// Sends test characters to I2C bus
send_test_data:
	push {r0-r3}
	// From datasheet
	ldr r0, =(I2C0_BASE + I2C_IC_DATA_CMD_OFFSET) // Command register
	// Set to write data
	ldr r1, =(I2C_IC_DATA_CMD_CMD_BITS & (I2C_IC_DATA_CMD_CMD_VALUE_WRITE << I2C_IC_DATA_CMD_CMD_MSB))
	add r1, #0x30 // Set to 8 bit mode, write
	str r1, [r0] // Actually send the bits

	bl loop_until_tx_fifo_empty
	// Turn display on
	ldr r1, =(I2C_IC_DATA_CMD_CMD_BITS & (I2C_IC_DATA_CMD_CMD_VALUE_WRITE << I2C_IC_DATA_CMD_CMD_MSB))
	add r1, #0xE
	bl toggle_led

	str r1, [r0]
	bl toggle_led


	bl loop_until_tx_fifo_empty
	bl toggle_led

	pop {r0-r3}
	bx lr

loop_until_tx_fifo_empty:
	push {r0-r1, lr}

	ldr r0, =(I2C0_BASE + I2C_IC_TXFLR_OFFSET)
loop_until_tx_fifo_empty_loop:
	ldr r1, [r0]
	cmp r1, #0
	bl delay
	bl toggle_led
	bne loop_until_tx_fifo_empty_loop

	pop {r0-r1, pc}

//
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