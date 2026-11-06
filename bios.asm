; OpenFamiDisk 6502 BIOS
; SPDX-License-Identifier: Apache-2.0

PPUCTRL = $2000
PPUMASK = $2001
PPUSTATUS = $2002
PPUADDR = $2006
PPUDATA = $2007
MASTERIO = $4023
DISKCTRL = $4025
DISKSTATUS = $4030
DISKDATA = $4031
DRIVE = $4032

ptr = $00
list = $02
remaining = $06
bootid = $08
selected = $09
dest = $0a
length = $0c
loaded = $0e
fault = $0f
fileid = $10
area = $11
scratch = $12
frame = $14

FILLVALUE $ff
ORG $e000

PAD $e149
Delay131:
    ldx #$2b
@loop:
    dex
    bne @loop
    rts

PAD $e153
Delayms:
    jsr Delay131
    dey
    bne Delayms
    rts

PAD $e18b
NMI:
    bit $0100
    bmi @third
    bvs @first
    pha
    inc frame
    pla
    rti
@first:
    jmp ($dff6)
@third:
    bvc @second
    jmp ($dffa)
@second:
    jmp ($dff8)

PAD $e1b2
VINTWait:
    jmp VINTWaitImpl

PAD $e1c7
IRQ:
    bit $0101
    bmi @high
    pha
    lda DISKSTATUS
    pla
    rti
@high:
    bvc @ack
    jmp ($dffe)
@ack:
    pha
    lda DISKSTATUS
    pla
    rti

PAD $e1f8
LoadFiles:
    tsx
    lda $0101,x
    sta scratch
    lda $0102,x
    sta scratch+1
    clc
    lda scratch
    adc #4
    sta $0101,x
    lda scratch+1
    adc #0
    sta $0102,x
    ldy #1
    lda (scratch),y
    sta ptr
    iny
    lda (scratch),y
    sta ptr+1
    iny
    lda (scratch),y
    sta list
    iny
    lda (scratch),y
    sta list+1
    jmp LoadEngine

PAD $e237
AppendFile:
    lda #$03
PAD $e239
WriteFile:
    jmp UnsupportedWrite
PAD $e2b7
CheckFileCount:
    jmp UnsupportedWrite
PAD $e2bb
AdjustFileCount:
    jmp UnsupportedWrite
PAD $e301
SetFileCount1:
    jmp UnsupportedWrite
PAD $e305
SetFileCount:
    jmp UnsupportedWrite
PAD $e32a
GetDiskInfo:
    lda #$01
    rts
PAD $e3da
AddYtoPtr0A:
    tya
    clc
    adc dest
    sta dest
    bcc @done
    inc dest+1
@done:
    rts
PAD $e3e7
GetHardCodedPointers:
    jmp UnsupportedWrite
PAD $e3ea
GetHardCodedPointersWriteProtected:
    jmp UnsupportedWrite
PAD $e445
CheckDiskHeader:
    jmp UnsupportedWrite
PAD $e484
GetNumFiles:
    jmp UnsupportedWrite
PAD $e492
SetNumFiles:
    jmp UnsupportedWrite
PAD $e4a0
FileMatchTest:
    jmp UnsupportedWrite
PAD $e4da
SkipFiles:
    jmp UnsupportedWrite
PAD $e4f9
LoadData:
    jmp UnsupportedWrite
PAD $e506
ReadData:
    jmp UnsupportedWrite
PAD $e5b5
SaveData:
    jmp UnsupportedWrite
PAD $e64d
WaitForDriveReady:
    lda DRIVE
    and #1
    rts
PAD $e685
StopMotor:
    lda #$2e
    sta $fa
    sta DISKCTRL
    rts
PAD $e68f
CheckBlockType:
    jmp UnsupportedWrite
PAD $e6b0
WriteBlockType:
    jmp UnsupportedWrite
PAD $e6e3
StartXfer:
    jmp UnsupportedWrite
PAD $e706
EndOfBlockRead:
    jmp UnsupportedWrite
PAD $e729
EndOfBlkWrite:
    jmp UnsupportedWrite
PAD $e778
XferDone:
    jmp StopMotor
PAD $e794
Xfer1stByte:
    jmp ReadByte
PAD $e7a3
XferByte:
    jmp ReadByte
