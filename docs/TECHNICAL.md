# Technical notes

How the two patches work, where they hook, and how one set of data becomes a
patched `main.dol`, a Gecko code list and a Riivolution patch. For installing
and playing, see the [README](../README.md).

Addresses below are the **USA** `main.dol` (`RMAE01`) unless noted; the table at
the end lists the other releases.

## One data set, three outputs

Every patch is a list of operations on one release's `main.dol`:

| Operation | Static (`main.dol`) | Gecko | Riivolution |
| --- | --- | --- | --- |
| **Hook** — replace one instruction with a branch to a routine that runs the displaced instruction and branches back | branch + trampoline in the injected section | `C2` code | `<memory>` (branch + trampoline) |

`tools/prebuilt/<feature>_<disc id>.json` holds those operations, including the
retail instruction expected at every site. `tools/ops.py` turns them into each
format, `tools/patcher.py` applies them (and refuses a `main.dol` whose sites do
not match, so already-modified or foreign dumps are never touched), and
`tools/build.py` writes `codes/` and `riivolution/`. `tools/check.py` fails if
the committed files drift from the data; `tools/verify.py` checks the data
against real retail DOLs for every combination of patches.

**Hooks are self-contained.** A routine carries everything it needs and reaches
game code through absolute addresses (`lis`/`addi`/`mtctr`/`bctrl`), never a
relative `bl` — a Gecko code handler runs the routine from wherever it keeps it,
so a relative branch to the game would land in the wrong place. `tools/check.py`
rejects any relative branch that leaves its routine. Routines hold no variables
of their own; the static build parks them in one new text section at
`0x80001820` (the Wii's boot-time scratch area, which this game never touches:
the game's own code starts at `0x80004000` and nothing in the retail DOLs
addresses `0x80001800-0x80003000`).

## The architecture

New Play Control! Mario Power Tennis was ported from the GameCube codebase to
the Wii Remote and Nunchuk. It uses the SDK's `KPAD` library (`Aug 8 2007` build),
where `KPADRead` turns raw Wii Remote samples into status structures.

### 1. KPAD sample synthesis

KPAD maintains a 16-slot ring buffer of `WPADStatus` samples per channel (`0x538` bytes
per channel struct, ring at `+0x110`, `0x38` bytes per slot, write index at `+0x10E`).
Its sampling callback reads a sample with `WPADRead`, stores the data format in slot
byte `0x36`, and advances the ring write index.

- **Classic Controller** (`src/cc_sample.s`):
  Hooks the format byte store (`stb r3, 0x36(r30)` at `0x800A6884`). If a Classic
  Controller is connected (`dev_type == 2`), its left stick is scaled to Nunchuk stick
  range (`+0x30/+0x31`), buttons are mapped to Wii Remote and Nunchuk bits, the right
  stick coordinates are carried in `+0x2A/+0x2C` for the pointer hook, and the sample is
  rewritten in place with `dev_type = 1` (Nunchuk) and format 4.

- **GameCube Controller** (`src/gc_sample.s`, `src/gc_convert.s`):
  Hooks the ring index increment (`addi r0, r28, 1` at `0x800A6888`). If a GameCube pad
  answers on the matching SI port (`0xCD006404 + 12*n`), its control stick is mapped to the
  Nunchuk stick, buttons are mapped to Wii Remote and Nunchuk bits, and the sample is rewritten
  to a Nunchuk sample.

- **Running with no Wii Remote** (`src/gc_synth.s`, `src/gc_probe.s`):
  If no Wii Remote is connected, `gc_probe.s` hooks `WPADProbe` (`0x800990B8`). If `WPADProbe`
  returns `-1` and a GameCube controller answers, it returns `0` (connected) and reports extension
  type 1 (Nunchuk). `gc_synth.s` hooks the ring count check in `KPADRead` (`lbz r0, 0x10F(r31)`
  at `0x800A5EC4`); when the ring is empty, it synthesizes a sample directly from the SI registers,
  advances the ring, and calls the connection callback once.

### 2. Tennis Racquet and Swing Trigger

In the retail game, racket swings and shot types are detected by evaluating multi-frame
accelerometer data in `0x800158F0` and storing the result in the racquet structure (`52(r15)` = active,
`56(r15)` = shot type: 1 topspin, 2 slice, 3 flat/lob).

- **CC Swing Hook** (`src/cc_swing.s` at `0x80015DC0`):
  Hooks `cmpwi r0, 0` before the motion evaluation. When a button is pressed on the player's
  controller (A = topspin, B = slice, X/A+B = flat), it directly sets `56(r15) = type`,
  `52(r15) = 1`, and sets `r0 = 1` so the game's `bne` branches past the accelerometer convolution.

- **GC Swing Hook** (`src/gc_swing.s` at `0x80015DC8`):
  Hooks `bl 0x800158f0`. When a button is pressed, it sets `56(r15) = type`, `52(r15) = 1`, and
  skips the motion evaluation call. If no button is pressed, it calls the original evaluation
  routine.

Because the CC and GC swing hooks occupy separate instruction addresses, both features can be
applied together without interference.

## Sites by release

| Hook | USA (`RMAE01`) | Europe (`RMAP01`) | Japan (`RMAJ01`) | Displaced instruction |
| --- | --- | --- | --- | --- |
| CC sample | `0x800A6884` | `0x800A6884` | `0x800A4E50` | `stb r3, 0x36(r30)` (`0x987E0036`) |
| GC sample | `0x800A6888` | `0x800A6888` | `0x800A4E54` | `addi r0, r28, 1` (`0x381C0001`) |
| CC pointer | `0x800A6478` | `0x800A6478` | `0x800A4A44` | `bl <ir>` (`0x4BFFEF19`) |
| GC pointer | `0x800A647C` | `0x800A647C` | `0x800A4A48` | `b <loop_end>` (`0x48000008`) |
| GC synth | `0x800A5EC4` | `0x800A5EC4` | `0x800A4490` | `lbz r0, 0x10f(r31)` (`0x881F010F`) |
| GC probe | `0x800990B8` | `0x800990B8` | `0x80097668` | `stwu r1, -0x10(r1)` (`0x9421FFF0`) |
| CC swing | `0x80015DC0` | `0x80015DC0` | `0x80015C38` | `cmpwi r0, 0` (`0x2C000000`) |
| GC swing | `0x80015DC8` | `0x80015DC8` | `0x80015C40` | `bl <eval>` (`0x4BFFFB29`) |
