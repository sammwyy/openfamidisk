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
blockready = $15
loadingactive = $16
loadingtransfer = $17
boxlow = $18
boxhigh = $19
cueframe = $1a
cueindex = $1b
staroffset = $1c
starindex = $1d
starrow = $1e

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
    pha
    lda loadingactive
    beq @game
    lda $0102
    cmp #$35
    beq @game
    pla
    jmp LoadingNMI
@game:
    pla
    bit $0100
    bmi @third
    bvs @first
    inc frame
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
    lda #$2e
    sta DISKCTRL
    lda #$ed
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
    sta loadingactive
    sta loadingtransfer
    sta cueframe
    sta cueindex
    sta $4010
    lda #$c0
    sta $4017
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
    lda #0
    sta $0102
    jsr ShowLoading
@retry:
    jsr LoadFiles
    dw BootDiskID
    dw BootList
    bne @retry
    jsr HideLoading
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
    php
    sei
    lda #0
    sta loaded
    sta fault
    sta blockready
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
    beq @blockdata
    jmp @finish
@blockdata:
    lda selected
    bne @data
    lda area
    beq @data
    ldx loadingactive
    beq @ppuaddr
    stx loadingtransfer
    ldx #$06
    stx $fe
    stx PPUMASK
@ppuaddr:
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
    lda loadingactive
    beq @skiploading
    lda selected
    bne @skiploading
    lda area
    beq @skiploading
    cmp #1
    bne @showloading
    jsr SaveLoadingTiles
    jsr DrawLoadingFont
@showloading:
    lda PPUSTATUS
    lda #0
    sta $2005
    sta $2005
    lda $ff
    sta PPUCTRL
    lda #$0a
    sta $fe
    sta PPUMASK
    lda #0
    sta loadingtransfer
@skiploading:
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
    plp
    lda fault
    rts

ExpectBlock:
    sta scratch
    lda blockready
    bne @next
    inc blockready
    jmp @scan
@next:
    lda $fa
    and #$bf
    sta DISKCTRL
    lda $fa
    sta DISKCTRL
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
    sta scratch+1
    and #2
    bne @ready
    lda scratch+1
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

ShowLoading:
    ldx #2
@vblank:
    lda PPUSTATUS
    bpl @vblank
    dex
    bne @vblank
    jsr SaveLoadingTiles
    jsr DrawLoadingFont
    lda PPUSTATUS
    lda #$3f
    sta PPUADDR
    lda #0
    sta PPUADDR
    ldx #0
@palette:
    lda LoadingPalette,x
    sta PPUDATA
    inx
    cpx #16
    bne @palette
    lda PPUSTATUS
    lda #$20
    sta PPUADDR
    lda #0
    sta PPUADDR
    ldx #4
    ldy #0
@clear:
    sta PPUDATA
    iny
    bne @clear
    dex
    bne @clear
    lda PPUSTATUS
    lda #$23
    sta PPUADDR
    lda #$c0
    sta PPUADDR
    lda #$bb
    ldx #16
@starattr:
    sta PPUDATA
    eor #$55
    dex
    bne @starattr
    lda #$55
    ldx #24
@boxattr:
    sta PPUDATA
    dex
    bne @boxattr
    lda #$bb
    ldx #8
@lowerattr:
    sta PPUDATA
    eor #$55
    dex
    bne @lowerattr
    lda #0
    ldx #16
@footerattr:
    sta PPUDATA
    dex
    bne @footerattr
    ldx #0
@stars:
    lda PPUSTATUS
    lda StarPositions+1,x
    sta PPUADDR
    lda StarPositions,x
    sta PPUADDR
    txa
    lsr a
    and #3
    clc
    adc #42
    sta PPUDATA
    inx
    inx
    cpx #64
    bne @stars
    lda PPUSTATUS
    lda #$21
    sta PPUADDR
    lda #$46
    sta PPUADDR
    ldx #20
    lda #38
@top:
    sta PPUDATA
    dex
    bne @top
    lda PPUSTATUS
    lda #$22
    sta PPUADDR
    lda #$66
    sta PPUADDR
    ldx #20
    lda #41
