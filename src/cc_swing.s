# hook: racquet update, `cmpwi r0, 0` at 0x80015DC0 (USA/Europe) or 0x80015C38 (Japan).
# r15 = player's racquet/swing struct
# r20 = 0(r15) = player character object
#
# If a button is pressed on the player's controller:
#   A (0x0800)       -> Topspin swing (type 1)
#   B (0x0400)       -> Slice swing (type 2)
#   X / C (0x4000) or A+B -> Flat swing (type 3)
# Sets 56(r15) = swing type, 52(r15) = 1 (swing active), and r0 = 1 so the
# following `bne` branch skips the accelerometer evaluation.
#
# Scratch: r9, r10, r11, r12.
    cmpwi   20, 0
    beq     9f                          # no player object
    lwz     11, 0x34(20)                # 52(r20) = player channel index (0..3, or 255 for CPU)
    cmplwi  11, 3
    bgt     9f                          # CPU or invalid -> original logic
    mulli   12, 11, 2120
    lis     11, INPUT_BUF@ha
    addi    11, 11, INPUT_BUF@l         # r11 = input buffer base
    add     11, 11, 12                  # r11 = player's controller struct
    lwz     12, 0x04(11)                # buttons trig
    lwz     10, 0x00(11)                # buttons hold
    andi.   9, 12, 0x4000               # Button C / X trig?
    bne     shot_flat
    andi.   9, 10, 0x0800               # Button A held?
    beq     check_b_only
    andi.   9, 10, 0x0400               # Button B held?
    beq     check_a_only
shot_flat:
    li      9, 3                        # Flat shot (type 3)
    b       trigger_swing
check_a_only:
    andi.   9, 12, 0x0800               # Button A trig?
    beq     check_b_only
    li      9, 1                        # Topspin shot (type 1)
    b       trigger_swing
check_b_only:
    andi.   9, 12, 0x0400               # Button B trig?
    beq     9f
    li      9, 2                        # Slice shot (type 2)
trigger_swing:
    sth     9, 0x38(15)                 # 56(r15) = shot type!
    li      0, 1
    stw     0, 0x34(15)                 # 52(r15) = swing active!
9:
    cmpwi   0, 0                        # displaced instruction
