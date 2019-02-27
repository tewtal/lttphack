; Overworld music data
; Overwrites:
; LDA #$F5 : STA $00
; LDA #$9E : STA $01
; LDA #$1A : STA $02
org $008913
  LDX #$00 : JSL music_setup_bank
  NOP : NOP
  NOP : NOP
  NOP : NOP


; Underworld music data
; Overwrites:
; LDA #$00 : STA $00
; LDA #$80 : STA $01
; LDA #$1B
org $008925
  LDX #$01 : JSL music_setup_bank
  NOP : NOP
  NOP : NOP


; Ending credits music data
; Overwrites:
; LDA #$80 : STA $00
; LDA #$D3 : STA $01
; LDA #$1A
org $008931
  LDX #$02 : JSL music_setup_bank
  NOP : NOP
  NOP : NOP


org !ORG
; Used when turning on the console, so sound is correctly unmuted after selecting a file.
; This removes file screen music, but oh well.
music_init:
    LDX #$00 : JSL music_setup_bank
    LDA #$FF : STA $2140
 %ppu_off()
    JSR sound_loadsongbank
 %ppu_on()
    JSL $00893d
    RTL


; Sets up $00-03 with the address of the songbank to be loaded.
; Both $008888 (Sound_LoadSongBank) and sound_loadsongbank below can be used for this.
; Enter with X=0 for Overworld music, X=1 for Underworld and X=2 for Credits.
music_setup_bank:
  PHB : PHK : PLB
    LDA !ram_feature_music : ASL #4 : STA $00
    TXA : ASL #2 : CLC : ADC $00 : TAX

    LDA spc_data, X : STA $00
    LDA spc_data+1, X : STA $01
    LDA spc_data+2, X : STA $02
  PLB
    RTL


music_reload:
  %ai8()
    LDA $1B : TAX : JSL music_setup_bank

    SEI

    STZ $4200
    STZ $420C

    LDA #$FF : STA $2140

    JSR sound_loadsongbank

    CLI

    LDA $1B : STA $0136

    LDA #$81 : STA $4200

    LDA $0130 : CMP #$FF : BEQ .muted

    STA $012C : STZ $0133

  .muted

    RTL


; Taken from MoN's disassembly. It originated from Bank 0, which I can't JSR to from here.
;
; Loads SPC with data
sound_loadsongbank:
  PHP
  %ai16()

    LDY #$0000
    LDA #$BBAA

  .loop
    ; // Wait for the SPC to initialize to #$AABB
    CMP $2140 : BNE .loop

    %a8()
    LDA #$CC
    BRA .setup_transfer

  .begin_transfer

    LDA [$00], Y
    INY
    XBA
    LDA #$00
    BRA .write_zero_byte

  .continue_transfer
    XBA
    LDA [$00], Y ; Load the data byte to transmit.
    INY

    ; Are we at the end of a bank?
    CPY.w #$8000 : BNE .not_bank_end ; If not, then branch forward.

    LDY.w #$0000 ; Otherwise, increment the bank of the address at [$00]

    INC $02

  .not_bank_end

    XBA

  .wait_for_zero
    ; Wait for $2140 to be #$00 (we're in 8bit mode)
    CMP $2140 : BNE .wait_for_zero

    INC A ; Increment the byte count

  .write_zero_byte
    REP #$20

    ; Ends up storing the byte count to $2140 and the
    STA $2140

    SEP #$20 ; data byte to $2141. (Data byte represented as **)

    DEX : BNE .continue_transfer

  .synchronize
    ; We ran out of bytes to transfer.
    ; But we still need to synchronize.
    CMP $2140 : BNE .synchronize

  .no_zero ; At this point $2140 = #$01
    ; Add four to the byte count
    ADC #$03 : BEQ .no_zero ; (But Don't let A be zero!)

  .setup_transfer
  PHA
    REP #$20
    LDA [$00], Y : INY #2 : TAX ; Number of bytes to transmit to the SPC.
    LDA [$00], Y : INY #2 : STA $2142 ; Location in memory to map the data to.
    SEP #$20
    CPX.w #$0001 ; If the number of bytes left to transfer > 0...

    ; Then the carry bit will be set
    ; And rotated into the accumulator (A = #$01)
    ; NOTE ANTITRACK'S DOC IS WRONG ABOUT THIS!!!
    ; He mistook #$0001 to be #$0100.
    LDA #$00 : ROL A : STA $2141 : ADC #$7F

    ; Hopefully no one was confused.
  PLA
    STA $2140

  .transfer_init_wait

    ; Initially, a 0xCC byte will be sent to initialize
    ; The transfer.
    ; If A was #$01 earlier...
    CMP $2140 : BNE .transfer_init_wait : BVS .begin_transfer

    STZ $2140 : STZ $2141 : STZ $2142 : STZ $2143
  PLP
    RTS

spc_data:
    dl $1B8000 : db $00 ; overworld
    dl $1A9EF5 : db $00 ; underworld
    dl $1AD380 : db $00 ; credits
    dl $000000 : db $00 ; unused

    dl !SPC_DATA_OVERWORLD : db $00 
    dl !SPC_DATA_UNDERWORLD : db $00
    dl !SPC_DATA_CREDITS : db $00
    dl $000000 : db $00 ; unused

incsrc "musicvolumes.asm"