@bottom:
    sta PPUDATA
    dex
    bne @bottom
    lda PPUSTATUS
    lda #$21
    sta PPUADDR
    lda #$65
    sta PPUADDR
    lda #34
    sta PPUDATA
    lda PPUSTATUS
    lda #$21
    sta PPUADDR
    lda #$7a
    sta PPUADDR
    lda #35
    sta PPUDATA
    lda PPUSTATUS
    lda #$22
    sta PPUADDR
    lda #$45
    sta PPUADDR
    lda #36
    sta PPUDATA
    lda PPUSTATUS
    lda #$22
    sta PPUADDR
    lda #$5a
    sta PPUADDR
    lda #37
    sta PPUDATA
    lda #$84
    sta boxlow
    lda #$21
    sta boxhigh
    ldy #6
@sides:
    lda PPUSTATUS
    lda boxhigh
    sta PPUADDR
    lda boxlow
    sta PPUADDR
    lda #40
    sta PPUDATA
    lda PPUSTATUS
    lda boxhigh
    sta PPUADDR
    lda boxlow
    clc
    adc #23
    sta PPUADDR
    lda #39
    sta PPUDATA
    clc
    lda boxlow
    adc #32
    sta boxlow
    bcc @nextside
    inc boxhigh
@nextside:
    dey
    bne @sides
    lda #<TitleTop
    sta ptr
    lda #>TitleTop
    sta ptr+1
    lda #$21
    ldx #$c9
    ldy #14
    jsr WriteLoadingRow
    lda #<TitleBottom
    sta ptr
    lda #>TitleBottom
    sta ptr+1
    lda #$21
    ldx #$e9
    ldy #14
    jsr WriteLoadingRow
    lda #<LoadingBrand
    sta ptr
    lda #>LoadingBrand
    sta ptr+1
    lda #$23
    ldx #$2a
    ldy #12
    jsr WriteLoadingRow
    lda #<LoadingVersion
    sta ptr
    lda #>LoadingVersion
    sta ptr+1
    lda #$23
    ldx #$6d
    ldy #6
    jsr WriteLoadingRow
    lda PPUSTATUS
    lda #0
    sta $2005
    sta $2005
    lda #$0a
    sta $fe
    sta PPUMASK
    lda #1
    sta loadingactive
    lda #0
    sta cueframe
    sta cueindex
    sta staroffset
    sta starindex
    lda #$98
    sta $4000
    lda #$08
    sta $4001
    sta $4005
    lda #$72
    sta $4004
    lda #$0e
    sta $4008
    lda #$31
    sta $400c
    lda #0
    sta $4015
    lda #$90
    sta $ff
    sta PPUCTRL
    rts

HideLoading:
    lda #1
    sta loadingtransfer
    lda #0
    sta $4015
    lda #$10
    sta $ff
    sta PPUCTRL
    lda #$06
    sta $fe
    sta PPUMASK
    jsr RestoreLoadingTiles
    lda #0
    sta loadingactive
    sta loadingtransfer
    rts

SaveLoadingTiles:
    lda #0
    sta ptr
    lda PPUSTATUS
    lda #$10
    sta PPUADDR
    lda #0
    sta PPUADDR
    lda PPUDATA
    ldx #4
@page:
    stx ptr+1
    ldy #0
@read:
    lda PPUDATA
    sta (ptr),y
    iny
    bne @read
    inx
    cpx #7
    bne @page
    rts

RestoreLoadingTiles:
    lda #0
    sta ptr
    lda PPUSTATUS
    lda #$10
    sta PPUADDR
    lda #0
    sta PPUADDR
    ldx #4
@page:
    stx ptr+1
    ldy #0
@write:
    lda (ptr),y
    sta PPUDATA
    iny
    bne @write
    inx
    cpx #7
    bne @page
    rts

DrawLoadingFont:
    lda PPUSTATUS
    lda #$10
    sta PPUADDR
    lda #0
    sta PPUADDR
    lda #<LoadingFont
    sta ptr
    lda #>LoadingFont
    sta ptr+1
    ldx #48
@tile:
    ldy #0
@row:
    lda (ptr),y
    sta PPUDATA
    iny
    cpy #8
    bne @row
    clc
    lda ptr
    adc #8
    sta ptr
    bcc @plane
    inc ptr+1
@plane:
    ldy #8
    lda #0
