// Nick Mankoski
    // Thomas Girotti
    // 5/7/2026
    // UMass Lowell EECE.3170 Microprocessors I
    // Project: RP2040-based Calculator in ARM Assembly

// Includes for named memory addresses from the datasheet
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

.equ RS_PIN, 16 // pin 21 // Like #define in C, register-select pin for the LCD
.equ E_PIN, 17 // pin 22 // Like #define in C, enable pin for the LCD
//kbd rows gpio 0-4
//kbd cols gpio 5-9

.equ KBD_ROW_MASK, 0x0000001F //gpio 0 -4 // Bitmask corresponding to GPIO 0-4
.equ KBD_COL_MASK, 0x000003E0 //gpio 5-9 // Mask for GPIO 5-9

pico_calc: // main // Main label
    bl gpio_init // Call gpio_init subroutine with link (inits GPIO pins)
    bl kbd_init // Call kbd_init subroutine wih link (sets up keypad stuff)
    bl lcd_init // Call lcd_init subroutine with link (sets up screen)
    bl clear_display // Call clear_display subroutine with link (clears the LCD screen)
    mov r2, #0 // r2 is the counter for _send_loop

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
    bl clear_display // clear the display after showing test num
    bl calc_reset // reset calc varibles to zero before starting main lool

main_loop: // Main program loop: Continuously scan keypad for button presses and display them on LCD
    bl scan_keyboard // Call keyboard scan subroutine
    cmp r0, #0xFF //seeing if button is pressed
    beq main_loop //if not pressed keeps gong

    bl calculator_handle_key //if key was pressed pass it to calc state machine

wait_for_button: // Subroutine to debounce a button
    ldr r0, =50000 //waits for button to bounce back so doesnt press twic
    bl delay_us // Delay by 50 * 10^3 us (50ms)

    bl scan_keyboard // Once delay is over, scan the keyboard again to get the currently pressed keys
    cmp r0, #0xFF // Are any buttons pressed?
    bne wait_for_button // Keep waiting for button to be released before continuing

    b main_loop // No more buttons are being pressed, so we can go back to main loop

scan_keyboard: // Test and scan keyboard subroutine (TODO: Nick Comments)
    push {r4-r7, lr} //save reg r4-r7 and link reg to stack
    ldr r4, =SIO_BASE // load sio base addres into r4 for gpio mainluatopn
    mov r5, #0 // init row counter r5 to 0

