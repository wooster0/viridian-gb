; Viridian from VVVVVV!

; In this file coordinate order is: Y, X.

INCLUDE "hardware.inc"

DEF TILE_WIDTH EQU 8
DEF MOVEMENT_SPEED EQU 2

SECTION "OAM data", WRAM0, ALIGN[8]
    ; We have space for 40 objects, each taking up 4 bytes.
    ; The layout of an object is as such:
    ; -Byte 1: Y position
    ; -Byte 2: X position
    ; -Byte 3: Tile number
    ; -Byte 4: Flags
    ; That's 4 bytes which we allocate using `DS 4`.
wOAMBuffer:
    .viridian1 DS 4
    .viridian2 DS 4
    .viridian3 DS 4
    .viridian4 DS 4
    .others DS 36 * 4 ; Other unused objects
    .end ; Local labels use camelCase

SECTION "Viridian", HRAM
ViridianNeedsAlignment: DS 1

SECTION "VBlank interrupt", ROM0[$0040]
    jp VBlankHandler

SECTION "Header", ROM0[$0100]
    jp Start

    DS $150 - @ ; Preserve space for the header.

SECTION "VBlank handler", ROM0
VBlankHandler:
    ; Preserve state
    push af

    call hOAMDMACopyRoutine

MoveViridian:
    ld a, P1F_GET_DPAD
    ld [rP1], a

    ; No input stabilization
    ld a, [rP1]

    ; The input is saved in `d` as well for later because `a` will be overwritten before it's needed again.
    ld d, a

    ; The Left button
    bit 1, a
    jr nz, .skipMoveLeft

    ; Check if Viridian is at the start of the screen.
    ld a, [wOAMBuffer.viridian1 + 1]
    cp MOVEMENT_SPEED + TILE_WIDTH
    jr c, .skipMoveLeft

    ld hl, wOAMBuffer.viridian1 + 1
    dec [hl]
    dec [hl]
    inc hl ; Skip tile number
    inc hl ; Flags
    res 5, [hl]
    ld hl, wOAMBuffer.viridian2 + 1
    dec [hl]
    dec [hl]
    inc hl ; Skip tile number
    inc hl ; Flags
    res 5, [hl]
    ld hl, wOAMBuffer.viridian3 + 1
    dec [hl]
    dec [hl]
    inc hl ; Skip tile number
    inc hl ; Flags
    res 5, [hl]
    ld hl, wOAMBuffer.viridian4 + 1
    dec [hl]
    dec [hl]
    inc hl ; Skip tile number
    inc hl ; Flags
    res 5, [hl]

    ld a, [ViridianNeedsAlignment]
    cp 1
    jr nz, .skipMoveLeft

    ld a, [wOAMBuffer.viridian2 + 1]
    add TILE_WIDTH * 2
    ld [wOAMBuffer.viridian2 + 1], a
    ld a, [wOAMBuffer.viridian4 + 1]
    add TILE_WIDTH * 2
    ld [wOAMBuffer.viridian4 + 1], a

    xor a
    ld [ViridianNeedsAlignment], a

.skipMoveLeft
    ; The Right button
    bit 0, d
    jr nz, .skipMoveRight

    ; Check if Viridian is at the end of the screen.
    ld a, [wOAMBuffer.viridian1 + 1]
    cp SCRN_X
    jr nc, .skipMoveRight

    ld hl, wOAMBuffer.viridian1 + 1
    inc [hl]
    inc [hl]
    inc hl ; Skip tile number
    inc hl ; Flags
    set 5, [hl]
    ld hl, wOAMBuffer.viridian2 + 1
    inc [hl]
    inc [hl]
    inc hl ; Skip tile number
    inc hl ; Flags
    set 5, [hl]
    ld hl, wOAMBuffer.viridian3 + 1
    inc [hl]
    inc [hl]
    inc hl ; Skip tile number
    inc hl ; Flags
    set 5, [hl]
    ld hl, wOAMBuffer.viridian4 + 1
    inc [hl]
    inc [hl]
    inc hl ; Skip tile number
    inc hl ; Flags
    set 5, [hl]

    ld a, [ViridianNeedsAlignment]
    and a
    jr nz, .skipMoveRight

    ld a, [wOAMBuffer.viridian2 + 1]
    sub TILE_WIDTH * 2
    ld [wOAMBuffer.viridian2 + 1], a
    ld a, [wOAMBuffer.viridian4 + 1]
    sub TILE_WIDTH * 2
    ld [wOAMBuffer.viridian4 + 1], a

    ld a, 1
    ld [ViridianNeedsAlignment], a

.skipMoveRight

    pop af
    reti ; Now we return and re-enable interrupts

SECTION "Main", ROM0

Start: ; Labels use PascalCase
    ; Turn off the LCD:
    ; We can't turn off the LCD before we are in the VBlank period.
DisableLCD:
    ; 0-143: the LCD is drawing scanline n.
    ; 144-153: the LCD is in the VBlank period.
.awaitVBlank:
    ldh a, [rLY]
    cp 144
    jr c, .awaitVBlank

    ; Turn off the LCD
    xor a
    ldh [rLCDC], a

    ; Turn off audio
    ld [rNR52], a

    ; Setup state
    ld [ViridianNeedsAlignment], a

    ; Reset scrolling
    ld [rSCX], a
    ld [rSCY], a

    ; Clear the OAM memory.
    ; If we don't do this, we would get weird artifacts on the screen.
ClearOAMSetup:
    ld hl, wOAMBuffer
    ld c, wOAMBuffer.end - wOAMBuffer
    ; `a` is cleared