@zero:
    sta PPUDATA
    dey
    bne @zero
    dex
    bne @tile
    rts

WriteLoadingRow:
    sta boxhigh
    stx boxlow
    sty scratch
    lda PPUSTATUS
    lda boxhigh
    sta PPUADDR
    lda boxlow
    sta PPUADDR
    ldy #0
@write:
    lda (ptr),y
    sta PPUDATA
    iny
    cpy scratch
    bne @write
    rts

LoadingNMI:
    pha
    txa
    pha
    tya
    pha
    inc frame
    lda loadingtransfer
    beq @visible
    lda #0
    sta cueframe
    sta cueindex
    sta $4015
    jmp @done
@visible:
    inc cueframe
    lda cueframe
    cmp #6
    bne @color
    lda #0
    sta cueframe
    ldx cueindex
    txa
    and #3
    bne @play
    txa
    and #7
    bne @snare
    lda #$8c
    bne @noise
@snare:
    lda #6
@noise:
    sta $400e
    lda #$0f
    sta $4015
    lda #$18
    sta $400f
    jmp @notes
@play:
    lda #7
    sta $4015
@notes:
    lda LoadingTune,x
    beq @harmony
    sta $4002
    lda #0
    sta $4003
@harmony:
    txa
    and #1
    bne @bass
    txa
    lsr a
    tay
    lda LoadingHarmony,y
    sta $4006
    lda #1
    sta $4007
@bass:
    txa
    and #3
    bne @advancecue
    txa
    lsr a
    lsr a
    tay
    lda LoadingBass,y
    sta $400a
    lda #$21
    sta $400b
@advancecue:
    inx
    cpx #32
    bne @storecue
    ldx #0
@storecue:
    stx cueindex
@color:
    lda frame
    and #7
    bne @stars
    lda frame
    lsr a
    lsr a
    lsr a
    and #3
    tax
    lda PPUSTATUS
    lda #$3f
    sta PPUADDR
    lda #$05
    sta PPUADDR
    lda BorderColors,x
    sta PPUDATA
    lda PPUSTATUS
    lda #$3f
    sta PPUADDR
    lda #$09
    sta PPUADDR
    lda StarColors,x
    sta PPUDATA
    lda PPUSTATUS
    lda #$3f
    sta PPUADDR
    lda #$0d
    sta PPUADDR
    lda StarGlowColors,x
    sta PPUDATA
@stars:
    jsr ScrollLoadingStars
    lda PPUSTATUS
    lda #0
    sta $2005
    sta $2005
    lda $ff
    sta PPUCTRL
@done:
    pla
    tay
    pla
    tax
    pla
    rti

ScrollLoadingStars:
    ldy #4
    ldx starindex
@next:
    lda StarPositions,x
    and #$e0
    sta starrow
    lda PPUSTATUS
    lda StarPositions+1,x
    sta PPUADDR
    lda StarPositions,x
    and #31
    sec
    sbc staroffset
    and #31
    ora starrow
    sta PPUADDR
    lda #0
    sta PPUDATA
    lda PPUSTATUS
    lda StarPositions+1,x
    sta PPUADDR
    lda StarPositions,x
    and #31
    sec
    sbc staroffset
    sec
    sbc #1
    and #31
    ora starrow
    sta PPUADDR
    txa
    lsr a
    clc
    adc staroffset
    adc #1
    and #3
    clc
    adc #42
    sta PPUDATA
    inx
    inx
    cpx #64
    bne @store
    ldx #0
    inc staroffset
    lda staroffset
    and #31
    sta staroffset
@store:
    dey
    bne @next
    stx starindex
    rts

LoadingPalette:
    db $0f,$30,$28,$00,$0f,$28,$30,$0f
    db $0f,$30,$28,$00,$0f,$3c,$30,$00
LoadingTune:
    db $96,0,$86,0,$c9,$b3,0,$e1
    db $bd,$c9,$e1,0,$e1,0,$c9,0
    db $bd,0,$bd,$c9,$e1,$c9,$b3,$96
    db $86,$b3,$96,$c9,$bd,$e1,$c9,$e1
LoadingHarmony:
    db $52,$c4,$2d,$93,$67,$df,$0c,$67
    db $93,$0c,$2d,$93,$c4,$2d,$c4,$2d
