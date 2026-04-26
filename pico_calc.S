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

	// 4.3.10.2 Master Operation
	// Make sure IP block disabled before configuring
	ldr r0, =(I2C0_BASE + I2C_IC_ENABLE_OFFSET)
	ldr r1, =(I2C_IC_ENABLE_ENABLE_BITS | I2C_IC_ENABLE_ENABLE_VALUE_DISABLED)
	str r1, [r0]

	// Configure I2C
	// Per datasheet, slave master must be enabled and slave must be disabled (diff bits)
	ldr r0, =(I2C0_BASE + I2C_IC_CON_OFFSET)
	ldr r1, =(
		(I2C_IC_CON_MASTER_MODE_BITS & I2C_IC_CON_MASTER_MODE_VALUE_ENABLED) |
		(I2C_IC_CON_SPEED_BITS & I2C_IC_CON_SPEED_VALUE_STANDARD) | 
		(I2C_IC_CON_IC_SLAVE_DISABLE_BITS & I2C_IC_CON_IC_SLAVE_DISABLE_VALUE_SLAVE_DISABLED) |
	)

	// Enable I2C
	ldr r0, =(I2C0_BASE + I2C_IC_ENABLE_OFFSET)
	ldr r1, =(I2C_IC_ENABLE_ENABLE_BITS | I2C_IC_ENABLE_ENABLE_VALUE_ENABLED)
	str r1, [r0]

	pop {r0-r3}
	bx lr

// Sends test characters to I2C bus
send_test_data:
	bx lr