PAD $e7bb
VRAMStructWrite:
    rts
PAD $e844
FetchDirectPtr:
    rts
PAD $e86a
WriteVRAMBuffers:
    rts
PAD $e8b3
ReadIndividualVRAMBytes:
    rts
PAD $e8d2
PrepareVRAMString:
    rts
PAD $e8e1
PrepareVRAMStrings:
    rts
PAD $e94f
GetVRAMBufferByte:
    rts
PAD $e97d
Pixel2NamConv:
    rts
PAD $e997
Nam2PixelConv:
    rts
PAD $e9b1
Random:
    lda frame
    eor $01
    rol a
    sta $01
    rts
PAD $e9c8
SpriteDMA:
    lda #0
    sta $2003
    lda #2
    sta $4014
    rts
PAD $e9d3
CounterLogic:
    rts
PAD $e9eb
ReadPads:
    rts
PAD $ea1a
ReadDownPads:
    rts
PAD $ea1f
ReadOrDownPads:
    rts
PAD $ea36
ReadDownVerifyPads:
    rts
PAD $ea4c
ReadOrDownVerifyPads:
    rts
PAD $ea68
ReadDownExpPads:
    rts
PAD $ea84
VRAMFill:
    rts
PAD $ead2
MemFill:
    jmp MemFillImpl
PAD $eaea
SetScroll:
    jmp SetScrollImpl
PAD $eafd
JumpEngine:
    jmp JumpEngineImpl
PAD $eb13
ReadKeyboard:
    rts
PAD $ebaf
LoadTileset:
    rts
PAD $ec22
UnknownEC22:
    rts
PAD $ee17
StartMotor:
    lda #$6d
    sta $fa
    sta DISKCTRL
    rts

PAD $ee30
MemFillImpl:
    sty ptr+1
    pha
@page:
    ldy #0
    sty ptr
    pla
    pha
@byte:
    sta (ptr),y
    iny
    bne @byte
    lda ptr+1
    cmp #0
    beq @done
    dec ptr+1
    cpx ptr+1
    bcc @page
    beq @page
@done:
    pla
    rts
SetScrollImpl:
    lda PPUSTATUS
    lda $fd
    sta $2005
    lda $fc
    sta $2005
    lda $ff
    sta PPUCTRL
    rts
JumpEngineImpl:
    sec
    rol a
    tay
    pla
    sta ptr
    pla
    sta ptr+1
    lda (ptr),y
    tax
    iny
    lda (ptr),y
    sta ptr+1
    stx ptr
    jmp (ptr)

VINTWaitImpl:
    pha
    lda $0100
    pha
    lda #0
    sta $0100
    lda $ff
    ora #$80
    sta $ff
    sta PPUCTRL
    lda frame
@wait:
    cmp frame
    beq @wait
    lda $ff
    and #$7f
    sta $ff
    sta PPUCTRL
    pla
    sta $0100
    pla
    rts

Reset:
    sei
    cld
    ldx #$ff
    txs
    lda #0
    sta PPUCTRL
    sta $4022
    sta MASTERIO
    sta frame
    lda #$06
    sta $fe
    sta PPUMASK
    lda #$10
    sta $ff
    sta PPUCTRL
    lda #$c0
    sta $0100
    lda #$80
    sta $0101
    lda #$7d
    sta $0300
    lda #0
    sta $0301
    lda #$ff
    sta $0302
    lda #$83
    sta MASTERIO
    lda $0102
    cmp #$35
    bne @boot
    lda $0103
    cmp #$ac
    beq @resume
    cmp #$53
    bne @boot
@resume:
    cli
    jmp ($dffc)
@boot:
    jsr LoadFiles
    dw BootDiskID
    dw BootList
    bne @boot
    lda #$35
    sta $0102
    lda #$ac
    sta $0103
    cli
    jmp ($dffc)

BootDiskID:
    db $ff,$ff,$ff,$ff,$ff,$ff,0,0,$ff,$ff
BootList:
    db $ff
Signature:
    db "*NINTENDO-HVC*"

UnsupportedWrite:
    lda #$03
    rts

LoadEngine:
    lda #0
    sta loaded
    sta fault
    lda DRIVE
    and #1
    beq @present
    jmp @nodisk
