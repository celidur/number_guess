PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
T1CL = $6004
T1CH = $6005
ACR = $600B
IFR = $600D
IER = $600E

E  = %10000000
RW = %01000000
RS = %00100000

ticks = $00 ; 4 bytes
ptr = $04 ; 2 bytes
lcd_toggle_time = $06 ; 1 byte
buttom_toggle_time = $07 ; 1 byte
guess_number = $08 ; 1 byte
choice = $09 ; 1 byte
delay = $0A ; 1 byte
mode = $0B ; 1 byte
tmp = $0C ; 1 byte

value = $0200 ; 2 bytes
mod10 = $0202 ; 2 bytes
message = $0204 ; 16 bytes

    .org $8000
message_start: .asciiz "Press start to  begin"
message_select: .asciiz "L - dec/R + inc Select when done"
message_increase: .asciiz "Is Bigger"
message_decrease: .asciiz "Is Smaller"
message_equal: .asciiz "You Win !"

reset:
    lda #%11111111 ; Set all pins on port B to output
    sta DDRB
    lda #%11100001 ; Set top 3 pins on port A to output and the last for led
    sta DDRA
    jsr init_timer

    lda #%00111000 ; Set 8-bit mode; 2-line display; 5x8 font
    jsr lcd_instruction
    lda #%00001100 ; Display on; cursor off; blink off
    jsr lcd_instruction
    lda #%00000110 ; Increment and shift cursor; don't shift display
    jsr lcd_instruction
    jsr clear_lcd

    lda #0 
    sta PORTA
    sta lcd_toggle_time
    sta buttom_toggle_time
    sta choice
    sta mode

    ; store message_start address in ptr
    lda #<message_start
    sta ptr
    lda #>message_start
    sta ptr + 1
    jsr cpy_string
    jsr print

loop_start:
    lda PORTA
    and #%00010000
    beq loop_start

    lda ticks
    sta guess_number
    lda #<message_select
    sta ptr
    lda #>message_select
    sta ptr + 1
    jsr cpy_string
    jsr print
    lda #200
    sta delay
    jsr delay_f
    lda #1
    sta mode

loop:
    jsr update_buttom
    lda tmp
    bne loop
    lda choice
    sta value
    lda #0
    sta value + 1
    jmp update_lcd_number
    jmp loop

init_timer:
    lda #0
    sta ticks
    sta ticks + 1
    sta ticks + 2
    sta ticks + 3
    lda #%01000000 ; Enable timer 1
    sta ACR
    lda #$02 
    sta T1CL
    lda #$27 ; Set timer 0x2702 => 1ms
    sta T1CH
    lda #%11000000 ; Enable timer 1 interrupt
    sta IER
    cli
    rts

update_lcd_number:
    sec 
    lda ticks
    sbc lcd_toggle_time
    cmp #20  ; 20ms
    bcc exit_update_lcd
    jsr print_number
    lda ticks
    sta lcd_toggle_time
exit_update_lcd:
    jmp loop

update_buttom:
    lda #0
    sta tmp
    sec 
    lda ticks
    sbc buttom_toggle_time
    cmp #13  ; 13ms
    bcc exit_update_buttom
    lda ticks
    sta buttom_toggle_time
    lda PORTA
    and #%00001110
    cmp #%00000010
    beq right
    cmp #%00001000
    beq left
    cmp #%00000100
    beq select
    lda #1
    sta tmp
    rts
right:
    inc choice
    rts
left:
    dec choice
    rts
select:
    lda choice
    cmp guess_number
    beq equal
    cmp guess_number
    bcc increase
decrease:
    lda #<message_decrease
    sta ptr
    lda #>message_decrease
    sta ptr + 1
    jmp exit_update_buttom2
equal:
    lda #<message_equal
    sta ptr
    lda #>message_equal
    sta ptr + 1
    jsr cpy_string
    jsr print
    jmp infinity_loop
increase:
    lda #<message_increase
    sta ptr
    lda #>message_increase
    sta ptr + 1
exit_update_buttom2:
    jsr cpy_string
    jsr print
    lda #100
    sta delay
    jsr delay_f
exit_update_buttom:
    rts

cpy_string:  ; the address of the string is in ptr
    ldy #0
loop_cpy:
    lda (ptr),y
    beq end_cpy
    sta message,y
    iny
    jmp loop_cpy
end_cpy:
    lda #0
    sta message,y ; add null terminator
    rts

print_number: ; for 2 bits number
    lda #0 
    sta message
divide:
    ; Initialize the remainder to zero
    lda #0
    sta mod10
    sta mod10 + 1
    clc
    ldx #16

divloop:
    ; Rotate quotient and remainder
    rol value
    rol value + 1
    rol mod10
    rol mod10 + 1
    ; a,y = dividend - devisor
    sec
    lda mod10
    sbc #10
    tay ; save low byte in Y
    lda mod10+1
    sbc #0
    bcc ignore_result ; branch if dividend < devisor
    sty mod10
    sta mod10 + 1

ignore_result:
    dex
    bne divloop
    rol value ; shift in the last bit of the quotient
    rol value + 1

    lda mod10
    clc
    adc #"0"
    pha
    inc message

    lda value
    ora value + 1
    bne divide ; branch if value not equal to 0
    lda message
    tax
    ldy #0
divloop2:
    pla
    sta message,y
    iny
    dex
    bne divloop2 
    txa
    sta message,y

print:
    jsr clear_lcd
    ldx #0
loop_print:
    lda message,x
    beq end_print
    jsr print_char
    inx
    cpx #16
    bne loop_print
    lda #%11000000 ; Set cursor to second line
    jsr lcd_instruction
    jmp loop_print
end_print:
    rts

print_char:
    jsr lcd_wait
    sta PORTB
    lda #RS         ; Set RS; Clear RW/E bits
    sta PORTA
    lda #(RS | E)   ; Set E bit to send instruction
    sta PORTA
    lda #RS         ; Clear E bits
    sta PORTA
    rts

clear_lcd:
    lda #%00000010 ; Retrun home
    jsr lcd_instruction
    lda #%00000001 ; Clear display
    jsr lcd_instruction
    rts

lcd_wait:
    pha
    lda #%00000000  ; Port B is input
    sta DDRB
lcdbusy:
    lda #RW
    sta PORTA
    lda #(RW | E)
    sta PORTA
    lda PORTB
    and #%10000000
    bne lcdbusy

    lda #RW
    sta PORTA
    lda #%11111111  ; Port B is output
    sta DDRB
    pla
    rts

lcd_instruction:
    jsr lcd_wait
    sta PORTB
    lda #0         ; Clear RS/RW/E bits
    sta PORTA
    lda #E         ; Set E bit to send instruction
    sta PORTA
    lda #0         ; Clear RS/RW/E bits
    sta PORTA
    rts

delay_f:
    lda ticks
    adc delay
    sta delay
delay_loop:
    lda ticks
    cmp delay
    bne delay_loop
    rts

infinity_loop:
    lda #1 
    sta PORTA
    jmp infinity_loop

irq:
    pha
    bit T1CL
    inc ticks
    bne end_irq
    inc ticks + 1
    bne end_irq
    inc ticks + 2
    bne end_irq
    inc ticks + 3
end_irq:
    pla
    rti

  .org $fffc
  .word reset
  .word irq