ClearOAM:
    ld [hli], a
    dec c
    jr nz, ClearOAM

    ; Copy the OAM DMA routine into HRAM:
CopyOAMDMACopyRoutineSetup:
    ld hl, hOAMDMACopyRoutine
    ld de, OAMDMACopyRoutine
    ld c, hOAMDMACopyRoutine.end - hOAMDMACopyRoutine
CopyOAMDMACopyRoutine:
    ld a, [de]
    inc de
    ld [hli], a
    dec c
    jr nz, CopyOAMDMACopyRoutine

    ; Call the routine to clear the initial OAM memory which will contain garbage at first.
    ; This works because we've already cleared the OAM before.
    call hOAMDMACopyRoutine

    ; Load the tiles/graphics into Video Random Access Memory.
LoadTiles:
    ld hl, Viridian
    ld de, Viridian.end - Viridian
    ld bc, _VRAM
.copy
    ld a, [hli]
    ld [bc], a
    inc bc
    dec de
    ld a, d
    or e
    jr nz, .copy

LoadPalette:
    ld a, %11100100
    ld [rOBP0], a

SetLCD:
    ld a, LCDCF_ON | LCDCF_OBJON | LCDCF_OBJ16
    ldh [rLCDC], a

ConfigureObjects:
    ; Set the tile numbers
    ld a, VIRIDIAN1
    ld [wOAMBuffer.viridian1 + 2], a
    ld a, VIRIDIAN2
    ld [wOAMBuffer.viridian2 + 2], a
    ld a, VIRIDIAN3
    ld [wOAMBuffer.viridian3 + 2], a
    ld a, VIRIDIAN4
    ld [wOAMBuffer.viridian4 + 2], a

    ; Viridian part 1
    ld a, SCRN_Y - TILE_WIDTH * 2
    ld [wOAMBuffer.viridian1], a
    ld a, SCRN_X / 2
    ld [wOAMBuffer.viridian1 + 1], a
    ; Viridian part 2
    ld a, SCRN_Y - TILE_WIDTH * 2
    ld [wOAMBuffer.viridian2], a
    ld a, SCRN_X / 2 + TILE_WIDTH
    ld [wOAMBuffer.viridian2 + 1], a
    ; Viridian part 3
    ld a, SCRN_Y
    ld [wOAMBuffer.viridian3], a
    ld a, SCRN_X / 2
    ld [wOAMBuffer.viridian3 + 1], a
    ; Viridian part 4
    ld a, SCRN_Y
    ld [wOAMBuffer.viridian4], a
    ld a, SCRN_X / 2 + TILE_WIDTH
    ld [wOAMBuffer.viridian4 + 1], a

EnableVBlankInterrupt:
    ld a, IEF_VBLANK
    ldh [rIE], a
    ei ; Enable interrupts

Loop:
    ; The HALT instructions halts the CPU until an interrupt is available and thus reduces power consumption more than a busy loop.
    halt
    jr Loop

OAMDMACopyRoutine:
LOAD "OAM DMA copy routine", HRAM
hOAMDMACopyRoutine:
    ld a, HIGH(wOAMBuffer)
    ldh [rDMA], a

    ; One OAM DMA transfer takes 160 microseconds.
    ; The following loop waits for just that long.
    ld a, 40
.wait
    dec a
    jr nz, .wait
    ret
.end
ENDL

SECTION "Graphics", ROM0

; This allows writing dots instead of zeroes for the graphics.
OPT g.123

; Viridian is 10 pixels wide and 21 pixels tall.
Viridian:
    DEF VIRIDIAN1 EQU 0
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `.2222222
    dw `22222222
    dw `23322332
    dw `23322332
    dw `22222222

    DEF VIRIDIAN2 EQU 2
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `2.......
    dw `22......
    dw `22......
    dw `22......
    dw `22......

    DEF VIRIDIAN3 EQU 4
    dw `22222222
    dw `23333332
    dw `22333322
    dw `.2222222
    dw `...2222.
    dw `.2222222
    dw `22222222
    dw `22222222
    dw `22222222
    dw `22.2222.
    dw `22.2222.
    dw `..222222
    dw `..22..22
    dw `.222..22
    dw `.222..22
    dw `.222..22

    DEF VIRIDIAN4 EQU 6
    dw `22......
    dw `22......
    dw `22......
    dw `2.......
    dw `........
    dw `2.......
    dw `22......
    dw `22......
    dw `22......
    dw `22......
    dw `22......
    dw `........
    dw `........
    dw `2.......
    dw `2.......
    dw `2.......

    ; The walking Viridian is 20 pixels tall. Currently unused.
    DEF WALKING_VIRIDIAN1 EQU 8
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `........
    dw `.2222222
    dw `22222222
    dw `22222222
    dw `23322332

    DEF WALKING_VIRIDIAN3 EQU 10
    dw `.23322332
    dw `.22222222
    dw `.23333332
    dw `.22333322
    dw `..2222222
    dw `....2222.
    dw `..2222222
    dw `.22222222
    dw `222222222
    dw `22..2222.
    dw `22..2222.
    dw `...222222
    dw `...22..22
    dw `..222..22
    dw `.222....2
    dw `.222....2

    DEF WALKING_VIRIDIAN4 EQU 12
    dw `22......
    dw `22......
    dw `22......
    dw `2.......
    dw `........
    dw `2.......
    dw `22......
    dw `22......
    dw `22......
    dw `22......
    dw `22......
    dw `........
    dw `........
    dw `2.......
    dw `22......
    dw `22......
.end