@present:
    jsr StartMotor
    lda #1
    jsr ExpectBlock
    beq @info
    jmp @finish
@info:
    ldy #0
@diskinfo:
    jsr ReadByte
    cpy #14
    bcs @compareid
    cmp Signature,y
    beq @nextinfo
    lda #$21
    sta fault
    jmp @nextinfo
@compareid:
    cpy #24
    bcs @bootid
    tax
    tya
    sec
    sbc #14
    tay
    txa
    cmp (ptr),y
    beq @matched
    lda (ptr),y
    cmp #$ff
    beq @matched
    lda #$04
    sta fault
@matched:
    tya
    clc
    adc #14
    tay
    jmp @nextinfo
@bootid:
    cpy #24
    bne @nextinfo
    sta bootid
@nextinfo:
    iny
    cpy #55
    bne @diskinfo
    jsr SkipCRC
    lda fault
    beq @count
    jmp @finish
@count:
    lda #2
    jsr ExpectBlock
    beq @countbyte
    jmp @finish
@countbyte:
    jsr ReadByte
    sta remaining
    jsr SkipCRC
@files:
    lda remaining
    bne @header
    jmp @finish
@header:
    lda #3
    jsr ExpectBlock
    beq @headerbytes
    jmp @finish
@headerbytes:
    jsr ReadByte
    jsr ReadByte
    sta fileid
    lda #$ff
    sta selected
    ldy #0
    lda (list),y
    cmp #$ff
    bne @explicit
    lda bootid
    cmp fileid
    bcc @unselected
    beq @select
    bcs @select
@explicit:
    ldy #0
@search:
    lda (list),y
    cmp fileid
    beq @select
    cmp #$ff
    beq @unselected
    iny
    cpy #20
    bne @search
    beq @unselected
@select:
    lda #0
    sta selected
@unselected:
    ldy #0
@name:
    jsr ReadByte
    iny
    cpy #8
    bne @name
    jsr ReadByte
    sta dest
    jsr ReadByte
    sta dest+1
    jsr ReadByte
    sta length
    jsr ReadByte
    sta length+1
    jsr ReadByte
    sta area
    bne @readheaderend
    lda selected
    bne @readheaderend
    lda dest+1
    cmp #$20
    bcc @lowmemory
    cmp #$60
    bcc @reject
    cmp #$e0
    bcc @readheaderend
    jmp @reject
@lowmemory:
    and #$07
    cmp #$02
    bcs @readheaderend
@reject:
    lda #$ff
    sta selected
@readheaderend:
    jsr SkipCRC
    lda #4
    jsr ExpectBlock
    bne @finish
    lda selected
    bne @data
    lda area
    beq @data
    lda PPUSTATUS
    lda dest+1
    sta PPUADDR
    lda dest
    sta PPUADDR
@data:
    lda length
    ora length+1
    beq @dataend
    jsr ReadByte
    ldy selected
    bne @advance
    ldy area
    bne @ppu
    ldy #0
    sta (dest),y
    jmp @increment
@ppu:
    sta PPUDATA
    jmp @advance
@increment:
    inc dest
    bne @advance
    inc dest+1
@advance:
    lda length
    bne @low
    dec length+1
@low:
    dec length
    jmp @data
@dataend:
    jsr SkipCRC
    lda selected
    bne @skipcount
    inc loaded
@skipcount:
    dec remaining
    jmp @files
@nodisk:
    lda #1
    sta fault
@finish:
    jsr StopMotor
    ldy loaded
    lda fault
    rts

ExpectBlock:
    sta scratch
@scan:
    jsr ReadByte
    ldx fault
    bne @failed
    cmp scratch
    beq @ok
    cmp #0
    beq @scan
    lda #$22
    sta fault
    rts
@ok:
    lda #0
@failed:
    lda fault
    rts

SkipCRC:
    jsr ReadByte
    jmp ReadByte

ReadByte:
@wait:
    lda DISKSTATUS
    bmi @ready
    and #$40
    bne @eof
    lda DRIVE
    and #1
    beq @wait
    lda #1
    sta fault
    lda #0
    rts
@eof:
    lda #$28
    sta fault
    lda #0
    rts
@ready:
    lda DISKDATA
    rts

PAD $fffa
    dw NMI,Reset,IRQ