LoadingBass:
    db $52,$2d,$67,$0c,$93,$2d,$c4,$c4
BorderColors:
    db $28,$27,$26,$30
StarColors:
    db $30,$28,$30,$27
StarGlowColors:
    db $3c,$2c,$3c,$30
StarPositions:
    dw $2002,$200d,$2019,$2025,$2033,$203e,$2041,$204a
    dw $2057,$2067,$2072,$207d,$2083,$208e,$209a,$20a9
    dw $20b6,$20c0,$20cc,$20db,$20e6,$20f1,$2284,$2291
    dw $229c,$22a2,$22ad,$22b9,$22c8,$22d4,$22e5,$22fb
TitleTop:
    db 1,3,5,0,7,3,9,11,13,1,15,17,17,17
TitleBottom:
    db 2,4,6,0,8,4,10,12,14,2,16,18,18,18
LoadingBrand:
    db 19,20,21,22,23,24,25,26,27,26,28,29
LoadingVersion:
    db 30,31,32,33,32,31
LoadingFont:
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $73,$73,$7b,$7b,$7f,$7f,$7f,$7f
    db $77,$77,$73,$73,$73,$73,$00,$00
    db $3e,$3e,$77,$77,$77,$77,$77,$77
    db $77,$77,$77,$77,$3e,$3e,$00,$00
    db $77,$77,$77,$77,$77,$77,$7f,$7f
    db $7f,$7f,$7f,$7f,$77,$77,$00,$00
    db $70,$70,$70,$70,$70,$70,$70,$70
    db $70,$70,$70,$70,$7f,$7f,$00,$00
    db $1c,$1c,$3e,$3e,$77,$77,$77,$77
    db $7f,$7f,$77,$77,$77,$77,$00,$00
    db $7e,$7e,$77,$77,$77,$77,$77,$77
    db $77,$77,$77,$77,$7e,$7e,$00,$00
    db $3e,$3e,$1c,$1c,$1c,$1c,$1c,$1c
    db $1c,$1c,$1c,$1c,$3e,$3e,$00,$00
    db $3e,$3e,$77,$77,$70,$70,$7f,$7f
    db $77,$77,$77,$77,$3e,$3e,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$1c,$1c,$1c,$1c,$00,$00
    db $3c,$66,$66,$66,$66,$66,$3c,$00
    db $00,$00,$7c,$66,$66,$7c,$60,$60
    db $00,$00,$3c,$66,$7e,$60,$3c,$00
    db $00,$00,$7c,$66,$66,$66,$66,$00
    db $7e,$60,$60,$7c,$60,$60,$60,$00
    db $00,$00,$3c,$06,$3e,$66,$3e,$00
    db $00,$00,$7c,$7e,$6a,$6a,$6a,$00
    db $18,$00,$38,$18,$18,$18,$3c,$00
    db $06,$06,$3e,$66,$66,$66,$3e,$00
    db $00,$00,$3e,$60,$3c,$06,$7c,$00
    db $60,$60,$6c,$78,$70,$78,$6c,$00
    db $00,$00,$66,$66,$66,$3c,$18,$00
    db $3c,$66,$6e,$76,$66,$66,$3c,$00
    db $00,$00,$00,$00,$00,$18,$18,$00
    db $18,$38,$18,$18,$18,$18,$3c,$00
    db $01,$03,$07,$0e,$1c,$38,$70,$e0
    db $80,$c0,$e0,$70,$38,$1c,$0e,$07
    db $e0,$70,$38,$1c,$0e,$07,$03,$01
    db $07,$0e,$1c,$38,$70,$e0,$c0,$80
    db $00,$00,$00,$00,$00,$00,$00,$ff
    db $80,$80,$80,$80,$80,$80,$80,$80
    db $01,$01,$01,$01,$01,$01,$01,$01
    db $ff,$00,$00,$00,$00,$00,$00,$00
    db $00,$10,$38,$7c,$38,$10,$00,$00
    db $00,$00,$18,$3c,$18,$00,$00,$00
    db $00,$18,$3c,$7e,$7e,$3c,$18,$00
    db $00,$00,$00,$18,$18,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00

PAD $fffa
    dw NMI,Reset,IRQ
