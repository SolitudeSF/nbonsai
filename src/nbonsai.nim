import random, strutils, base64, endians
from os import sleep
from terminal import getch
import cligen, ternim

type
  BaseKind = enum
    baseBig = "big", baseSmall = "small"

  BranchKind = enum
    bkTrunk, bkLeft, bkRight, bkDying, bkDead

  Config = object
    life, mult, pad: int
    live: bool
    step: float
    leaves: seq[string]

proc rand(i: static[int]): range[0..i] = random.rand i

func `>>`(s: Slice[int], o: int): Slice[int] =
  s.a + o..s.b + o

proc oneIn(i: int): bool =
  rand(i - 1) == 0

func size(base: BaseKind): tuple[width, height: int] =
  case base
  of baseBig: (31, 4)
  of baseSmall: (15, 3)

proc drawBase(tb: var TermBuffer, base: BaseKind, seed: string) =
  let
    (baseWidth, baseHeight) = base.size
    baseOriginY = tb.height.int - baseHeight
    baseOriginX = (tb.width.int div 2) - (baseWidth div 2)

  case base
  of baseBig:
    const
      grass = "___________"
      trunk = r"./~~~\."
      grass1Off = grass.len
      trunkOff = grass1Off + trunk.len
      grass2Off = trunkOff + grass.len

      layer1 = r" \                           / "
      layer2 = r"  \_________________________/ "
      layer3 = r"  (_)                     (_)"

    tb[baseOriginX, baseOriginY] = bold brBlack ':'
    tb[1..grass1Off >> baseOriginX, baseOriginY] = bold green grass
    tb[grass1Off.succ..trunkOff >> baseOriginX, baseOriginY] = bold yellow trunk
    tb[trunkOff.succ..grass2Off >> baseOriginX, baseOriginY] = bold green grass
    tb[baseOriginX + grass2Off + 1, baseOriginY] = bold brBlack ':'

    tb[0..layer1.len >> baseOriginX, baseOriginY + 1] = bold brBlack layer1
    tb[0..layer2.len >> baseOriginX, baseOriginY + 2] = bold brBlack layer2
    tb[0..layer3.len >> baseOriginX, baseOriginY + 3] = bold brBlack layer3

    tb[0..seed.len >> baseOriginX + 10, baseOriginY + 1] = black blackBg seed

  of baseSmall:
    const
      grass = "---"
      trunk = r"./~~~\."
      grass1Off = grass.len
      trunkOff = grass1Off + trunk.len
      grass2Off = trunkOff + grass.len

      layer1 = " (           ) "
      layer2 = "  (_________)  "

    tb[baseOriginX, baseOriginY] = brBlack '('
    tb[1..grass1Off >> baseOriginX, baseOriginY] = green grass
    tb[grass1Off.succ..trunkOff >> baseOriginX, baseOriginY] = brYellow trunk
    tb[trunkOff.succ..grass2Off >> baseOriginX, baseOriginY] = green grass
    tb[baseOriginX + grass2Off + 1, baseOriginY] = brBlack ')'

    tb[0..layer1.len >> baseOriginX, baseOriginY + 1] = bold brBlack layer1
    tb[0..layer2.len >> baseOriginX, baseOriginY + 2] = bold brBlack layer2

    tb[0..seed.len >> baseOriginX + 2, baseOriginY + 1] = black blackBg seed

  tb.display

proc ctrlc {.noconv.} =
  deinitTernim()
  quit 0

proc initTerminal(): TermBuffer =
  initTernim()
  setControlCHook ctrlc
  result = newTermBuffer()

proc delta(kind: BranchKind, age, life, mult: int): tuple[x, y: int] =
  case kind
  of bkTrunk:
    if age <= 2 or life < 4: # new or dead
      result.y = 0
      result.x = rand -1..1
    elif age < mult * 3: # young
      result.y = if age mod (mult div 2) == 0: -1 else: 0
      result.x = case rand 9
      of 0:    -2
      of 1..3: -1
      of 4, 5: 0
      of 6..8: 1
      of 9:    2
    else:
      result.y = if rand(9) > 2: -1 else: 0
      result.x = rand -1..1
  of bkLeft:
    result.y = case rand 9
    of 0, 1: -1
    of 2..7: 0
    of 8, 9: 1
    result.x = case rand 9
    of 0, 1: -2
    of 2..5: -1
    of 6..8: 0
    of 9:    1
  of bkRight:
    result.y = case rand 9
    of 0, 1: -1
    of 2..7: 0
    of 8, 9: 1
    result.x = case rand 9
    of 0, 1: 2
    of 2..5: 1
    of 6..8: 0
    of 9:    -1
  of bkDying:
    result.y = case rand 9
    of 0, 1: -1
    of 2..8: 0
    of 9:    1
    result.x = case rand 14
    of 0:      -3
    of 1, 2:   -2
    of 3..5:   -1
    of 6..8:   0
    of 9..11:  1
    of 12, 13: 2
    of 14:     3
  of bkDead:
    result.y = case rand 9
    of 0..2: -1
    of 3..6: 0
    of 7..9: 1
    result.x = rand -1..1