row_check: // lopp through to inreate each row of kbd
    mov r1, #0x1F //setting high
    str r1, [r4, #SIO_GPIO_OUT_SET_OFFSET] // drive all row pins high to reset their state

    mov r1, #1 // load base 1 for shifting
    lsl r1, r1, r5 //shift 1 left by the current row numer to select one spefici row
    str r1, [r4, #SIO_GPIO_OUT_CLR_OFFSET] 
    //current row low

    mov r0, #10 //set delay to 10 micro seconds
    bl delay_us //adding delay inbetween sweeps

    //read columns
    ldr r6, [r4, #SIO_GPIO_IN_OFFSET] // read current state of all pins
    ldr r7, =0x3E0 // load column mask gpio 5-9 into r7
    and r6, r6, r7 // bitwise and to isolate onlt the column pins states

    //check if col went low
    cmp r6, r7 // compare masked inputs to 0x3E0 all cols high unpressed
    beq next_row // if all cols are high no button was pressed go to next row
    // find what col went low
    mov r2, #5 // init col counter

col_check: //loop to fins which col went low
    mov r3, #1 // load bade 1 for shifing
    lsl r3, r3, r2 // shift 1 by current col numner to create a single bit mask
    tst r6, r3 // test if speicf col but in r6 is low
    beq key_pressed // r0 contains the key that is pressed 
    add r2, r2, #1 // otherwse incriment col counter
    cmp r2, #10 // check if all col are checked
    blt col_check // if not keep looping

next_row: // start next row iteratio
    add r5, #1 // increament row counter 
    cmp r5, #5 //checking to see if all 5 roes were checked
    blt row_check // if not keep checking
    mov r0, #0xFF //nothting prssed
    pop {r4-r7, pc} // restore reister and return to caller

key_pressed: //calc what key was pressed based on row col intersetion
    // index (row * 5) + (col - 5)
    mov r1, #0x1F // load row mask
    str r1, [r4, #SIO_GPIO_OUT_SET_OFFSET] // all high to reset matrix
    mov r0, r5 // move cur row num into r0
    mov r1, #5 //load 5 into 4 1
    mul r0, r1 // r0 = row * 5
    sub r2, r2, #5 // r2 = colpin - 5
    add r0, r0, r2 // r0 = row*5 + array indsxe
    ldr r1, =key_map //inset where we have all asci values
    ldrb r0, [r1, r0] // load ascii byte from array using calcuated index 
    pop {r4-r7, pc} // restore refister and return

kbd_init: // init kbd
    push {lr} // save link reg
    ldr r2, =PADS_BANK0_BASE // load memory base for kbd control
    mov r3, #5 // start counter at 5
kbd_loop: // loop to set up pu reistors on col
    mov r0, r3 //move current pin num ro r0
    lsl r0, #2 // muriply pin numer by 4 bc each pad reg is 4 pins wide
    add r0, #4 // add 4 to skip volrage selecte reg
    add r0, r2 // add base address to get final pad reg add for pin 
    mov r1, #0x48 //load 0x48 pu enable bit and input enable bit
    str r1, [r0] // store config into pad reg
    add r3, #1 // increament pin counter
    cmp r3, #9 // has it config up to pin 9?
    ble kbd_loop //if lese or equal to 9 keep looping
    pop {pc} // return to caller

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

// R3 - Pin to start
// R4 - Pin to end at inclusive
gpio_loop_data: // loops through range of pins to assign them to sio control
    push {lr} //save link reg

gpio_loop_data_loop:
    bl set_pin_sio //call funcrion to set r3 to sio function
    add r3, r3, #1 // move to next pin
    cmp r3, r4 // check if we have reached end pin
    ble gpio_loop_data_loop // if not loop again

    pop {pc} // return

// Select Function 5 (SIO) for GPIO pins
set_pin_sio: // maps a gpio pin to be controled by the sio block and not periphal
    push {r0-r1} // saves r0 and r1

    ldr r0, =(IO_BANK0_BASE + IO_BANK0_GPIO0_CTRL_OFFSET) // loads base addres of gpio0 control
    lsl r1, r3, #3 // mul each pin num by 8 bc each pin has 2 4 byte regs
    add r0, r0, r1 // add offset to base to get pins speifci control reg

    mov r1, #5 // 5 is mutlitplex vale for sio
    str r1, [r0] // write 5 to control reg

    pop {r0-r1} // restorr r0 and r1
    bx lr // return

// Delay for number of microseconds
// r0 - Contains the number of microseconds to stall 
// NOTE: This code is from Lecture ## TODO
delay_us:
    push {r1-r3} // Push r1-r3 onto the stack (we will overwrite them)
    ldr r2, =TIMER_BASE // r2 has the address of TIMER_BASE from datasheet
    ldr r1, [r2, #TIMER_TIMELR_OFFSET] // grab start time 
    add r1, r0 // add requested delsay to start time to get target end time
delay_wait: // busy wait loop
    ldr r3, [r2, #TIMER_TIMELR_OFFSET] // read cur time
    cmp r3, r1 // compare cur time with target and edn time
    blo delay_wait //if cur time is lower keep waiting
    pop {r1-r3} //restor reg once delay is finished 
    bx lr //return

// NOTE: This code was translated from Arias' C code (TODO: specify lines)
lcd_pulse_enable: // pulses the e pin on the lcd to latch data 
    push {r0-r2, lr} //save reg

    // Set Enable HI
    mov r0, #1 //load 1
    lsl r0, #E_PIN // shift to epin pos
    ldr r1, =(SIO_BASE + SIO_GPIO_OUT_SET_OFFSET) //load sio set reg
    str r0, [r1] // Set pin HI
    // Sleep 20us
    mov r0, #20 //load 20
    bl delay_us // wait 20 micro snter for screen to go high
    // Set Enable LO
    mov r0, #1 //load 1
    lsl r0, #E_PIN // shift to e pin pos
    ldr r1, =(SIO_BASE + SIO_GPIO_OUT_CLR_OFFSET) // load sio clr reg
    str r0, [r1] // Set pin LO
    // Sleep 50us
    mov r0, #50 // load 50
    bl delay_us // wait 50 ms

    pop {r0-r2, pc} // return

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

// R0 - Byte to send
// R1 - 0 for commands, 1 for data
// NOTE: This was taken from Arias' C code TODO
lcd_send_byte:
    push {r1-r4, lr} // TODO: This doesn't do what we want it to do

    mov r4, r1 // Copy is_data to r4
    // Clear RS
    mov r1, #1 // load 1
    lsl r1, #RS_PIN // shift to rs pin pos
    ldr r2, =(SIO_BASE + SIO_GPIO_OUT_CLR_OFFSET) // load sio clr reg
    str r1, [r2] // set rs pin to lo

    cmp r4, #0 // Is data (characters)?
    beq _lcd_send_byte_send_nibbles // This beq from the cmp from the start of the function before we push r1
    // Is data, set RS
    mov r1, #1 // load 1
    lsl r1, #RS_PIN // shift to rs pin pos
    ldr r2, =(SIO_BASE + SIO_GPIO_OUT_SET_OFFSET) // load sio set reg
    str r1, [r2] // set rs pin hi
_lcd_send_byte_send_nibbles:
    // Send high nibble
    mov r3, r0 // r3 has original byte
    lsr r0, #4 // Align high nibble
    bl lcd_send_nibble // send upper 4 bit

    mov r0, r3 // Copy original byte back into r0
    mov r1, #0x0F
    and r0, r1 // Mask off low nibble
    bl lcd_send_nibble // send lower 4 bit

    ldr r0, =500 // load 500 
    bl delay_us // wait 500 micro sec for screen to run

    pop {r1-r4, pc} // restore reg and return

lcd_init: // subroutine to init lcd in 4 bit mode
    push {lr} // save link reg

    ldr r2, =SIO_BASE // load sio base

    mov r3, #1 // load 1
    lsl r3, #RS_PIN // shifr to rs
    str r3, [r2, #SIO_GPIO_OUT_CLR_OFFSET] // drive rs low

    mov r3, #1 // load 1
    lsl r3, #E_PIN // shift to rs
    str r3, [r2, #SIO_GPIO_OUT_CLR_OFFSET] // drive enable low

    ldr r0, =50000 // load 50000
    bl delay_us // wait 50 ms for lcd power up

    mov r0, #0x03 // Send 0x03 nibble
    bl lcd_send_nibble
    ldr r0, =5000 // Load 5000
    bl delay_us // Wait 5ms

    mov r0, #0x03 // Send 0x03 nibble again
    bl lcd_send_nibble
    ldr r0, =5000 // Load 5000
    bl delay_us // Wait 5ms

    mov r0, #0x03 // Send 0x03 nibble a third time
    bl lcd_send_nibble
    ldr r0, =2000 // Load 2000
    bl delay_us // Wait 2ms

    mov r0, #0x02 // Send 0x02 nibble to lock screen into 4-bit mode
    bl lcd_send_nibble
    ldr r0, =2000 // Load 2000
    bl delay_us // Wait 2ms

    //now in 4 bit mode
    mov r0, #0x28 // comand 2 lines 5x8 font 4 bit mode
    mov r1, #0 // comand mode 
    bl lcd_send_byte // send commands

    mov r0, #0x0C // command display on cursor off blink off
    mov r1, #0 // send mode 
    bl lcd_send_byte // send commands

    mov r0, #0x01 // clear dispaly
    mov r1, #0 // comand mode
    bl lcd_send_byte // send comand 
    ldr r0, =2000 // load 2000
    bl delay_us // clear which needs 2 ms

    mov r0, #0x06 // comand enter mode set
    mov r1, #0 // commands mode
    bl lcd_send_byte // send command

    pop {pc} // return

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

// Precondition: r0 contains the number to display
// The number is 16 decimal digits or less
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

// Clears the display
// NOTE: From Arias' C code TODO: find attribution
clear_display:
    push {r0-r1, lr}

    mov r0, #0x01 // Clear display instruction
    mov r1, #0x00 // Command
    bl lcd_send_byte
    // Wait >1.52ms
    ldr r0, =1520
    bl delay_us

    pop {r0-r1, pc}

calc_reset: // subroutnit to rset all global calc state varibbles to zero
    push {r0-r1, lr} // save registers 

    mov r1, #0 // prepare a 0 to sore 

    ldr r0, =first_num // load add of first num
    str r1, [r0] // store 0 into first num 

    ldr r0, =second_num // load addres of second num 
    str r1, [r0] // store 0 into sceond num

    ldr r0, =calc_op // load add of calc op
    str r1, [r0] // store 0 into calc op

    ldr r0, =calc_state // load add into calc state 
    str r1, [r0] // store 0 into calc state

    pop {r0-r1, pc} // return

calculator_handle_key: // lofic touter for calc op based on what key was pressed 
    push {r4-r7, lr} // save reg

    mov r4, r0 // copy the pressed ascii char into r4

    cmp r4, #' ' // check if space key is prssed 
    beq calculator_done // if space ignore and exit

    cmp r4, #'0' // check if key ies less than asii 0
    blt calculator_check_operator // if less route to operator logic
    cmp r4, #'9' // chec if key is less than or equal to asii 9
    ble calculator_digit // if true route to digit logic

calculator_check_operator: // routing block for specif opeators
    cmp r4, #'+' // is it addation?
    beq calculator_operator // handle op

    cmp r4, #'-' // is it subtration?
    beq calculator_operator // handle op

    cmp r4, #'=' // is it equal sign?
    beq calculator_equals // handles equal logic

    b calculator_done // if none of abvoe ignore and exit

calculator_digit: // handles logic when num is pressed 
    ldr r5, =calc_state // load add of calc state
    ldr r6, [r5] // read current calc state into r6

    cmp r6, #2 // state 2 means it was prev = calcuation just finished 
    bne calculator_digit_continue // if not state 2 keep going

    bl clear_display // if state 2 and i type new num clear screen
    bl calc_reset // reset entier calc to fresh state 
    mov r6, #0 // froce state back to 0

calculator_digit_continue: //echo digit and append to cur building number
    mov r0, r4 // move the ascci digi back to r0
    mov r1, #1 // set flag to send data
    bl lcd_send_byte // echho the pressed digit to the lcd

    sub r2, r4, #'0' // convery asci to real numb

    cmp r6, #0 //check if we are in state 0
    beq calculator_append_first // beanch to load first num address

    ldr r0, =second_num //if in state 1 i am typuing second num load to addres 
    b calculator_append_digit // jump over first num logic

calculator_append_first: // setip for appsendin gthe first num 
    ldr r0, =first_num // load addres of first num

calculator_append_digit: // math logic to append digig value = val * 10 + new figi
    ldr r3, [r0] // load current sotr initer from moemry

    mov r7, r3 // copt current valye to r7 for mul trick
    lsl r3, r3, #3 // shif r3 lefr by 3
    lsl r7, r7, #1 // shift r7 left by 1
    add r3, r3, r7 // add thhem togther 
    add r3, r3, r2 // add new digit

    str r3, [r0] // store new combined valye into memory 

    b calculator_done // exit

calculator_operator: // logic when + - is presed 
    ldr r5, =calc_op // load add of calc op var
    str r4, [r5] // store the pressed ascii op inot memory

    ldr r5, =second_num // load add of second num
    mov r6, #0 // load 0
    str r6, [r5] // clear secvond num to precent carryng over old data

    ldr r5, =calc_state // load addres of calc state 
    mov r6, #1 // load 1 
    str r6, [r5] // update state

    mov r0, r4 // move op ascii char to r0
    mov r1, #1 // data flag
    bl lcd_send_byte // preint op to screen

    b calculator_done // exit

calculator_equals: // logic when = is pressed 
    ldr r5, =calc_op // load add of op valye 
    ldr r6, [r5] // load the store op

    cmp r6, #0 // check if ip is 0 nothing prssed yet 
    beq calculator_done // if no op equals doesn ntohign exit

    bl clear_display //clear screen to make room for final num 
    bl calculate_result // cal subrotue to do math
    bl display_signed_number // print the num handles negative formating

    b calculator_done // exit 

calculator_done: // exit lable for stat machine
    pop {r4-r7, pc} // restore reg and return

calculate_result: //prformes the math on store num and opeator
    push {r1-r5, lr} // save reg

    ldr r2, =first_num // load add of first num 
    ldr r0, [r2] // load value of fist num into r0

    ldr r3, =second_num // load value of second num
    ldr r1, [r3] // load value of second num into r1

    ldr r4, =calc_op // load add of op
    ldr r4, [r4] // load op char into r4

    cmp r4, #'+' // check if op is add
    beq calculate_add // jump to add logic

    cmp r4, #'-' // check if op is subtation
    beq calculate_subtract // jump to subtation logic

    b calculate_store // stores values

calculate_add: // add logic
    add r0, r0, r1 // 0 = first num + second num
    b calculate_store // go to store result

calculate_subtract: // subtration logic
    sub r0, r0, r1 //r0= fist num - second num 

calculate_store: // store rsult logic 
    str r0, [r2] // store result back into first num 

    mov r1, #0 // load 0 
    str r1, [r3] // clear second num var

    ldr r3, =calc_op // load add of op
    str r1, [r3] // clear op varaibe

    ldr r3, =calc_state // load add of calc state
    mov r1, #2 // state 2 means it is fibished 
    str r1, [r3] // store new state

    pop {r1-r5, pc} // resitor registe and return 

display_signed_number: // function to print num that are neg
    push {r4, lr} // save reg

    mov r4, r0 // cope the nuber to display into r4

    cmp r4, #0 // check if num >= 0
    bge display_signed_positive // if pos or zero keep going

    mov r0, #'-' // load asci minus sign
    mov r1, #1 // data flag
    bl lcd_send_byte // print the minus sign to screen

    mov r0, #0 // load 0 
    sub r0, r0, r4 // r0= 0- neg num
    bl display_number // call the unsighed displa subroune with pos verison

    b display_signed_done // exit

display_signed_positive: // postiv num bypass
    mov r0, r4 // move num back to r0
    bl display_number // prints 

display_signed_done: // exit point 
    pop {r4, pc} // restor reg and return

.data // Data section for variables we store in the binary
welcome: .ascii "Welcome!" // .ascii is a NOT null-terminated array of characters

.align 2
key_map: // the lookup table for our keypad
    .ascii "789  " //row 1
    .ascii "456  " //row 2
    .ascii "123- " //row 3
    .ascii "0=+  " //roe 4
    .ascii "     " //row 5

.align 2
first_num: // hold first num
    .word 0

second_num: // hold sceond num
    .word 0

calc_op: // hold ascii char of chose op
    .word 0

calc_state: // stat machine tracke 0 = first num , 1= second num, 2 = finished
    .word 0
