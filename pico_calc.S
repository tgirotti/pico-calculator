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

pico_calc:
	bl setup_i2c
	bl send_test_data

idle:
	b idle


// Set up I2C registers and enable its functionality
setup_i2c:
	push {r0-r3}
	// Set I2C pins
	ldr r0, =(IO_BANK0_BASE + IO_BANK0_GPIO26_CTRL_OFFSET)
	ldr r1, =(IO_BANK0_GPIO6_CTRL_FUNCSEL_BITS & IO_BANK0_GPIO6_CTRL_FUNCSEL_VALUE_I2C0_SDA)
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
	ldr r1, =(
		(I2C_IC_CON_MASTER_MODE_BITS & I2C_IC_CON_MASTER_MODE_VALUE_ENABLED) |
		(I2C_IC_CON_SPEED_BITS & I2C_IC_CON_SPEED_VALUE_STANDARD) | 
		(I2C_IC_CON_IC_SLAVE_DISABLE_BITS & I2C_IC_CON_IC_SLAVE_DISABLE_VALUE_SLAVE_DISABLED) |
	)
	str r1, [r0]

	// Set our own address and target address
	ldr r0, =(I2C0_BASE + I2C_IC_TAR_OFFSET)
	ldr r1, =(I2C_IC_TAR_IC_TAR_BITS & lcd_addr)

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
	ldr r0, =(0000110000b) // Set to 8 bit operation and select 1-line display
	ldr r0, =(0000001110b)
	pop {r0-r3}
	bx lr

.data
lcd_addr: .byte 0x3f
clear_disp: .byte 0x01