func selectBranchSym(kind: BranchKind, x, y: int): string =
  case kind
  of bkTrunk:
    if y == 0:   r"/~"
    elif x < 0:  r"\|"
    elif x == 0: r"/|\"
    elif x > 0:  r"|/"
    else: "?"
  of bkLeft:
    if y > 0:    r"\"
    elif y == 0: r"\_"
    elif x < 0:  r"\|"
    elif x == 0: r"/|"
    elif x > 0:
      r"/"
    else: "?"
  of bkRight:
    if y > 0:    r"/"
    elif y == 0: r"_/"
    elif x < 0:  r"\|"
    elif x == 0: r"/|"
    elif x > 0:  r"/"
    else: "?"
  else: "?"

proc colored(s: string, kind: BranchKind): TermCells =
  case kind
  of bkTrunk, bkLeft, bkRight:
    if oneIn 2:
      bold brYellow s
    else:
      yellow s
  of bkDying:
    if oneIn 10:
      bold green s
    else:
      green s
  of bkDead:
    if oneIn 3:
      bold brGreen s
    else:
      brGreen s

proc branch(tb: var TermBuffer, x, y: int, kind: BranchKind, life: int,
  nextShoot: var BranchKind, config: Config) =

  template addBranch(newKind: BranchKind, newLife: int): untyped =
    tb.branch(x, y, newKind, newLife, nextShoot, config)

  var
    x = x
    y = y
    life = life
    shootCooldown = config.mult

  while life > 0:
    dec life
    let age = config.life - life

    var (dx, dy) = delta(kind, age, life, config.mult)
    if dy > 0 and y > config.pad: dec dy

    if life < 3:
      addBranch bkDead, life
    elif kind == bkTrunk and life < config.mult + 2:
      addBranch bkDying, life
    elif kind in {bkLeft, bkRight} and life < config.mult + 2:
      addBranch bkDying, life
    elif kind == bkTrunk and
      (oneIn(3) or (life mod config.mult) == 0):
      # (oneIn(mult - 1) or (life > mult and life mod mult == 0)):

      if oneIn(8) and life > 7:
        shootCooldown = config.mult * 2
        addBranch bkTrunk, life + rand -2..2
      elif shootCooldown <= 0:
        shootCooldown = config.mult * 2
        nextShoot = if nextShoot == bkLeft: bkRight else: bkLeft
        addBranch nextShoot, life + config.mult

    dec shootCooldown

    x += dx
    y += dy

    let
      branchSym =
        if life < 4 or kind in {bkDying, bkDead}:
          sample config.leaves
        else:
          selectBranchSym(kind, dx, dy)
      xslice = x..x + branchSym.len

    tb[xslice, y] = branchSym.colored kind

    if config.live:
      tb.display
      sleep int(config.step * 1000)

proc growTree(tb: var TermBuffer, height: int, config: Config) =
  var nextShoot = rand bkLeft..bkRight
  tb.branch(tb.width.int div 2, tb.height.int - height - 1, bkTrunk, config.life, nextShoot, config)
  tb.display

proc seedToBase64(seed: int64): string =
  var seedByteArray: array[8, byte]
  bigEndian64(addr seedByteArray, unsafeAddr seed)
  encode(seedByteArray).strip(chars = {'='})

proc base64ToSeed(s: string): int64 =
  var decoded = decode s
  decoded.setLen 8
  bigEndian64(addr result, addr decoded[0])

proc genSeed(): int64 =
  randomize()
  rand(int64)

proc nbonsai(
  live = false,
  infinite = false,
  print = false,
  wait = 4.0,
  step = 0.03,
  life = 32,
  multiplier = 5,
  base = baseBig,
  seed = "",
  leaves = "&"
) =

  var seed = if seed == "": genSeed()
             else: base64ToSeed(seed)

  randomize(seed)

  var tb = initTerminal()

  let config = Config(
    life: life,
    mult: multiplier,
    pad: tb.height.int - base.size.height - 2,
    step: step,
    live: live,
    leaves: leaves.split ','
  )
  while true:
    tb.drawBase base, seedToBase64(seed)
    tb.growTree base.size.height, config

    if infinite:
      sleep int(wait * 1000)
      tb.clear
      seed = genSeed()
      randomize(seed)
    else:
      break

  if print:
    deinitTernim()
    var line = ""
    for y in 0'u16..<tb.height:
      line.toString tb.buf.toOpenArray(int(tb.width * y), int(tb.width * y.succ - 1))
      stdout.writeLine line
      line.setLen 0
  else:
    discard getch()
    deinitTernim()

dispatch nbonsai
