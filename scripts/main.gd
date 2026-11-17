extends Node2D

# Level 1 at the original 320x200 : scrolling map, starfield, ship, base gun, enemy waves,
# enemy fire, collisions, explosions, wave bonuses, death and restart, HUD.
# The game runs in fixed game frames (ticks), in the order of the main loop at 0x3d26.
# "code" marks behaviour ported from XENON2.EXE, with the load module offset it was read at.
# "placeholder" marks guesses where the code is not read yet.
# "unconfirmed" marks code readings that left a detail open.

# the level ds:0x991c (1 to 5) and its files S1 to S5. code 0x4131 : after the end of level
# shop the next one, 5 going back to 1.

var level_number := 1

# ds:0x991a : the times round the five levels, 1 on a new game (0x1837), one more after
# level 5 (0x4142). The wave enemies' energy is multiplied by it.

var game_loop := 1
var LEVEL := "S1"
const PLAY_HEIGHT := 192

# code 0x5e8a : timer divisor 0x5555, a game frame every third interrupt, at most

const TICK_SECONDS := 3.0 * 0x5555 / 1193182.0

# code 0x1aaf and 0x195b : the level starts at scroll 0x1200, ship at (0xa0, 0xb0), which is
# also the first checkpoint. Waves and wall objects below 0x7fee all fire on the first check.

const START_SCROLL := 0x1200
const START_X := 0xa0
const SHIP_Y_MAX := 0xb0
const SHIP_Y_MIN := 0x10
const FIRST_CHECK := 0x7fee

# code 0x3e1a : the scroll may go back up to ds:0x91ae (16) rows behind its furthest point.
# The level inits (per level table cs:0xf8a) set the lower scroll limit ds:0x91a8 and the
# upper ds:0x91aa : level 1 (0x758f) 0 and 0x11ff, level 2 (0x8e01) 0x9e0 and 0x11ff, level 3
# (0xac4e) 0xaf0 and 0x11ff.

const BACK_SCROLL := 0x10
const SCROLL_MINS := {1: 0, 2: 0x9e0, 3: 0xaf0, 4: 0x880, 5: 0}
const START_SCROLL_MAX := 0x11ff
var scroll_min := 0

# code 0x655b (level 1 hook 0xff0) : the mid level shop, once, when scroll + ship y goes
# below 0xa80. The scroll and its limit jump to 0x9c0.

const MID_SHOP_LINE := 0xa80
const MID_SHOP_SCROLL := 0x9c0

# the level inits : the price caps of the shops, end of level (ds:0x8eac) and mid level
# (ds:0x8eae), level 1 (0x758f) 3000 and 600, level 2 (0x8e01) 4000 and 1200, level 3 (0xac4e)
# 5000 and 2000. Code 0x3fb4 :
# at the end of the level (scroll <= 0x1e0) the credits floor is the cap plus 400, in the
# middle the cap itself.

const SHOP_CAPS := {1: [0xbb8, 0x258], 2: [0xfa0, 0x4b0], 3: [0x1388, 0x7d0], 4: [0x1770, 0x7d0], 5: [0x1770, 0x1770]}
const END_SHOP_LINE := 0x1e0
var end_shop_cap := 0xbb8
var mid_shop_cap := 0x258

# code 0x3246 : side cannons (type 0x34), up to 4, in the slots ds:0x9138, 0x913c, 0x9140,
# 0x9144, at these offsets from the ship (ds:0x30a8). X2WEAPS 51 static, after a shot
# 52, 53 (the shell leaves), 54, 55 for a tick each (cs:0x12ca). The companion (type 0x40,
# 0x21e9) under it plays X2WEAPS 68 to 71 (cs:0x1366).

const CANNON_OFFSETS := [Vector2i(-26, 16), Vector2i(26, 16), Vector2i(-44, 24), Vector2i(44, 24)]
const CANNON_FRAMES := [["X2WEAPS/052", 1], ["X2WEAPS/053", 1], ["X2WEAPS/054", 1], ["X2WEAPS/055", 1], ["X2WEAPS/051", 0]]
const CANNON_REST := 4
const COMPANION_FRAMES := [["X2WEAPS/068", 1], ["X2WEAPS/069", 1], ["X2WEAPS/070", 1], ["X2WEAPS/071", 1]]

# code 0x28b8 : the cannon shell, 10 rows up a frame, X2WEAPS 47 to 50 for 2 ticks each
# (cs:0x132c), damage 2 (cs:0x3da4) to the first enemy box it overlaps, not removed by it

const SHELL_FRAMES := [["X2WEAPS/047", 2], ["X2WEAPS/048", 2], ["X2WEAPS/049", 2], ["X2WEAPS/050", 2]]
const SHELL_SPEED := -10
const SHELL_DAMAGE := 2

# code 0x758f and 0x72c4 : the level 1 boss (type 0x50), created at level start, active
# once the scroll is at most 0x1c0. Energy 30 (cs:0x6278). Its body is a 6x7 grid of tiles
# (cs:0x7660) drawn at x 112, 0 empty, negative masked (colour 0 transparent).

const BOSS_ENERGY := 30
const BOSS_BODY := [
	[-115, -116, -117, -118, -119, -120],
	[-133, 134, 135, 136, 137, -138],
	[-151, 152, 153, 154, 155, -156],
	[-169, -170, 171, 172, 173, -174],
	[-187, -188, -189, 190, 191, -192],
	[0, -205, -206, -207, -208, -209],
	[0, -222, -223, -224, -225, 0],
]

# cs:0x76e4 : mouth frames for row 5 and row 6, columns 1 to 4, by (frame count >> 2) & 3

const BOSS_MOUTHS := [
	[[-205, -206, -207, -208], [-222, -223, -224, -225]],
	[[-280, 281, 282, -283], [292, 293, 294, 295]],
	[[284, 285, 286, 287], [296, 297, 298, 299]],
	[[-280, 281, 282, -283], [292, 293, 294, 295]],
]

# cs:0x76fc : the eye, S1 100, 101, 102, 101 by (ds:0x91fe >> 6) & 3, at (152, y + 0x42)

const BOSS_EYE := [100, 101, 102, 101]

# code 0x71dd : 8 tentacle segments (S1 38), the tip aims with S1 43, 42, 41, 40, 39, 46,
# 45, 44 by direction (cs:0x76ec) and fires S1 109, 110, 111 (cs:0x6549) at speed 4

const TIP_FRAMES := [43, 42, 41, 40, 39, 46, 45, 44]
const TIP_BULLET := [["S1/109", 2], ["S1/110", 2], ["S1/111", 2]]

# code 0x3360 : the pod (type 0) keeps its speed field for another use and moves at 3

const POD_TYPE := 0
const POD_SPEED := 3

# code 0x304c : ship frame by tilt -6..6 (pointers 0x3a8, 0x54e, 0x77a, 0x9a6, 0xbd2)

const SHIP_FRAMES := [6, 6, 6, 7, 7, 7, 8, 9, 9, 9, 10, 10, 10]

# code 0x16d8 and 0x4759 : four flames (type 0xc4) follow the ship, in list order 3, 2, 1, 0.
# Each alternates two X2SPR frames every tick (animations ds:0x3292). Flames 0 and 1 show
# while up is held, 2 and 3 while down is held. x = ship x + ds:0x3276[|tilt|], plus 7
# entries for odd flames, y = ship y.

const FLAME_FRAMES := [[131, 132], [133, 134], [129, 130], [127, 128]]
const FLAME_X_EVEN := [-1, -1, -1, -2, -2, -2, 0]
const FLAME_X_ODD := [1, 1, 1, 2, 2, 2, 0]

# code 0x3c01 and cs:0x1264 : the ship's explosion, X2SPR 25 to 32 for a tick each, then
# frame 33 with a count of 0, which is never drawn

const SHIP_DEATH_FRAMES := [25, 26, 27, 28, 29, 30, 31, 32]

# code 0x3326 : explosions, cs:0x1230 (small) and cs:0x124c (large), a tick per frame

const SMALL_EXPLOSION := [0, 1, 2, 3, 4, 5]
const LARGE_EXPLOSION := [25, 27, 29, 31, 33]

# code 0x3aec : wave bonuses, cs:0x11f2 (small, X2SPR 70..83) and cs:0x11b4 (large, 11..24),
# a tick per frame, looping. Moves by the table at ds:0x31b8, 0 up and clockwise.

const SMALL_BONUS := [70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83]
const LARGE_BONUS := [11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]
const BONUS_STEP := [Vector2i(0, -2), Vector2i(2, -2), Vector2i(2, 0), Vector2i(2, 2),
		Vector2i(0, 2), Vector2i(-2, 2), Vector2i(-2, 0), Vector2i(-2, -2)]

# code 0x1f0d and 0x1f2d : enemy bullet direction table, 2.14 fixed point, 0 up, clockwise

const BULLET_DX := [0, 0x2d41, 0x4000, 0x2d41, 0, -0x2d41, -0x4000, -0x2d41,
		0x187d, 0x3b20, 0x3b20, 0x187d, -0x187d, -0x3b20, -0x3b20, -0x187d]
const BULLET_DY := [-0x4000, -0x2d41, 0, 0x2d41, 0x4000, 0x2d41, 0, -0x2d41,
		-0x3b20, -0x187d, 0x187d, 0x3b20, 0x3b20, 0x187d, -0x187d, -0x3b20]
const ENEMY_BULLET_SPEED := 6

# the enemy bullet ds:0x8e72, set by each level init : level 1 S1 frame 48 (0x764f),
# level 2 S2 frame 11 (0x8f88), level 3 S3 71 (0xace2), level 4 S4 110 (0xc823), level 5
# S5 175 (0xe50b)

const ENEMY_BULLET_FRAMES := {1: 48, 2: 11, 3: 71, 4: 110, 5: 175}

# code 0x8ca7 and 0x8d18 (level 2, hook 0xf96) : blocks that any player shot breaks. When a
# shot meets no enemy, the top left corner of its box (in the world, scroll added) picks one
# of four lists (0x8c85 : left when x <= 0x80, upper when y <= 0x80), sorted by x. The first
# block left (state 1) whose 16x16 square overlaps the box breaks, unless the box is below
# world y 0x1b0 or a block further right than the box is met first. Its map word becomes 0
# and a small explosion shows at its middle. Entries : x, world y, map word (cs:0x938b,
# 0x93ed, 0x944f, 0x94a1, order of cs:0x9503 by 0x8c85's index 0, 2, 4, 6). The three hit
# tests (0x1bea, 0x1c4f, 0x1ccc) ask for it, so every kind of shot breaks blocks. The ship
# touching one does nothing : the record's type is 0 and 0x4388 skips it.

const BLOCK_LISTS := [
	[[0xc0, 0x150, 0x3901], [0xc0, 0x140, 0x3941], [0xd0, 0x160, 0x3901], [0xd0, 0x150, 0x3941],
		[0xe0, 0x170, 0x3901], [0xe0, 0x160, 0x3941], [0xf0, 0x180, 0x3901], [0xf0, 0x170, 0x3941],
		[0x100, 0x190, 0x3901], [0x100, 0x180, 0x3941], [0x110, 0x1a0, 0x3901], [0x110, 0x190, 0x3941]],
	[[0xc0, 0x60, 0x3981], [0xc0, 0x70, 0x39c1], [0xd0, 0x50, 0x3981], [0xd0, 0x60, 0x39c1],
		[0xe0, 0x40, 0x3981], [0xe0, 0x50, 0x39c1], [0xf0, 0x30, 0x3981], [0xf0, 0x40, 0x39c1],
		[0x100, 0x20, 0x3981], [0x100, 0x30, 0x39c1]],
	[[0x20, 0x1a0, 0x39c1], [0x20, 0x190, 0x3981], [0x30, 0x190, 0x39c1], [0x30, 0x180, 0x3981],
		[0x40, 0x180, 0x39c1], [0x40, 0x170, 0x3981], [0x50, 0x170, 0x39c1], [0x50, 0x160, 0x3981],
		[0x60, 0x160, 0x39c1], [0x60, 0x150, 0x3981], [0x70, 0x150, 0x39c1], [0x70, 0x140, 0x3981]],
	[[0x30, 0x20, 0x3941], [0x30, 0x30, 0x3901], [0x40, 0x30, 0x3941], [0x40, 0x40, 0x3901],
		[0x50, 0x40, 0x3941], [0x50, 0x50, 0x3901], [0x60, 0x50, 0x3941], [0x60, 0x60, 0x3901],
		[0x70, 0x60, 0x3941], [0x70, 0x70, 0x3901]],
]
const BLOCK_LINE := 0x1b0

# the state of each block (0x8df0 at the level init : all there)

var blocks: Array = []

# level 2's own routines (level2.gd), null on the other levels

var level2: Level2 = null
var level3: Level3 = null
var level4: Level4 = null
var level5: Level5 = null

# code 0x37df and 0x45f4 : the base gun bullet starts 6 rows above the ship and moves 9 up.
# code 0x3835 : the rear shot starts 18 rows below and moves 9 down.
# Bullet pictures by weapon level (cs:0x12b8 and cs:0x12c4), drawn in colour 7 :
# hot spot x, hot spot y, rows (ds:0x4546, 0x473e, 0x49b6 and ds:0x4632, 0x486a, 0x4b22)

const GUN_OFFSET_Y := -6
const GUN_SPEED := -9
const REAR_OFFSET_Y := 18
const REAR_SPEED := 9
const GUN_PICTURES := [
	[2, 5, [".###.", "#####", "#####", ".###.", "..#..", "..#.."]],
	[3, 7, ["..###..", ".#####.", "#######", "#######", ".#####.", ".#####.", "..###..", "...#..."]],
	[4, 9, ["...###...", ".#######.", ".#######.", "#########", ".#######.", ".#######.", "..#####..", "..#####..", "...###...", "....#...."]],
]
const REAR_PICTURES := [
	[2, 0, ["..#..", "..#..", ".###.", "#####", "#####", ".###."]],
	[3, 0, ["...#...", "..###..", ".#####.", ".#####.", "#######", "#######", ".#####.", "..###.."]],
	[4, 0, ["....#....", "...###...", "..#####..", "..#####..", ".#######.", ".#######.", "#########", ".#######.", ".#######.", "...###..."]],
]

# code 0x308c and cs:0x12f8 : the rear shot launcher, X2WEAPS 72 (static), and after each
# shot 73, 74, 75, 76 for a tick each, then 72 again

const REAR_FRAMES := [["X2WEAPS/072", 0], ["X2WEAPS/073", 1], ["X2WEAPS/074", 1], ["X2WEAPS/075", 1], ["X2WEAPS/076", 1]]

# code 0x1e61, ds:0x31fe : pod items by index, animation (frame, ticks), looping

const ITEM_FRAMES := {
	0: [["X2SPR/041", 1], ["X2SPR/042", 1], ["X2SPR/043", 1], ["X2SPR/044", 1], ["X2SPR/045", 1], ["X2SPR/046", 1], ["X2SPR/047", 1], ["X2SPR/048", 3]],
	1: [["X2SPR/056", 1], ["X2SPR/057", 1], ["X2SPR/058", 1], ["X2SPR/059", 1], ["X2SPR/060", 1], ["X2SPR/061", 1], ["X2SPR/062", 1], ["X2SPR/048", 3]],
	2: [["X2SPR/087", 1], ["X2SPR/088", 1], ["X2SPR/089", 1], ["X2SPR/088", 1]],
	3: [["X2SPR/084", 1], ["X2SPR/085", 1], ["X2SPR/086", 1], ["X2SPR/085", 1]],
	4: [["X2WEAPS/072", 1], ["X2WEAPS/073", 1], ["X2WEAPS/074", 1], ["X2WEAPS/075", 1], ["X2WEAPS/076", 1]],
	5: [["X2SPR/094", 1], ["X2SPR/095", 1], ["X2SPR/096", 1], ["X2SPR/097", 1], ["X2SPR/098", 1], ["X2SPR/097", 1], ["X2SPR/096", 1], ["X2SPR/095", 1]],
	6: [["X2SPR/049", 1], ["X2SPR/050", 1], ["X2SPR/051", 1], ["X2SPR/052", 1], ["X2SPR/053", 1], ["X2SPR/054", 1], ["X2SPR/055", 1], ["X2SPR/048", 3]],
	7: [["X2WEAPS/051", 1], ["X2WEAPS/052", 1], ["X2WEAPS/053", 1], ["X2WEAPS/054", 1], ["X2WEAPS/055", 1]],
	8: [["X2WEAPS/000", 1], ["X2WEAPS/001", 1], ["X2WEAPS/002", 1], ["X2WEAPS/003", 1]],
	9: [["X2WEAPS/004", 1], ["X2WEAPS/005", 1], ["X2WEAPS/006", 1], ["X2WEAPS/007", 1], ["X2WEAPS/008", 1], ["X2WEAPS/009", 1], ["X2WEAPS/010", 1], ["X2WEAPS/011", 1]],
	10: [["X2WEAPS/012", 1], ["X2WEAPS/013", 1], ["X2WEAPS/014", 1], ["X2WEAPS/015", 1], ["X2WEAPS/016", 1], ["X2WEAPS/017", 1], ["X2WEAPS/018", 1], ["X2WEAPS/019", 1], ["X2WEAPS/020", 1]],
	11: [["X2WEAPS/059", 2], ["X2WEAPS/060", 2], ["X2WEAPS/061", 2]],
	12: [["X2WEAPS/079", 0], ["X2WEAPS/080", 1], ["X2WEAPS/081", 1], ["X2WEAPS/082", 1], ["X2WEAPS/083", 1], ["X2WEAPS/084", 1], ["X2WEAPS/085", 1]],
	13: [["X2WEAPS/102", 1], ["X2WEAPS/103", 1]],
	14: [["X2WEAPS/091", 1], ["X2WEAPS/092", 1], ["X2WEAPS/093", 1], ["X2WEAPS/094", 1]],
	15: [["X2WEAPS/062", 1], ["X2WEAPS/063", 1], ["X2WEAPS/064", 1], ["X2WEAPS/065", 1], ["X2WEAPS/066", 1], ["X2WEAPS/067", 1]],
	16: [["X2WEAPS/086", 2], ["X2WEAPS/087", 2]],
	17: [["X2SPR/063", 1], ["X2SPR/064", 1], ["X2SPR/065", 1], ["X2SPR/066", 1], ["X2SPR/067", 1], ["X2SPR/068", 1], ["X2SPR/069", 1], ["X2SPR/048", 3]],
	18: [["X2SPR/099", 1], ["X2SPR/100", 1], ["X2SPR/101", 1], ["X2SPR/102", 1], ["X2SPR/103", 1], ["X2SPR/102", 1], ["X2SPR/101", 1], ["X2SPR/100", 1]],
}

# code 0x2b80 : the shield of item 16, ds:0x9188 frames left (0xaa an item), its picture
# X2WEAPS 86 and 87 (cs:0x1148) on the ship and a gauge at (4, 0xa0)

const SHIELD_FRAMES := [["X2WEAPS/086", 2], ["X2WEAPS/087", 2]]
const SHIELD_ADD := 0xaa

# code 0x6590 (level 1 hook) : the hole creatures while the scroll is 0xa40 to 0xd10. cs:0x65f6
# : the 16 hole cells, map word index and the tiles written for counter & 3 (counters
# ds:0x91d4, 0x14 when a creature goes in or out). cs:0x6767 : x, world y, entry hole, exit
# hole, path (main.paths index 87 + n). ds:0x91f4 to 0x91fc : one word a slot, turned right
# by 3 for each spawn, its low nibble picks the entry (initial values 0x758f).

const HOLE_CELLS := [
	[3542, [0x53c1, 0x5401, 0x5441, 0x5401]], [3662, [0x53c1, 0x5401, 0x5441, 0x5401]],
	[3842, [0x53c1, 0x5401, 0x5441, 0x5401]], [3538, [0x5301, 0x5341, 0x5381, 0x5341]],
	[3597, [0x5301, 0x5341, 0x5381, 0x5341]], [3658, [0x5301, 0x5341, 0x5381, 0x5341]],
	[3756, [0x5301, 0x5341, 0x5381, 0x5341]], [4027, [0x5301, 0x5341, 0x5381, 0x5341]],
	[4086, [0x5301, 0x5341, 0x5381, 0x5341]], [4147, [0x5301, 0x5341, 0x5381, 0x5341]],
	[4013, [0x53c1, 0x5401, 0x5441, 0x5401]], [3998, [0x5301, 0x5341, 0x5381, 0x5341]],
	[4092, [0x53c1, 0x5401, 0x5441, 0x5401]], [4057, [0x5301, 0x5341, 0x5381, 0x5341]],
	[4133, [0x53c1, 0x5401, 0x5441, 0x5401]], [4118, [0x5301, 0x5341, 0x5381, 0x5341]],
]
const HOLE_OPEN := 0x14
const HOLE_FIRST := 0xa40
const HOLE_LAST := 0xd10
const HOLE_SPAWNS := [
	[40, 2840, 0, 6, 87], [40, 2936, 1, 11, 88], [40, 3080, 2, 8, 89], [296, 2824, 3, 9, 90],
	[280, 2872, 4, 12, 91], [296, 2920, 5, 14, 92], [264, 3000, 6, 13, 93], [120, 3224, 7, 0, 94],
	[104, 3272, 8, 3, 95], [120, 3320, 9, 10, 96], [216, 3208, 10, 15, 97], [296, 3192, 11, 1, 98],
	[200, 3272, 12, 2, 99], [280, 3240, 13, 4, 100], [216, 3304, 14, 5, 101], [296, 3288, 15, 7, 102],
]
const HOLE_ROTATIONS := [0xd272, 0x6a4a, 0xba5d, 0x2512, 0xe51a]

# code 0x6823 : a leader (type 0x10c, update 0x6aad, not drawn, not hit) on the path at speed 4
# (cs:0x6282), a head (0x114, 250, hit 0x66a6) and 10 bodies (0x110, 50, hit 0x6696) with
# steps 0, -7, -14 ... (cs:0x670d), energy 1, hidden. Frames by direction ((dir + 16) >> 4) & 7
# (cs:0x6a8d head, cs:0x6a9d body), debris animations cs:0x6523 and cs:0x650d.

const HOLE_SEGMENTS := 11
const HOLE_SPEED := 4
const HOLE_DELAY := 7
const HOLE_SCORES := [250, 50]
const HOLE_HEAD_FRAMES := ["S1/065", "S1/066", "S1/059", "S1/060", "S1/061", "S1/062", "S1/063", "S1/064"]
const HOLE_BODY_FRAMES := ["S1/057", "S1/058", "S1/055", "S1/056", "S1/057", "S1/058", "S1/055", "S1/056"]
const HOLE_HEAD_DEBRIS := [["S1/059", 2], ["S1/060", 2], ["S1/061", 2], ["S1/062", 2], ["S1/063", 2], ["S1/064", 2], ["S1/065", 2], ["S1/066", 2]]
const HOLE_BODY_DEBRIS := [["S1/055", 2], ["S1/056", 2], ["S1/057", 2], ["S1/058", 2]]

# code 0x6ef6 : level 1 wall creatures, made of 2x2 map tiles (words top left, top right,
# bottom left, bottom right, all with bit 0 set). Frame lists by side (0 left, 1 right),
# death tiles, box from (x, screen y), fire rate, bullet frame, speed and start offset.
#   type 1 (0x6f7f, update 0x6d22) : hand, frame = counter >> 2, counter 0..15
#   type 2 (0x6f00, update 0x6ac7) : creature in the wall, a frame per update
#   type 3 (0x6fe0, update 0x6bca) : clam, top row only, 20 frames of 2 updates

const WALL_TYPES := {
	1: {
		"frames": [
			[[256, 257, 268, 269], [258, 259, 270, 271], [260, 261, 272, 273], [258, 259, 270, 271]],
			[[262, 263, 274, 275], [276, 277, 288, 289], [278, 279, 290, 291], [276, 277, 288, 289]],
		],
		"death": [[302, 303, 310, 311], [300, 301, 308, 309]],
		"box": [10, 4, 28, 28],
		"rate": 4,
		"bullet": "S1/048",
		"speed": 6,
		"shot_x": 32,
		"shot_y": 14,
	},
	2: {
		"frames": [
			[[27, 241, 47, 249], [27, 243, 47, 251], [27, 253, 47, 265], [27, 255, 47, 267]],
			[[240, 22, 248, 42], [242, 22, 250, 42], [252, 22, 264, 42], [254, 22, 266, 42]],
		],
		"death": [[306, 307, 314, 315], [304, 305, 312, 313]],
		"box": [4, 4, 28, 28],
		"rate": 5,
		"bullet": "X2SPR/136",
		"speed": 6,
		"shot_x": 16,
		"shot_y": 14,
	},
	3: {
		"init": [[233, 234, 246, 247], [226, 227, 244, 245]],
		"frames": [
			[[233, 234], [235, 236], [237, 238], [239, 0], [239, 324], [239, 325], [239, 326], [239, 327],
				[239, 328], [239, 329], [239, 330], [239, 331], [239, 327], [239, 326], [239, 325], [239, 324],
				[239, 0], [237, 238], [235, 236], [233, 234]],
			[[226, 227], [228, 229], [230, 231], [0, 232], [316, 232], [317, 232], [318, 232], [319, 232],
				[320, 232], [321, 232], [322, 232], [323, 232], [319, 232], [318, 232], [317, 232], [316, 232],
				[0, 232], [230, 231], [228, 229], [226, 227]],
		],
		"death": [[0, 0, 0, 0], [0, 0, 0, 0]],
		"box": [8, 8, 24, 24],
		"rate": 10,
		"bullet": "S1/018",
		"speed": 6,
		"shot_x": 26,
		"shot_y": 2,
	},
}

# code 0x705b : the wall pod (type 4), S1 frames for 2 updates each, by side, and the
# opening frames it plays after firing (then it goes, 0x41fb)

const WALL_POD_FRAMES := [
	[["S1/012", 2], ["S1/013", 2], ["S1/014", 2], ["S1/013", 2]],
	[["S1/006", 2], ["S1/007", 2], ["S1/008", 2], ["S1/007", 2]],
]
const WALL_POD_OPEN := [
	[["S1/015", 2], ["S1/016", 2], ["S1/017", 2]],
	[["S1/009", 2], ["S1/010", 2], ["S1/011", 2]],
]

# code 0x2a48 : the small energy item gives 20, energy is at most 39

const ENERGY_ITEM := 20
const ENERGY_MAX := 39

# code 0x1784 : autofire, a counter of ds:0x9130 (8 at the start) lowered by the rate (1)
# while fire is held

const AUTOFIRE_PERIOD := 8

# code 0x2c32 : the double shot launcher, X2WEAPS 101 on the ship (cs:0xa658, static)

const DOUBLE_FRAMES := [["X2WEAPS/101", 0]]

# code 0x3801 : side shot bullet pictures by level, left (cs:0x12b2 : ds:0x44d8, 0x46b0,
# 0x4908) and right (cs:0x12be : ds:0x45c4, 0x47dc, 0x4a74), hot spot x, y, rows

const SIDE_LEFT_PICTURES := [
	[5, 2, [".##...", "####..", "######", "####..", ".##..."]],
	[6, 3, ["..##....", ".#####..", "#######.", "########", "#######.", ".#####..", "..##...."]],
	[9, 4, ["...#.....", ".#####...", ".######..", "########.", "#########", "########.", ".######..", ".#####...", "...#....."]],
]
const SIDE_RIGHT_PICTURES := [
	[0, 2, ["...##.", "..####", "######", "..####", "...##."]],
	[0, 3, ["....##..", "..#####.", ".#######", "########", ".#######", "..#####.", "....##.."]],
	[0, 4, ["......#...", "....#####.", "...######.", "..########", ".#########", "..########", "...######.", "....#####.", "......#..."]],
]

# code 0x2f08 and cs:0x140c : electro ball, X2WEAPS 12 to 20 a tick each. Damage cs:0x3da2.

const ELECTRO_FRAMES := [["X2WEAPS/012", 1], ["X2WEAPS/013", 1], ["X2WEAPS/014", 1], ["X2WEAPS/015", 1], ["X2WEAPS/016", 1], ["X2WEAPS/017", 1], ["X2WEAPS/018", 1], ["X2WEAPS/019", 1], ["X2WEAPS/020", 1]]
const ELECTRO_DAMAGE := 4

# code 0x2f7c, 0x3004 and cs:0x1342, 0x1354 : mines, X2WEAPS 59 to 61 (level 0) or 56 to 58
# (level 1), 2 ticks each

const MINE_FRAMES_SMALL := [["X2WEAPS/059", 2], ["X2WEAPS/060", 2], ["X2WEAPS/061", 2]]
const MINE_FRAMES_LARGE := [["X2WEAPS/056", 2], ["X2WEAPS/057", 2], ["X2WEAPS/058", 2]]

# code 0x31b6 and cs:0x118e : laser, X2WEAPS 4 to 11 a tick each. The beam (0xab7, f29:1478)
# draws its head (ds:0x32c8 : X2WEAPS 77, 89, 21 by level), once free its tail (ds:0x32c2 :
# X2WEAPS 78, 90, 22) and a column in colour 7, 8, 12 or 16 pixels wide (ds:0x33be).

const LASER_FRAMES := [["X2WEAPS/004", 1], ["X2WEAPS/005", 1], ["X2WEAPS/006", 1], ["X2WEAPS/007", 1], ["X2WEAPS/008", 1], ["X2WEAPS/009", 1], ["X2WEAPS/010", 1], ["X2WEAPS/011", 1]]
const BEAM_HEADS := ["X2WEAPS/077", "X2WEAPS/089", "X2WEAPS/021"]
const BEAM_TAILS := ["X2WEAPS/078", "X2WEAPS/090", "X2WEAPS/022"]
const BEAM_MASKS := [0xff00, 0xfff0, 0xffff]

# code 0x2e84 and cs:0x115a : drone, X2WEAPS 0 to 3 a tick each. Shots by level (ds:0x30ec) :
# x and y from the drone, then the step a frame.

const DRONE_FRAMES := [["X2WEAPS/000", 1], ["X2WEAPS/001", 1], ["X2WEAPS/002", 1], ["X2WEAPS/003", 1]]
const DRONE_SHOTS := [
	[[4, 4, 6, 6], [-8, 4, -6, 6], [-8, -8, -6, -6], [4, -8, 6, -6]],
	[[6, -2, 8, 0], [4, 4, 6, 6], [-2, 6, 0, 8], [-8, 4, -6, 6], [-10, -2, -8, 0], [-8, -8, -6, -6], [-2, -10, 0, -8], [4, -8, 6, -6]],
	[[6, -2, 8, 0], [5, 2, 7, 4], [2, 5, 4, 7], [-2, 6, 0, 8], [-6, 5, -4, 7], [-9, 2, -7, 4], [-10, -2, -8, 0], [-9, -6, -7, -4], [-6, -9, -4, -7], [-2, -10, 0, -8], [2, -9, 4, -7], [5, -6, 7, -4]],
]
# code 0x3126 and cs:0x1566 : the missile launcher, X2WEAPS 79 at rest, 80 to 85 after a
# shot. Code 0x2d2a and cs:0x1170 : the bomb, X2WEAPS 62 to 67. Code 0x2df0 and cs:0x110c :
# the flamer, X2WEAPS 91 to 94. cs:0x1288 : a flame, X2WEAPS 95 (2 ticks) to 100, then gone.
# cs:0x1380 on : the homing missile's frames by direction (0 up, clockwise), X2WEAPS
# 23 + 3d and 24 + 3d. ds:0x30dc and ds:0x30cc : its steps by direction.

const MISSILE_LAUNCHER_FRAMES := [["X2WEAPS/079", 0], ["X2WEAPS/080", 1], ["X2WEAPS/081", 1], ["X2WEAPS/082", 1], ["X2WEAPS/083", 1], ["X2WEAPS/084", 1], ["X2WEAPS/085", 1]]
const BOMB_FRAMES := [["X2WEAPS/062", 1], ["X2WEAPS/063", 1], ["X2WEAPS/064", 1], ["X2WEAPS/065", 1], ["X2WEAPS/066", 1], ["X2WEAPS/067", 1]]
const FLAMER_FRAMES := [["X2WEAPS/091", 1], ["X2WEAPS/092", 1], ["X2WEAPS/093", 1], ["X2WEAPS/094", 1]]
const FLAMER_FLAME_FRAMES := [["X2WEAPS/095", 2], ["X2WEAPS/096", 1], ["X2WEAPS/097", 1], ["X2WEAPS/098", 1], ["X2WEAPS/099", 1], ["X2WEAPS/100", 1]]
const HOMING_FRAMES := [
	[["X2WEAPS/023", 1], ["X2WEAPS/024", 1]], [["X2WEAPS/026", 1], ["X2WEAPS/027", 1]],
	[["X2WEAPS/029", 1], ["X2WEAPS/030", 1]], [["X2WEAPS/032", 1], ["X2WEAPS/033", 1]],
	[["X2WEAPS/035", 1], ["X2WEAPS/036", 1]], [["X2WEAPS/038", 1], ["X2WEAPS/039", 1]],
	[["X2WEAPS/041", 1], ["X2WEAPS/042", 1]], [["X2WEAPS/044", 1], ["X2WEAPS/045", 1]],
]
const HOMING_DX := [0, 4, 5, 4, 0, -4, -5, -4]
const HOMING_DY := [-5, -4, 0, 4, 5, 4, 0, -4]
const SPARK_COUNT := 80
const DRONE_DAMAGE := 0x5441

# code 0x46e4 : Super Nashwan Power lasts 0xaa frames, with a gauge at (0x98, 0xa0), X2SPR
# 117 to 126 by 10 * frames left / 0xab (ds:0x3262)

const NASHWAN_FRAMES := 0xaa

# code 0x3dbd : a dive lasts 0x88 frames, with a gauge at (0x98, 8) by 10 * frames left /
# 0x89. Code 0x449b : the ship's frames by the depth 1 to 4 (ds:0x3258).

const DIVE_FRAMES := [6, 90, 91, 92, 93]
const DIVE_FRAMES_LEFT := 0x88

# code 0x4fd7 : the bitmap shades last 0xdc frames, gauge by 10 * frames left / 0xde

const SHADES_FRAMES := 0xdd
const GAUGE_FIRST := 117

# the wave enemies' energy (ds:0x8e76 small, ds:0x8e78 large), times ds:0x991a (1 on a new
# game), set by each level init : level 1 1 and 2 (0x7637), level 2 1 and 2 (0x8f68),
# level 3 2 and 3 (0xacce), level 4 6 and 8 (0xc809), level 5 12 and 14 (0xe4f7)

const ENERGIES := {1: [1, 2], 2: [1, 2], 3: [2, 3], 4: [6, 8], 5: [12, 14]}

# code 0x3c4f, 0x4392, 0x1f9d : damage to the ship. code 0x3a33 : damage to a touched enemy

const CONTACT_DAMAGE_SMALL := 8
const CONTACT_DAMAGE_LARGE := 16
const BULLET_DAMAGE := 4
const RAM_DAMAGE := 0x7f

# code 0x1e29 : ground test, ds:0x329a. The ship's mask, 25 rows of 48 pixels (30 used),
# placed at (x - 14, y - 14). Shifted copies of it exist for each x within a tile.

const GROUND_MASK := [
	".............####.............",
	"............######............",
	"...........########...........",
	"...........########...........",
	"...........########...........",
	"...........########...........",
	"...........########...........",
	"...........########...........",
	"............######............",
	".........############.........",
	".........############.........",
	".........############.........",
	".........############.........",
	".........############.........",
	"...........########...........",
	"...........########...........",
	".........############.........",
	"........##############........",
	"......##################......",
	"....######################....",
	"...########################...",
	"..##########################..",
	".############################.",
	"########.#.########.#.########",
	"########.#....##....#.########",
]

# code 0x426a : 48 stars, each a row (rand mod 192), a byte column (rand mod 40) and a
# fraction of 0, from the generator at 0x4191 (seed = seed * 0x6255 + 0x3619)

const STAR_COUNT := 48

# code ds:0x304a : the generator starts at 0x7ab7. In the original it also runs before the
# stars are set up (0x3c94), for as long as the intro and title screens are shown, so the
# stars differ from game to game. The remake starts the level straight from 0x7ab7.

const STAR_SEED := 0x7ab7

# code 0x3d0d : before the main loop the map is drawn and the stars are moved once
# (ds:0x9198 = 1 from 0x1af1)

const STAR_LEAD := 1

# code 0xf3ef (EGA and VGA) : stars 0-15, 16-31, 32-47 are drawn in colours 4, 5, 7 of the
# level palette, one pixel at x = byte * 8 + 4, and only over pixels of colour 0

const STAR_COLOURS := [Color8(73, 73, 109), Color8(109, 109, 146), Color8(255, 219, 255)]

# code 0xff41 and 0x103da : hit flashes and the gun bullet use colour 7 of the level palette

const COLOUR_7 := Color8(255, 219, 255)

# code 0x10854, 0x108dc, 0x108f9, 0x10ad0 (EGA and VGA HUD). The screen is 40 bytes a row,
# the HUD starts at row 192. Digits are the 8x8 glyphs of GR.DAT (0x500 for the score,
# 0x640 for the lives), drawn opaque.

const SCORE_X := [24, 240]
const SCORE_Y := 192
const LIVES_POS := Vector2(136, 193)
const ENERGY_POS := Vector2(91, 195)
const LIVES_POSITIONS := [Vector2(136, 193), Vector2(176, 193)]
const ENERGY_POSITIONS := [Vector2(91, 195), Vector2(190, 195)]
const ENERGY_WIDTH := 39
const ENERGY_ROWS := 3
const ENERGY_COLOUR := Color8(255, 182, 0)

var map: Node2D
var world: Node2D
var star_layer: Node2D
var display_modulate: CanvasModulate
var shades_dark: ColorRect

# the Amiga flash of the Z (game $4926) : frames left, time to the next frame, the overlay
# and its own generator

const Z_FLASH_FRAMES := 30
const AMIGA_FRAME := 1.0 / 50.0
var z_flash_left := 0
var z_flash_time := 0.0
var z_flash: ColorRect
var z_flash_random := RandomNumberGenerator.new()
var level_palette: Array = []
var z_flash_test := -1
var hud: Sprite2D
var hud_values: Node2D
var tile_atlas: Texture2D
var tile_image: Image
var tile_flash := {}

# map words : tile << 6 | flag bit 0. drawn_words is the copy taken when the frame starts,
# because the original draws the map before the objects update (0x3d47).

var map_words: Array[int] = []
var drawn_words: Array[int] = []
var textures := {}
var flash_textures := {}
var headers := {}
var digit_textures: Array[Texture2D] = []
var gun_textures: Array[Texture2D] = []
var rear_textures: Array[Texture2D] = []

# weapons : 7 slots (ds:0x9134, type and launcher) : 0 front (base gun, double shot), 1 to 4
# side (cannons, lasers), 5 rear (rear shot, mines, electro ball, drone), 6 outer (side
# shot). Each launcher has a level and a maximum (+0x34 and +0x24). ds:0x915e is the speed
# level, ds:0x9130 the autofire period.

var weapon_slots: Array = [null, null, null, null, null, null, null]

# the launcher list (ds:0x9008), newest first

var launchers: Array = []
var speed_level := 0
var autofire_period := 8

# ds:0x8f34 the ship position before this frame's move, ds:0x8ebc the three positions
# before (the electro ball and the drone sit under the oldest), ds:0x8e86 mines out,
# ds:0x8f38 the last mine drop point, ds:0x9c80 the drone shots by entry (x, y, dx, dy),
# ds:0x91b4 the launchers and slots put aside by Super Nashwan Power

var ship_prev := Vector2i(START_X, SHIP_Y_MAX)
var trail: Array = []
var mines_out := 0
var mine_mark := Vector2i(-100, 0)
var sparks := {}
var spark_dots: Array = []
var gauge_frame := -1
var nashwan_saved := {}
var side_left_textures: Array[Texture2D] = []
var side_right_textures: Array[Texture2D] = []
var overlay: Node2D

var shot_path := ""
var shot_ticks := 0
var shot_fire := false
var test_presses: Array = []
var test_weapons: Array = []
var fire_until := -1
var test_nashwan := false
var time_left := 0.0

# ENHANCED (remake only, F5) : smooth motion. The game still moves everything in whole
# pixels once a tick (about 18 times a second); the picture is drawn at every frame of the
# screen, each object and the map between where they were at the last two ticks
# (smooth_alpha, 0 the one before, 1 the last). On by default, static, so F5 is kept for
# the next level and game. The positions of the tick before : px, py, pwy in each object,
# prev_* here. A flash drawn is cleared at the next tick (flash_drawn), as it is drawn
# more than once.

static var smooth := true
var smooth_alpha := 1.0
var prev_scroll := 0
var prev_drawn_scroll := 0
var prev_ship := Vector2.ZERO
var flash_later: Array = []
var ship_flash_later := false
const SMOOTH_JUMP := 32

var events: Array = []
var walls: Array = []
var paths: Array = []
var sine: Array = []
var enemy_types := {}

# object lists, newest first, as the lists at ds:0x9054 (enemies) and ds:0x90a0 (bullets,
# explosions, bonuses)

var enemies: Array = []
var effects: Array = []
var appended: Array = []

# the weapons saved at the last checkpoint (code 0x35eb, ds:0x916a) : (type, level) a slot

var saved_weapons: Array = []

# boss : ds:0x922b tentacle made, ds:0x91fe eye counter. Level end : ds:0x9164 bonuses
# still out, ds:0x8fb0 shop due, ds:0x922c mid level shop done, ds:0x8f61 level done.

var boss := {}

# the shop (shop.gd) and the state its items change : ds:0x91b2 the advice step (0 at the
# start of the game, 0x1b3c), ds:0x9162 Super Nashwan Power, ds:0x9160 dive, ds:0x9223
# protection, ds:0x9150 bitmap shades

var shop: Shop
var advice_step := 0

# sound (sound.gd, the PC speaker driver) : ds:0x8e88 the effect asked for, ds:0x8e8a an
# effect that goes first, both started and cleared by the timer interrupt. ds:0x8f54 music
# in play, 0 at the start (0x3c78) and switched in the title menu (0x5c00).
# remake : on at the start (the user's choice). Tests with --shot keep it off unless --music
# is given.

var sound: SpeakerSound
var sound_request := 0
var sound_priority := 0
var music_on := true
var music_kept := false
var music_asked := false
var wav_path := ""

# Amiga sound (amiga_sound.gd), chosen instead of the speaker : the Amiga game asks for
# its effects the same way, at $414 (played on channel 2) and $418 (channel 1), -1 when
# none. Each place below that asks the speaker for an effect also gives the Amiga effect
# the Amiga game asks for at the same place of its code (game addresses at base $400).

var amiga_sound: AmigaSound
var amiga_music: AmigaSound
var pc_request := 0
var title_tune_on := false
var tune_volume := 0x30
var use_amiga := true
var title: TitleScreen
var show_title := false

# what goes over to the next game after GAME OVER (0x3c9d keeps the generator and the
# settings)

static var carried := {}

# remake : the opening screen (title.gd) once a run, and the Enter key for it

static var intro_seen := false
var enter_event := false
var held_enter := false

# keys of the game's key table (cs:0x3d8f) : P pauses (0x3df8), Esc goes back to the title
# (0x3c9d). any_key : a key went down this tick (ds:0x8f58, any key).

var pause_event := false
var escape_event := false
var held_pause := false
var held_escape := false
var any_key := false
var paused := false

# code 0x66e : the keys chosen in Customise keys (ds:0x2fb8 to 0x300d), tested first by the
# keyboard handler (0x5eeb) ; the default keys keep working. Not saved to disk (as the
# original), but kept until the program ends : static, so the scene loaded again for the
# next level or a new game keeps them (as carried).
# last_key : the physical key of the last key press, for the customise screen.

static var custom_keys := {}

# ENHANCED (remake only, F4) : the picture as on a 4:3 screen of the time (PC VGA), each
# pixel 20% taller. Off at launch, kept for the next level and game. ORIGINAL keeps square
# pixels. --four-three turns it on for tests.

static var four_three := false

var last_key := 0

# Amiga graphics (tools/x2amiga.py) : the same tiles and sprites as the PC, plus the level's
# background picture under the map and the tiles' Amiga kinds (0 empty, 1 opaque, else 16
# mask rows), no stars. Game $436 : the background line at the top of the play area.

var use_amiga_gfx := true
var amiga_tiles := {}
var amiga_background: Texture2D
var amiga_masked := {}
var background_line := 0
var amiga_2 := -1
var amiga_1 := -1

# game $47d6 : the item routines of the Amiga game, a flag byte each. Items with the flag
# ask for effect 4 when picked up, the others for $81.

const AMIGA_ITEM_FLAGS := [0, 1, 2, 3, 6, 17]
var nashwan := 0
var dive := 0
var is_web := OS.has_feature("web")
var web_state := -1

# two players (code 0x1a19) : ds:0x8e70 the number of players, ds:0x8e7a the current one,
# ds:0x8f5d + p in the game, ds:0x8f5f + p done with the level and waiting. The other
# player's state is kept in stored (ds:0xce80, ds:0x8f62 and segment 1565 in the original),
# exchanged with the live one. level_end_now : ds:0x8f61 set without a shop due (0x3fbb).

var player_count := 1
var current := 0
var present := [true, false]
var waiting := [false, false]
var stored := {}
var level_end_now := false
var pristine_words: Array[int] = []
var player_defaults := {}
var test_players := 1
var test_items: Array = []

# what the swap exchanges : the block ds:0x8fb2 to 0x923d (object lists, weapons, score,
# credits, speed, dive, shades, Super Nashwan, energy, lives, continues, scroll and its
# limits, checkpoint, checkpoint weapons, shop advice, the levels' variables), the ship
# record ds:0x9f00 and the map ds:0 to 0x2edf

const PLAYER_VARS := [
	"launchers", "weapon_slots", "speed_level", "autofire_period", "autofire_rate",
	"mines_out", "nashwan", "nashwan_saved", "saved_weapons", "dive", "protection", "shades",
	"bonuses_out", "shield", "hole_counters", "hole_slots", "hole_rotations", "mid_shop_done", "scroll", "drawn_scroll", "scroll_max", "scroll_min",
	"scroll_base", "scroll_off_base", "wave_check", "wall_check", "checkpoint_scroll",
	"checkpoint_x", "checkpoint_credits", "score", "shown_score", "score_digits", "lives",
	"energy", "credits", "advice_step", "enemies", "effects", "boss", "blocks", "level2",
	"level3", "level4", "level5", "map_words", "ship_x", "ship_y", "tilt", "ship_frame",
]

# dive : ds:0x8e80 the depth (also 1 while dying), ds:0x8e82 its step, ds:0x8e84 the frames
# left under the ground. At depth 4 with the step 0 the ship is drawn by 0x897, under the
# map tiles. blocked : ds:0x8e80 not 0.

var depth := 0
var depth_step := 0
var dive_time := 0
var under_map := false
var dive_gauge := -1
var shades_gauge := -1
var blocked: bool:
	get:
		return depth != 0

# protection : ds:0x9223, halves the damage in 0x3c4f until the next shop (0x403e)

var protection := false

# ds:0x9188 : the shield's frames left. Every damage to the ship (0x3c4f) is skipped while
# it is not 0 (0x1f9d, 0x4381 and the levels' 0x8646, 0xc2bd, 0xd481, 0xd813, 0xdd66).
# Only the start of the game sets it to 0 (0x17f4) : its picture counts it down, so after a
# lost life (the picture gone with the effects) what is left stays, as in the original.

var shield := 0
var shield_gauge := -1

# level 1 hole creatures : ds:0x91d4 hole counters, ds:0x9226 slot bytes, ds:0x91f4 slot words

var hole_counters: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var hole_slots: Array = [false, false, false, false, false]
var hole_rotations: Array = HOLE_ROTATIONS.duplicate()
var shades := 0
var bonuses_out := 0
var shop_due := false
var mid_shop_done := false
var level_done := false
var finished := false

# random generator ds:0x304a, shared by stars, waves, enemy fire and bonuses

var seed := STAR_SEED
var stars: Array = []

# scroll : ds:0x9190 scroll, 0x919a asked, 0x9198 applied, 0x91a0 frames asked off base,
# 0x91aa upper limit, 0x9192 and 0x9194 last wave and wall check

var scroll := START_SCROLL
var drawn_scroll := START_SCROLL
var scroll_asked := 1
var scroll_applied := 1
var scroll_off_base := 0
var scroll_max := START_SCROLL_MAX

# ds:0x918c : the base scroll the ship asks for (0x43db, 0x454a), 1, and -1 while level 2's
# arena scrolls back (0x8820)

var scroll_base := 1
var wave_check := FIRST_CHECK
var wall_check := FIRST_CHECK

# ship : ds:0x9f00 record, 0x919e tilt, 0x8e7e push back, 0x8ecc history,
# 0x9224 dying, 0x8e80 blocked (dive or death), 0x991e attachment counter

var ship_x := START_X
var ship_y := SHIP_Y_MAX
var tilt := 0
var ship_frame := 8
var ship_box := [0, 0, 0, 0]
var ship_flash := false
var ship_visible := true
var push_back := 0
var history: Array = []
var flames: Array = []
var dying := false
var death_index := 0
var death_count := 0
var attach := 8
var life_lost := false

# checkpoint ds:0x91a6 scroll, 0x91a2 x

var checkpoint_scroll := START_SCROLL
var checkpoint_x := START_X
var checkpoint_credits := 0

# input : ds:0x8f59 held bits, 0x8f5b fire event, 0x912e autofire counter

var held_up := false
var held_down := false
var held_left := false
var held_right := false
var held_fire := false
var fire_event := false
var autofire := AUTOFIRE_PERIOD
var autofire_rate := 1

# enemy fire : the interpreter leaves BX behind, the fire code reads it (see _enemy_fire)

var path_bx := 0

# wave groups : ds:0x919c frame count, 0x91ac next id, 0x8eb0 / 0x8eb2 small and large ids,
# 0x8e8c eight (id, count) slots. unconfirmed : 0x8eb0 and 0x8eb2 taken as 0 before frame 4

var frame_count := 0
var next_group := 1
var small_group := 0
var large_group := 0
var groups: Array = []

# code 0x1790 : game start values. The score is ds:0x9152 and the shown score ds:0x9156,
# with its digits from the millions down at ds:0x921c (the units digit is never changed).
# Lives are ds:0x918a, energy ds:0x9186, credits ds:0x915a.

var score := 0
var shown_score := 0
var score_digits := [0, 0, 0, 0, 0, 0, 0]
# Code 0x1804 of this XENON2.EXE writes 0xff, a trainer patch : the same routine of the
# Amiga game ($6ba4) writes 3, and so does the PC continue (0x3f4b). The remake starts with 3.
var lives := 3
var energy := 39
var credits := 0

# ds:0x8f56 stops all damage in 0x3c4f (a crush by the ground still kills). The original's
# cheat (F7 in the display mode menu, 0x652, then the I key, 0x3db4) is not in the remake :
# only the test option sets it.

var invulnerable := false
var test_full := false

# ENHANCED (remake only) : F1 switches at once between ORIGINAL and ENHANCED (--enhanced
# starts in ENHANCED, for tests). In ENHANCED the pictures drawn in play come from assets_hd
# (xBRZ, tools/x2xbrz.py) through hd_texture.gd, which keeps the original sizes, and the
# canvas is drawn at the window's resolution. The game itself stays the original in 320x200.

const HD_TEXTURE = preload("res://scripts/hd_texture.gd")

# the xBRZ sheets of the masked tiles (colour 0 transparent, and the Amiga masks), for the
# masked tiles and the flashes, null without assets_hd

var tile_masked_hd: Image
var tile_amiga_hd: Image


func _ready() -> void:
	# ENHANCED is the default when playing ; --original starts in ORIGINAL. Test runs with
	# --shot stay ORIGINAL unless --enhanced.

	var original := false

	for arg in OS.get_cmdline_user_args():
		if arg == "--enhanced":
			HD_TEXTURE.on = true
		elif arg == "--original":
			original = true
			HD_TEXTURE.on = false
		elif arg == "--four-three":
			four_three = true
		elif arg.begins_with("--shot="):
			shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--ticks="):
			shot_ticks = int(arg.trim_prefix("--ticks="))
		elif arg == "--fire":
			shot_fire = true
		elif arg == "--cheat":

			# test option : no damage (ds:0x8f56)

			invulnerable = true
		elif arg.begins_with("--scroll="):

			# test option : start the level at this scroll, with the waves and wall objects
			# above it already passed

			var value := arg.trim_prefix("--scroll=")
			scroll = value.hex_to_int() if value.begins_with("0x") else int(value)
			scroll_max = scroll
			drawn_scroll = scroll
			wave_check = scroll + 1

			# as a restart at a checkpoint (0x195b) : the wall objects up to 0xc0 rows back

			wall_check = scroll + 1 + 0xbf
			mid_shop_done = scroll + SHIP_Y_MAX < MID_SHOP_LINE
			checkpoint_scroll = scroll
		elif arg == "--shop":

			# test option : a shop is due from the first tick (end of level shop when the
			# scroll is at 0x1e0 or less)

			shop_due = true
		elif arg.begins_with("--weapons="):

			# test option : weapons given at the start by slot type (0x29d7), for example
			# --weapons=0xc0,0x4c

			for value in arg.trim_prefix("--weapons=").split(","):
				test_weapons.append(value.hex_to_int())
		elif arg.begins_with("--fire-until="):

			# test option : with --fire, fire is let go from this tick on

			fire_until = int(arg.trim_prefix("--fire-until="))
		elif arg.begins_with("--level="):
			# test option : start at that level, as a new game

			level_number = int(arg.trim_prefix("--level="))
		elif arg.begins_with("--z-flash="):

			# test option : the Amiga Z flash starts at that tick

			z_flash_test = int(arg.trim_prefix("--z-flash="))
		elif arg.begins_with("--dives="):

			# test option : dives at the start (Enter)

			dive = int(arg.trim_prefix("--dives="))
		elif arg == "--shades":

			# test option : the bitmap shades at the start

			shades = 0xdc
		elif arg.begins_with("--item="):

			# test option : pod items collected at the start (index of ds:0x31d8)

			test_items.append(int(arg.trim_prefix("--item=")))
		elif arg.begins_with("--players="):

			# test option without the title : 1 or 2 players

			test_players = int(arg.trim_prefix("--players="))
		elif arg == "--protection":

			# test option : the protection at the start

			protection = true
		elif arg.begins_with("--lives="):

			# test option : lives at the start (3, see the lives variable)

			lives = int(arg.trim_prefix("--lives="))
		elif arg == "--music":
			music_asked = true
		elif arg == "--title":
			show_title = true
		elif arg == "--pc-graphics":

			# test option : the PC graphics from the start (the Amiga ones are the default, the
			# menu has the choice)

			use_amiga_gfx = false
		elif arg == "--pc-sound":

			# test option : the PC speaker from the start (the Amiga sound is the default, the
			# menu has the choice)

			use_amiga = false
		elif arg.begins_with("--wav="):

			# test option : with --shot, the speaker is written to this WAV file

			wav_path = arg.trim_prefix("--wav=")
		elif arg == "--full":

			# test option : the weapons of Super Nashwan Power (0x2b22) kept for good, so
			# saved at the checkpoints and given back after a lost life

			test_full = true
		elif arg == "--nashwan":

			# test option : Super Nashwan Power from the start

			test_nashwan = true
		elif arg.begins_with("--credits="):
			credits = int(arg.trim_prefix("--credits="))
		elif arg.begins_with("--press="):
			for entry in arg.trim_prefix("--press=").split(","):
				var parts := entry.split(":")
				test_presses.append([int(parts[0]), parts[1]])

	if shot_path != "" and not music_asked:
		music_on = false

	# only at launch : a reloaded scene (next level, after GAME OVER) keeps the choice

	if shot_path == "" and not original and not intro_seen and carried.is_empty():
		HD_TEXTURE.on = true

	if shot_path == "":
		_size_window()

	# a game after GAME OVER : the generator and the settings of the last one

	if not carried.is_empty():
		seed = carried["seed"]
		music_on = carried["music"]
		use_amiga = carried["amiga_sound"]
		use_amiga_gfx = carried["amiga_graphics"]

	# the next level (_next_level) : what goes on from the last one

	var next: Dictionary = carried.get("next", {})

	# the values a player starts with (code 0x16ba), after the test options

	for name in PLAYER_VARS:
		player_defaults[name] = _copy(get(name))

	if not next.is_empty():
		level_number = next["level"]
		stars = next["stars"]
		game_loop = next.get("loop", 1)

	LEVEL = "S%d" % level_number
	_load_headers("X2SPR")
	_load_headers("X2WEAPS")
	_load_headers(LEVEL)
	_load_level()

	# test option : --scroll at a checkpoint's y starts there as from that checkpoint, the
	# ship at its x

	for wall in walls:
		if int(wall["type"]) == 0 and int(wall["y"]) == scroll and scroll != START_SCROLL:
			ship_x = int(wall["x"])
			checkpoint_x = ship_x
			checkpoint_scroll = scroll

	for picture in GUN_PICTURES:
		gun_textures.append(_make_bullet_texture(picture[2]))

	for picture in REAR_PICTURES:
		rear_textures.append(_make_bullet_texture(picture[2]))

	for picture in SIDE_LEFT_PICTURES:
		side_left_textures.append(_make_bullet_texture(picture[2]))

	for picture in SIDE_RIGHT_PICTURES:
		side_right_textures.append(_make_bullet_texture(picture[2]))

	_fill_trail()

	for i in 8:
		groups.append([0, 0])

	for index in [3, 2, 1, 0]:
		flames.append({"index": index, "frame": 0, "count": 1, "x": 0, "y": 0, "visible": false})

	# code 0x985 : the map is drawn tile by tile every frame from the map words (ds:0),
	# 20 words a row, tile = word >> 6, which objects may rewrite while the game runs

	_set_enhanced(HD_TEXTURE.on)
	tile_atlas = _gfx("res://assets/tiles/%s_tiles.png" % LEVEL)

	if FileAccess.file_exists("res://data/amiga_%s.json" % LEVEL):
		var amiga_level: Dictionary = _read_json("res://data/amiga_%s.json" % LEVEL)
		amiga_tiles = amiga_level["tiles"]
		level_palette = amiga_level.get("palette", [])
		amiga_background = _gfx("res://assets/amiga/%s_background.png" % LEVEL)

	if amiga_background == null:
		use_amiga_gfx = false

	_amiga_display()

	if not FileAccess.file_exists("res://data/amiga_sound.bin"):
		use_amiga = false
	tile_image = _image(tile_atlas)
	tile_masked_hd = _hd_image("res://assets_hd/tiles/%s_tiles_masked.png" % LEVEL)
	tile_amiga_hd = _hd_image("res://assets_hd/tiles/%s_tiles_amiga.png" % LEVEL)
	tile_image.convert(Image.FORMAT_RGB8)
	map = Node2D.new()
	map.draw.connect(_draw_map)
	add_child(map)

	world = Node2D.new()
	world.draw.connect(_draw_world)
	add_child(world)

	# code 0x3d1c : the stars are drawn after all objects, so a star shows only where
	# the finished picture is still colour 0

	star_layer = Node2D.new()
	star_layer.draw.connect(_draw_stars)
	var star_shader := Shader.new()
	star_shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
void fragment() {
	if (texture(screen_texture, SCREEN_UV).rgb != vec3(0.0)) {
		discard;
	}
}
"""
	star_layer.material = ShaderMaterial.new()
	star_layer.material.shader = star_shader
	add_child(star_layer)

	# code 0x3c94 : at the start of the program only

	if carried.is_empty():
		_init_stars()

	# code 0x4675 and 0xa95 : the Super Nashwan Power gauge and the drone shots are drawn
	# after the stars

	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)

	hud = Sprite2D.new()
	hud.texture = _gfx("res://assets/gr/hud_bar.png")
	hud.centered = false
	hud.position = Vector2(0, PLAY_HEIGHT)
	add_child(hud)

	for i in 20:
		digit_textures.append(_gfx("res://assets/gr/hud_digits/%02d.png" % i))

	hud_values = Node2D.new()
	hud_values.draw.connect(_draw_hud)
	add_child(hud_values)

	shop = Shop.new()
	shop.main = self
	add_child(shop)

	sound = SpeakerSound.new()
	sound.record = wav_path != "" and not use_amiga
	add_child(sound)
	amiga_sound = AmigaSound.new()
	amiga_sound.record = wav_path != "" and use_amiga
	add_child(amiga_sound)

	# ENHANCED : the full arrangement of the tune (the loading screen music of the original
	# release, 39 instruments) on a second player, music only, the effects staying with the
	# game's player

	var full := AmigaSound.new()

	if full.use_intro_music():
		amiga_music = full
		amiga_music.record = amiga_sound.record
		add_child(amiga_music)

	# code 0x3c75 : the title sequence comes first (title.gd). Tests with --shot skip it
	# unless --title is given.

	title = TitleScreen.new()
	title.main = self
	add_child(title)

	_player_level_init(next, true)

	for index in test_items:
		_collect_item(index)

	# two players : the other one set up the same way (code 0x1b7f : swap, 0x1aaf, swap)

	var players: Dictionary = next.get("players", {})

	if not players.is_empty():
		player_count = players["count"]
		current = players["current"]
		present = players["present"].duplicate()

		if player_count == 2:
			_make_second_player(next["other"])

	_fill_history()
	ship_box = _box("X2SPR", ship_frame, ship_x, ship_y)
	_place()

	if not next.is_empty():
		if shot_path == "":
			title.loading(level_number)
		else:
			_level_loaded()
	elif shot_path == "" or show_title:
		title.open()
	else:
		_title_done()

		if test_players == 2:
			start_players(2)

	if shot_path != "":
		for i in shot_ticks:
			var fire := shot_fire and (fire_until < 0 or i < fire_until)

			if fire and not held_fire:
				fire_event = true

			held_fire = fire
			_test_presses(i)
			_step()

			if i == z_flash_test:
				_z_flash_start()

			_z_flash_advance(TICK_SECONDS)

		_place()
		print("state scroll=%d lives=%d energy=%d boss_made=%s boss_phase=%d boss_energy=%d boss_y=%d reach=%d enemies=%d bonuses=%d done=%s finished=%s credits=%d" % [scroll, lives, energy, boss["made"], boss["phase"], boss["energy"], boss["y"], boss["reach"], enemies.size(), bonuses_out, level_done, finished, credits])
		_save_shot()


func _process(delta: float) -> void:
	if shot_path != "":
		return

	time_left += delta
	_z_flash_advance(delta)

	while time_left >= TICK_SECONDS and not finished:
		time_left -= TICK_SECONDS
		_read_input()
		_remember()
		_step()
		_place()

	_smooth_frame()

	# remake, the browser : the touch controls of the page (web/touch.html) are a joystick in
	# a level, arrows on the menus and in the shop, and show DIVE while a dive is left

	if is_web:
		var level := not title.running and not shop.running
		var state := (1000 + dive) if level else 0

		if state != web_state:
			web_state = state
			JavaScriptBridge.eval("window.x2state && window.x2state(%s, %d)" % ["true" if level else "false", dive])


func _step() -> void:

	# one game tick : the shop runs in place of the game while it is open

	if title.running:
		title.tick()
	elif shop.running:
		shop.tick()
	elif paused:
		_pause_tick()
	else:
		_tick()

	# code 0x600b : three driver calls, then the effect asked for (ds:0x8e8a first). On the
	# Amiga, the vertical blanks of one game tick (game $215e), the first one starting the
	# effects asked for.

	var request := sound_priority if sound_priority != 0 else sound_request
	sound_priority = 0
	sound_request = 0

	if use_amiga:
		amiga_sound.request_2 = amiga_2
		amiga_sound.request_1 = amiga_1
		amiga_2 = -1
		amiga_1 = -1
		amiga_sound.vblank_ticks(TICK_SECONDS)

		if amiga_music != null:
			amiga_music.vblank_ticks(TICK_SECONDS)

		# remake : the speaker still runs for the PC sounds of the opening screen
		# (pc_request), silent otherwise

		sound.game_tick(pc_request & 0xff)
	else:
		sound.game_tick((request if request != 0 else pc_request) & 0xff)

	pc_request = 0


func _smoothing() -> bool:

	# smooth motion only while a level plays in ENHANCED

	return smooth and HD_TEXTURE.on and shot_path == "" and not title.running and not shop.running and not paused and map != null


func _remember() -> void:

	# before a tick : where everything is now, and the flashes drawn since the last tick
	# end (drawn more than once while smooth)

	for d in flash_later:
		d["flash"] = false

	flash_later.clear()

	if ship_flash_later:
		ship_flash = false
		ship_flash_later = false

	if not _smoothing():
		return

	prev_scroll = scroll
	prev_drawn_scroll = drawn_scroll
	prev_ship = Vector2(ship_x, ship_y)

	for list in [enemies, effects, launchers, flames, stars]:
		for d in list:
			d["px"] = d.get("x", 0)
			d["py"] = d.get("y", 0)

			if d.has("world_y"):
				d["pwy"] = d["world_y"]

	if not boss.is_empty():
		boss["py"] = boss.get("y", 0)


func _smooth_frame() -> void:

	# every frame of the screen : how far the picture is between the last two ticks, the
	# map moved by the part of the scroll not yet shown, the objects drawn again

	if not _smoothing():
		if smooth_alpha < 1.0 or (map != null and map.position != Vector2.ZERO):
			smooth_alpha = 1.0
			map.position = Vector2.ZERO
			_place()

		return

	smooth_alpha = clampf(time_left / TICK_SECONDS, 0.0, 1.0)
	map.position = Vector2(0, _limited(drawn_scroll - prev_drawn_scroll))
	world.queue_redraw()
	star_layer.queue_redraw()


func _limited(step: float) -> float:

	# a move of the last tick, the part not yet shown ; a jump (a new place) is not smoothed

	if absf(step) > SMOOTH_JUMP:
		return 0.0

	return step * (1.0 - smooth_alpha)


func _scroll_lag() -> Vector2:

	# what is fixed on the map : it goes with the scroll

	if smooth_alpha >= 1.0:
		return Vector2.ZERO

	return Vector2(0, _limited(scroll - prev_scroll))


func _lag(d: Dictionary, fixed_x := false, fixed_y := false) -> Vector2:

	# an object : the part of its last move not yet shown (16.16 positions in units of
	# 65536), with world_y as the scroll moves it

	if smooth_alpha >= 1.0 or not d.has("px"):
		return Vector2.ZERO

	var dx := float(d["px"] - d.get("x", 0))
	var dy := float(d["py"] - d.get("y", 0))

	if fixed_x:
		dx /= 65536.0

	if fixed_y:
		dy /= 65536.0

	if d.has("pwy") and d.has("world_y"):
		dy = float(d["pwy"] - prev_scroll) - float(d["world_y"] - scroll)

	return Vector2(_limited(dx), _limited(dy))


func flash_drawn(d: Dictionary) -> void:

	# a hit flash has been drawn : cleared now, or at the next tick while smooth

	if _smoothing():
		flash_later.append(d)
	else:
		d["flash"] = false


func _title_done() -> void:

	# code 0x5950 : the game's stars are set up again (0x426a), from where the title left
	# the generator. Code 0x3d00 : the level tune when music is on.

	_init_stars()

	if music_on:
		_start_level_tune()

	_place()


func _size_window() -> void:

	# remake : the window 4 times 320x200 as the eye sees it, so times the screen's scaling
	# (Windows counts the window in physical pixels), at most the largest whole multiple that
	# fits the usable screen, centred

	var screen := DisplayServer.window_get_current_screen()
	var scaling := DisplayServer.screen_get_dpi(screen) / 96.0
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var times := maxi(1, roundi(4 * scaling))
	var high := _screen_height()

	while times > 1 and (320 * times > usable.size.x or high * times > usable.size.y - 40):
		times -= 1

	var size := Vector2i(320 * times, high * times)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


func _level_loaded() -> void:

	# code 0x416c : the next level, after LOADING LEVEL n, goes through the restart (0x1a62)
	# as after a lost life, GET READY PLAYER n included, the ship at the level's start. With
	# two players the other one starts it.

	_switch_turn()


func _title_tune() -> void:

	# code 0x5863 : tune 0 whatever the music setting. Amiga game $8230 : tune 0, then 0x3f
	# at the high byte of the player's volume.

	title_tune_on = true

	if use_amiga:
		_amiga_tune(0x3f)
	else:
		sound.call_driver(2, 0)


func _tune_player() -> AmigaSound:

	# ENHANCED plays the full arrangement when its data is there

	return amiga_music if HD_TEXTURE.on and amiga_music != null else amiga_sound


func _amiga_tune(volume_byte: int) -> void:

	# tune 0 on the player of the version shown, the other one silent

	tune_volume = volume_byte
	var player := _tune_player()

	if amiga_music != null and player != amiga_music:
		amiga_music.stop()

	if player != amiga_sound:
		amiga_sound.stop()

	player.start_tune(0, volume_byte)


func _menu_sound(pc: int, amiga: int) -> void:

	# code 0x5bad, 0x5bf3 : effects 8 and 9. Amiga game $8d60, $8da2 : $c and $d.

	sound_request = pc
	amiga_2 = amiga


func _switch_graphics(amiga: bool) -> void:

	# remake : the graphics line of the menu, Amiga only when its files are there

	use_amiga_gfx = amiga and amiga_background != null
	_amiga_display()


func _amiga_display() -> void:

	# The Amiga game keeps the same 3 bit colours, but doubles them for its 4 bit colour
	# registers ($63b4, $83f0 and the others writing $dff180), so 7 is 14 of 15 : every
	# colour 14 / 15 of the PC's (VGA 7 is 63 of 63). The pictures of the remake carry the
	# PC values, so with the Amiga graphics the whole screen is multiplied by 14 / 15.

	if display_modulate == null:
		display_modulate = CanvasModulate.new()
		add_child(display_modulate)

	var v := 14.0 / 15.0 if use_amiga_gfx else 1.0
	display_modulate.color = Color(v, v, v)


func _shades_display() -> void:

	# Amiga game : the shop's item sets $c90 = $dc (shop $b30), and while it is not 0 the
	# palette is set halved, each 3 bit colour shifted right (and masked $777, $7a86, $912c),
	# before its doubling for the colour registers. Back at 0 ($639c) the palette comes back.
	# The Amiga game has no gauge for it (the remake keeps the PC's). With the Amiga graphics,
	# only while the game plays (the title, the shop and GET READY have their own palettes),
	# the remake darkens the screen the same way : the screen holds 2c / 15, the CanvasModulate takes 14 / 15
	# again. unconfirmed : whether the Amiga HUD has a palette of its own ; here the whole
	# screen goes dark, as with the Z.

	var on := use_amiga_gfx and shades != 0 and not title.running and not shop.running

	if shades_dark == null:
		if not on:
			return

		shades_dark = ColorRect.new()
		shades_dark.size = Vector2(320, 200)
		shades_dark.z_index = 4095
		shades_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
void fragment() {
	vec3 c = floor(texture(screen_texture, SCREEN_UV).rgb * 7.5 + 0.5);
	COLOR = vec4(floor(c / 2.0) / 7.0, 1.0);
}
"""
		var material := ShaderMaterial.new()
		material.shader = shader
		shades_dark.material = material
		add_child(shades_dark)

	shades_dark.visible = on


func _z_flash_start() -> void:

	# game $4926 (Amiga graphics only) : for 30 frames each of the 16 colours is white
	# ($777, doubled $eee) or black by the bits of a random word, low bit colour 0, then the
	# palette comes back. The Amiga game waits there and so stops for the 30 frames ; the
	# remake only shows it, the PC game goes on. The Amiga generator ($1f50) is not the
	# PC's, so the remake uses one of its own, leaving the game's alone. unconfirmed : whether
	# the Amiga HUD has a palette of its own and so does not flash ; here the whole screen does.

	if not use_amiga_gfx or level_palette.size() < 16:
		return

	if z_flash == null:
		z_flash = ColorRect.new()
		z_flash.size = Vector2(320, 200)
		z_flash.z_index = 4096
		z_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec3 palette[16];
uniform int mask;
void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	COLOR = vec4(0.0);
	for (int i = 0; i < 16; i++) {
		if (distance(c, palette[i]) < 0.01) {
			COLOR = vec4(vec3(((mask >> i) & 1) == 1 ? 1.0 : 0.0), 1.0);
			break;
		}
	}
}
"""
		var material := ShaderMaterial.new()
		material.shader = shader
		z_flash.material = material
		add_child(z_flash)

	# the screen holds the colours already darkened by 14 / 15

	var colours := PackedVector3Array()

	for c in level_palette:
		colours.append(Vector3(c[0], c[1], c[2]) / 255.0 * 14.0 / 15.0)

	(z_flash.material as ShaderMaterial).set_shader_parameter("palette", colours)
	z_flash_left = Z_FLASH_FRAMES
	z_flash_time = 0.0
	_z_flash_frame()


func _z_flash_frame() -> void:
	(z_flash.material as ShaderMaterial).set_shader_parameter("mask", z_flash_random.randi() & 0xffff)
	z_flash.visible = true


func _z_flash_advance(seconds: float) -> void:
	if z_flash_left <= 0:
		return

	z_flash_time += seconds

	while z_flash_time >= AMIGA_FRAME and z_flash_left > 0:
		z_flash_time -= AMIGA_FRAME
		z_flash_left -= 1

		if z_flash_left > 0:
			_z_flash_frame()
		else:
			z_flash.visible = false


func _switch_sound(amiga: bool) -> void:

	# remake : the sound line of the menu, the other player is silenced

	_stop_sound()
	use_amiga = amiga


func _start_level_tune() -> void:

	# PC : tune 0 (code 0x3d00). Amiga : tune 0, then the byte 0x30 at the high byte of the
	# player's master volume (game $7894 and the like).

	if use_amiga:
		_amiga_tune(0x30)
	else:
		sound.call_driver(2, 0)


func _shop_tune() -> void:

	# code 0x4c6c : the sound stops and the shop tune starts. The Amiga shop has no tune :
	# at the same place (the left door up, shop $55276) it plays its sample 3 on channel 0,
	# called at once. unconfirmed : the right door reaching 0 asks for the word at $8
	# ($55296, an effect from the exception vectors), not played here.

	if use_amiga:
		amiga_sound.effect_now(0x83)
		return

	_stop_sound()
	sound.call_driver(2, 1)


func _stop_sound() -> void:

	title_tune_on = false

	# PC : interrupt 0x80, function 1. Amiga : $19fba.

	if use_amiga:
		amiga_sound.stop()

		if amiga_music != null:
			amiga_music.stop()
	else:
		sound.call_driver(1, 0)


func _test_presses(tick: int) -> void:

	# test option --press=tick:key,... : the key is held for that one tick (fire also
	# raises the fire event)

	held_up = false
	held_down = false
	held_left = false
	held_right = false

	for entry in test_presses:
		if entry[0] != tick:
			continue

		match entry[1]:
			"up":
				held_up = true
			"down":
				held_down = true
			"left":
				held_left = true
			"right":
				held_right = true
			"fire":
				fire_event = true
			"enter":
				enter_event = true


func _read_input() -> void:

	# code 0x5eeb : a fire press raises the fire event at once, holding it only sets the bit

	# code 0x60a5 : the joystick (port 0x201), either button fires. The custom keys first.

	var fire := Input.is_physical_key_pressed(KEY_SPACE) or _custom_held("fire")
	fire = fire or Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_joy_button_pressed(0, JOY_BUTTON_B)

	if fire and not held_fire:
		fire_event = true

	held_fire = fire
	# code 0x5fee : the custom dive key stands for Enter

	var enter := Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER) or _custom_held("dive")

	if enter and not held_enter:
		enter_event = true

	held_enter = enter
	var pause_key := Input.is_physical_key_pressed(KEY_P)

	if pause_key and not held_pause:
		pause_event = true

	held_pause = pause_key
	var escape_key := Input.is_physical_key_pressed(KEY_ESCAPE)

	if escape_key and not held_escape:
		escape_event = true

	held_escape = escape_key
	# the keypad 8, 2, 4 and 6 send the arrows' scancodes, keypad 5 is down too (0x5f67)

	held_up = Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_KP_8) or _custom_held("up")
	held_down = Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_KP_2) or Input.is_physical_key_pressed(KEY_KP_5) or _custom_held("down")
	held_left = Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_KP_4) or _custom_held("left")
	held_right = Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_KP_6) or _custom_held("right")


func _tick() -> void:
	shield_gauge = -1

	# code 0x3d26 : wave group ids are renewed every 4 frames

	frame_count += 1

	if frame_count & 3 == 0:
		small_group = next_group
		large_group = next_group + 1
		next_group += 2

	scroll_asked = 1
	drawn_scroll = scroll
	drawn_words = map_words.duplicate()
	_count_score()
	_level_hook()

	# code 0x3682 : updates list by list (ship, enemies, launchers newest first, bullets and
	# effects), then the draws, then the group slots no enemy carries any more are cleared

	_update_ship()
	_update_flames()
	_update_enemies()

	var latched := fire_event
	fire_event = false

	for launcher in launchers.duplicate():
		if launcher["freed"]:
			continue

		match launcher["kind"]:
			"gun":
				_update_gun(launcher, latched)
			"double":
				_update_double(launcher, latched)
			"side":
				_update_side(launcher, latched)
			"rear":
				_update_rear(launcher, latched)
			"cannon":
				_update_cannon(launcher, latched)
			"laser":
				_update_laser(launcher, latched)
			"electro":
				_update_electro(launcher)
			"mine":
				_update_mine_launcher(launcher)
			"drone":
				_update_drone(launcher)
			"missile_launcher":
				_update_missile_launcher(launcher, latched)
			"bomb_launcher":
				_update_bomb_launcher(launcher, latched)
			"homing_launcher":
				_update_homing_launcher(launcher, latched)
			"flamer":
				_update_flamer(launcher)

	_update_effects()

	if level2 != null:
		level2.update_tile_objects()

	if level4 != null:
		level4.update_tile_objects()

	_clear_groups()

	_move_stars(scroll_applied)
	_update_counters()
	_update_sparks()
	_game_keys()
	_check_waves()
	_scroll()

	# Amiga game $1f22 : the background goes back by half the scroll, one more on odd
	# frames when the scroll is odd, wrapping at 192 lines. unconfirmed : the PC frame and
	# scroll stand for the Amiga ones.

	var step := (scroll_applied >> 1) + (frame_count & 1 & scroll_applied)
	background_line = posmod(background_line - step, 0xc0)

	if life_lost:
		_lose_life()

	_check_shop()


func _level_hook() -> void:

	# code 0xff0 : the hook of the level (table cs:0x1002)

	if level2 != null:
		level2.hook()
		return

	if level3 != null:
		level3.hook()
		return

	if level4 != null:
		level4.hook()
		return

	if level_number != 1:
		return

	# code 0x655b : the mid level shop, once

	if not mid_shop_done and scroll + ship_y < MID_SHOP_LINE:
		mid_shop_done = true
		shop_due = true
		scroll = MID_SHOP_SCROLL
		scroll_max = MID_SHOP_SCROLL

	_hole_hook()


func _hole_hook() -> void:

	# code 0x6590 : while the scroll is 0xa40 to 0xd10 the back limit is at least 0xd10, the
	# spawner runs (0x6807) and the hole cells play their tiles. Code 0x65dc : every frame the
	# slot bytes are cleared ; a living creature sets its own again.

	if scroll >= HOLE_FIRST and scroll <= HOLE_LAST:
		scroll_max = maxi(scroll_max, HOLE_LAST)

		for slot in 5:
			if not hole_slots[slot]:
				hole_slots[slot] = true
				_spawn_hole_creature(slot)

		for i in 16:
			if hole_counters[i] != 0:
				hole_counters[i] -= 1
				var cell: Array = HOLE_CELLS[i]
				map_words[cell[0]] = cell[1][hole_counters[i] & 3]

	for slot in 5:
		hole_slots[slot] = false


func _spawn_hole_creature(slot: int) -> void:

	# code 0x6823 : the slot's word turned right by 3, its low nibble the entry. The entry
	# hole opens, then a leader and the segments, head first, at the front of the enemies.

	var word: int = hole_rotations[slot]
	word = ((word >> 3) | (word << 13)) & 0xffff
	hole_rotations[slot] = word
	var entry: Array = HOLE_SPAWNS[word & 0xf]
	var x: int = entry[0]
	var y: int = entry[1] - scroll_asked - scroll

	if hole_counters[entry[2]] == 0:
		hole_counters[entry[2]] = HOLE_OPEN

	var leader := {
		"kind": "hole_leader",
		"slot": slot,
		"exit": entry[3],
		"path": paths[entry[4]],
		"origin": Vector2i(x, y),
		"x": x,
		"y": y,
		"steps": 0,
		"heading": 0,
		"exited": false,
		"box": [1000, 0, 1000, 0],
		"dead": false,
		"flash": false,
		"large": false,
		"group": 0,
		"head": null,
		"hit": "none",
		"energy": 1,
	}
	enemies.push_front(leader)
	var before: Dictionary = leader

	for k in HOLE_SEGMENTS:
		var head := k == 0
		var segment := {
			"kind": "hole_segment",
			"head_part": head,
			"slot": slot,
			"exit": entry[3],
			"pred": before,
			"x": x,
			"y": y,
			"steps": -HOLE_DELAY * k,
			"heading": 0,
			"shown": false,
			"exited": false,
			"copied_dead": false,
			"key": HOLE_HEAD_FRAMES[0] if head else HOLE_BODY_FRAMES[0],
			"energy": 1,
			"score": HOLE_SCORES[0] if head else HOLE_SCORES[1],
			"hit": "0x66a6" if head else "0x6696",
			"box": [1000, 0, 1000, 0],
			"dead": false,
			"flash": false,
			"large": false,
			"group": 0,
			"head": null,
		}
		segment["box"] = _box_of(segment["key"], x, y)
		enemies.push_front(segment)
		before = segment


func _update_hole_leader(leader: Dictionary) -> void:

	# code 0x6aad : moves with the scroll, marks its slot, 4 steps of its path. At the end it
	# goes at once (0x49b5, 0xf2b).

	var origin: Vector2i = leader["origin"]
	origin.y += scroll_applied
	leader["origin"] = origin
	hole_slots[leader["slot"]] = true
	var path: Dictionary = leader["path"]
	var points: Array = path["points"]
	var total := points.size()
	var ended: bool = leader["steps"] >= total

	if not ended:
		leader["steps"] += HOLE_SPEED
		ended = leader["steps"] > total

	if ended:
		leader["dead"] = true
		leader["exited"] = true
		return

	var steps: int = leader["steps"]
	var start: Vector2i = path["start"]
	var point: Vector2i = start if steps <= 0 else points[steps - 1]
	leader["x"] = origin.x + point.x - start.x
	leader["y"] = origin.y + point.y - start.y

	if steps > 0:
		leader["heading"] = path["angles"][steps - 1]


func _update_hole_segment(segment: Dictionary) -> void:

	# code 0x6a0a : marks its slot, then copies the one before it in the list (updated after
	# it, so as it was last frame). With the leader or the segment before gone (0xbc next) it
	# goes at once and opens its exit hole. A segment shot dead stays linked until its own
	# update, so its follower copies it once more.

	hole_slots[segment["slot"]] = true
	var pred: Dictionary = segment["pred"]

	while pred["dead"] and not pred["exited"] and pred["copied_dead"]:
		pred = pred["pred"]
		segment["pred"] = pred

	if pred["exited"]:
		if hole_counters[segment["exit"]] == 0:
			hole_counters[segment["exit"]] = HOLE_OPEN

		segment["dead"] = true
		segment["exited"] = true
		return

	if pred["dead"]:
		pred["copied_dead"] = true

	segment["x"] = pred["x"]
	segment["y"] = pred["y"] + scroll_applied
	segment["heading"] = pred["heading"]
	segment["steps"] = pred["steps"]

	# code 0x6a55 : drawn from the first copy with steps not below 0

	if not segment["shown"] and segment["steps"] >= 0:
		segment["shown"] = true

	var octant: int = ((int(segment["heading"]) + 16) >> 4) & 7
	segment["key"] = (HOLE_HEAD_FRAMES if segment["head_part"] else HOLE_BODY_FRAMES)[octant]
	segment["box"] = _box_of(segment["key"], segment["x"], segment["y"])


func _hole_hit(segment: Dictionary, damage: int) -> void:

	# code 0x6696 (body), 0x66a6 (head) : a flash, the damage ; at 0 or below (always, energy
	# 1) debris on the effects list with a random angle, the score, the segment goes. The
	# head's death does nothing to the body.

	segment["flash"] = true
	segment["energy"] -= damage

	if segment["energy"] > 0:
		return

	var frames: Array = HOLE_HEAD_DEBRIS if segment["head_part"] else HOLE_BODY_DEBRIS
	effects.push_front({
		"kind": "hole_debris",
		"x": segment["x"],
		"y": segment["y"],
		"frames": frames,
		"anim": 0,
		"count": frames[0][1],
		"angle": _random() & 0xff,
		"box": [1000, 0, 1000, 0],
		"dead": false,
	})
	score += segment["score"]
	segment["dead"] = true


func _update_hole_debris(debris: Dictionary) -> void:

	# code 0x69d0 : its animation, then flies by the sine table / 4 on the screen, gone
	# outside 320x192 (y tested first)

	_step_animation(debris, debris["frames"], 0)
	var angle: int = debris["angle"]
	var y: int = debris["y"] + (int(sine[angle & 0xff]) >> 2)

	if y < 0 or y >= PLAY_HEIGHT:
		debris["dead"] = true
		return

	var x: int = debris["x"] + (int(sine[(angle + 64) & 0xff]) >> 2)

	if x < 0 or x >= 320:
		debris["dead"] = true
		return

	debris["x"] = x
	debris["y"] = y


func _check_shop() -> void:

	# code 0x3fb4 : once every bonus is gone and a shop is due, the credits get their floor
	# and the shop opens (0x4a69, shop.gd). The floor is compared with the low word of the
	# credits as a signed number, and only while the high word is 0.

	if bonuses_out != 0:
		return

	# code 0x3fbb : the level done without a shop due, the next level at once (two players,
	# the waiting one left alone, 0x1a9c)

	if not shop_due:
		if level_end_now and level_done:
			level_end_now = false
			_next_level()

		return

	shop_due = false

	# code 0x3fc8 : the sound stops

	_stop_sound()
	var cap := end_shop_cap if scroll <= END_SHOP_LINE else mid_shop_cap
	var floor := cap + 0x190 if scroll <= END_SHOP_LINE else cap
	var low := credits & 0xffff

	if low >= 0x8000:
		low -= 0x10000

	if credits >> 16 == 0 and floor > low:
		credits = floor + (_random() & 3) * 50

	# code 0x403e : the protection ends. Level 5 has its last shop (ds:0x8fb1), not here.

	protection = false

	# code 0x4043 : on level 5 the shop at scroll 0x3c0 or less is the last one (ds:0x8fb1),
	# the end of the game

	# code 0x405c : the last shop is not shown while the other player is still to finish
	# level 5 (so the first one to finish it never sees it)

	var last := level_number == 5 and scroll <= 0x3c0
	var other := 1 - current

	if last and player_count == 2 and present[other] and not waiting[other]:
		_shop_closed()
		return

	# Amiga shop $54e0c : its own player for the effects

	amiga_sound.shop_sound(true)
	shop.open(level_number, last, cap)


func _shop_weapons() -> void:

	# code 0x3319, 0x35f2 after the shop : the base gun when the front slot was sold, the
	# weapons saved as at a checkpoint

	_ensure_front()
	_save_weapons(true)


func _shop_closed() -> void:

	# Amiga shop $5502a, $55036 : its player off, the game's back

	amiga_sound.shop_sound(false)

	# code 0x4ba8 : the map and the stars (one more move) are drawn before play goes on.
	# Code 0x408a : with Super Nashwan Power bought, 0x2b22 hands out every weapon. Code
	# 0x40a7 : after the end of level shop the next level starts.

	# code 0x408a : Super Nashwan Power hands out its weapons again first

	if nashwan != 0:
		_nashwan_start()

	if level_done:
		_next_level()
		return

	# code 0x4094 : the level tune again when music is on

	if music_on:
		_start_level_tune()

	_move_stars(scroll_applied)
	_place()


func _launcher_item(launcher: Dictionary) -> int:

	# the item index of a launcher (+0x36)

	return launcher["item"]


func _launcher_power(launcher: Dictionary) -> int:

	# the power level of a launcher (+0x34)

	return launcher["level"]


func _free_cannon_slot() -> int:

	# code 0x100e : the first empty side slot, 1 to 4 (ds:0x9138 on), 0 when none

	for slot in range(1, 5):
		if weapon_slots[slot] == null:
			return slot

	return 0


func _buy_item(item: int) -> void:

	# the purchase routines of ds:0x381a for every item but the advice

	match item:
		3:

			# code 0x2ab2

			_collect_item(0)
		4:

			# code 0x2a48

			_collect_item(2)
		5:

			# code 0x2aa4 : the autofire step, up to 4

			if autofire_rate < 4:
				autofire_rate += 1
		6:

			# code 0x4f96 : ds:0x9162 = 0xaa

			nashwan = 0xaa
		7:

			# code 0x2a66 : energy + 40, at most 39, effect 0x12

			energy = mini(energy + 0x28, ENERGY_MAX)
			sound_request = 0x12
			amiga_2 = 7
		8:

			# code 0x308c

			_collect_item(4)
		0xc:

			# code 0x2a6e

			_collect_item(6)
		0xf:

			# code 0x3246

			_collect_item(7)
		0x10:

			# code 0x2ac4 : ds:0x9160 + 3 dives (Enter, 0x3dbd)

			dive += 3
		0x16:

			# code 0x4fde

			lives += 1
		0x18:

			# code 0x2abe : ds:0x9223, half damage until the next shop (0x3c5d)

			protection = true
		0x19:

			# code 0x4fd7 : ds:0x9150 = 0xdc frames of bitmap shades (0x4356)

			shades = 0xdc
		9:
			_give_mine(0x38)
		0xa:
			_give_side()
		0xb:
			_give_electro()
		0xd:
			_give_mine(0x3c)
		0xe:
			_give_double()
		0x12:
			_give_laser()
		0x13:
			_give_drone()
		1:

			# 0x761 does nothing : the forward shot is only sold back

			pass
		0x11:
			_give_missile_launcher()
		0x14:
			_give_flamer()
		0x15:
			_give_bomb()
		0x17:
			_give_homing()


# ---------------------------------------------------------------- data

func _read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())


func _load_headers(set_name: String) -> void:

	# frame headers : f0, f1 box offset, f2, f3 box size, f4, f5 hot spot, width, height

	var lines := FileAccess.open("res://assets/sprites/%s/frames.csv" % set_name, FileAccess.READ).get_as_text().split("\n")

	for i in range(1, lines.size()):
		var values := lines[i].split(",")

		if values.size() < 9:
			continue

		var header: Array[int] = []

		for v in values:
			header.append(int(v))

		headers["%s/%03d" % [set_name, header[0]]] = header.slice(1)


func _player_level_init(next: Dictionary, first: bool) -> void:

	# code 0x1aaf and 0x16ba for one player : what goes on from the last level, or a fresh
	# start, then the level's own set up (table cs:0xf8a)

	if not next.is_empty():
		score = next["score"]
		shown_score = next["shown_score"]
		score_digits = next["score_digits"]
		lives = next["lives"]
		energy = next["energy"]
		speed_level = next["speed_level"]

	# the command line stays across the reload : a test --scroll is for the first player
	# of the first level only, the others start at the level's beginning. The checkpoint
	# too : the level starts as a restart from it (_restart_player).

	if not next.is_empty() or not first:
		scroll = START_SCROLL
		drawn_scroll = START_SCROLL
		scroll_max = START_SCROLL_MAX
		wave_check = FIRST_CHECK
		wall_check = FIRST_CHECK
		checkpoint_scroll = START_SCROLL
		checkpoint_x = START_X
		mid_shop_done = false

	scroll_min = SCROLL_MINS.get(level_number, 0)

	if not first:
		blocks = _fresh_blocks()
		map_words = pristine_words.duplicate()

	# code 0x16d8 : the base gun from the start (0x2bcc)

	if next.is_empty():
		_give_base_gun()

	# code 0x758f : the level 1 boss exists from the start, at the end of the enemies list.
	# On the other levels the dict stays out of the list and is never made.

	boss = {
		"kind": "boss",
		"y": 16,
		"energy": BOSS_ENERGY,
		"hit": "0x714d",
		"large": false,
		"group": 0,
		"head": null,
		"segments": [],
		"box": [1000, 0, 1000, 0],
		"phase": 0,
		"velocity": 0,
		"timer": 0,
		"reach": 0,
		"heading": 0,
		"turn": 0,
		"change": 0,
		"eye": 0,
		"body": BOSS_BODY.duplicate(true),
		"flash": false,
		"dead": false,
		"made": false,
	}

	if level_number == 1:
		enemies.append(boss)

	# code 0x8e01 : level 2's guardian and targets (level2.gd)

	if level_number == 2:
		level2 = Level2.new(self)
		level2.init()

	if level_number == 3:
		level3 = Level3.new(self)

	if level_number == 4:
		level4 = Level4.new(self)

	if level_number == 5:
		level5 = Level5.new(self)

	for type in test_weapons:
		_give_by_type(type)

	if test_full:
		_give_cannon()
		_give_cannon()

		for launcher in [_give_laser(), _give_laser(), _give_drone(), _give_side(), _give_double()]:
			if launcher != null:
				launcher["level"] = 2

	if test_nashwan:
		nashwan = NASHWAN_FRAMES
		_nashwan_start()

	# code 0x1781 : the weapons are saved as at a checkpoint. On the next level, code 0x4152 :
	# the weapons saved after the shop come back (0x193c), and Super Nashwan Power again
	# while frames of it are left (0x415c, 0x2b22).

	if next.is_empty():
		_save_weapons()
	else:
		saved_weapons = next["weapons"]
		_restore_weapons()
		nashwan = next["nashwan"]

		# ds:0x9160 and ds:0x9150 are set only at the start of the game (0x1781)

		dive = next.get("dive", 0)
		shield = next.get("shield", 0)
		shades = next.get("shades", 0)

		if nashwan != 0:
			_nashwan_start()

	if not next.is_empty():
		title.credits = next["continues"]
	elif not first:

		# code 0x16ba : 3 continues for the second player too

		title.credits = 3


func _copy(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)

	return value


func _take_player() -> Dictionary:
	var state := {}

	for name in PLAYER_VARS:
		state[name] = get(name)

	state["continues"] = title.credits
	return state


func _put_player(state: Dictionary) -> void:
	for name in PLAYER_VARS:
		set(name, state[name])

	title.credits = state["continues"]


func _reset_player() -> void:
	for name in PLAYER_VARS:
		set(name, _copy(player_defaults[name]))


func _make_second_player(next_other: Dictionary) -> void:

	# code 0x189b and 0x1b7f : the second player set up between two swaps

	var live := _take_player()
	_reset_player()
	_player_level_init(next_other, false)
	stored = _take_player()
	_put_player(live)


func start_players(count: int) -> void:

	# code 0x5c09 : the menu's choice. Code 0x1827 : both players in the game with two,
	# player 2 set up like player 1 (with 0 lives shown for one player, 0x18ad)

	player_count = count
	current = 0
	present = [true, count == 2]
	waiting = [false, false]

	if count == 2:
		_make_second_player({})


func _swap_players() -> void:

	# code 0x1a19 : the live player and the stored one exchanged, then the level's hook
	# (0xf5a : level 2 0x7aa8 exchanges the breakable cells, here in the swapped blocks,
	# level 5 0xd0da the first entries of the event lists, here the swapped checks)

	var live := _take_player()
	_put_player(stored)
	stored = live
	current = 1 - current


func _cleanup_objects() -> void:

	# code 0x18f5 : objects with +0x4a set stay (the boss and its tentacle, not moved
	# since their +0x4b is set too), the others go

	enemies = enemies.filter(func(e): return e.get("kind", "") in ["boss", "segment"] or e.get("stays", false))
	effects.clear()


func _switch_turn() -> void:

	# code 0x1a62 : with the current player still in the game the other one plays if he
	# is in it and not waiting at the end of the level. With the current one out the other
	# one plays, and if he was waiting the level ends (ds:0x8f61, on level 5 with its shop,
	# ds:0x8fb0). Then the restart at the checkpoint (0x195b).

	if player_count == 2:
		var other := 1 - current

		if present[current]:
			if present[other] and not waiting[other]:
				_cleanup_objects()
				_swap_players()
		else:
			_cleanup_objects()
			_swap_players()

			if waiting[current]:
				level_done = true

				if level_number == 5:
					shop_due = true
				else:
					level_end_now = true

	_restart_player()


func _player_out() -> void:

	# code 0x3f88 : GAME OVER, the player leaves the game. The other one goes on alone
	# (0x3f9a, 0x1a62), with none left the title (0x3c9d).

	present[current] = false

	if player_count == 2 and present[1 - current]:
		_switch_turn()
		return

	_game_finished()


func _fresh_blocks() -> Array:

	# code 0x8f1a : every block there (0x8df0)

	var fresh: Array = []

	for list in BLOCK_LISTS:
		var states: Array = []
		states.resize(list.size())
		states.fill(1)
		fresh.append(states)

	return fresh


func _load_level() -> void:
	var level: Dictionary = _read_json("res://data/%s.json" % LEVEL)
	scroll_min = SCROLL_MINS.get(level_number, 0)
	end_shop_cap = SHOP_CAPS.get(level_number, SHOP_CAPS[1])[0]
	mid_shop_cap = SHOP_CAPS.get(level_number, SHOP_CAPS[1])[1]

	blocks = _fresh_blocks()
	var tables: Dictionary = _read_json("res://data/enemies.json")

	sine = tables["sine"]

	for path in level["paths"]:
		paths.append(PathBuilder.build(path["commands"], sine))

	events = level["events"]
	walls = level["background_events"]

	var tiles: Array = level["map"]["tiles"]
	var flags: Array = level["map"]["flags"]

	for i in tiles.size():
		map_words.append((int(tiles[i]) << 6) | (int(flags[i]) & 1))

	drawn_words = map_words.duplicate()
	pristine_words = map_words.duplicate()

	var types: Dictionary = tables[LEVEL]

	for key in types:
		var parts: Array = []

		for part in types[key]["parts"]:
			var raw: Array = part["raw"]
			var size_word: int = String(raw[7]).hex_to_int()
			parts.append({
				"id": String(raw[0]).hex_to_int(),
				"score": String(raw[1]).hex_to_int(),
				"hit": raw[4],
				"large": size_word & 0xff != 0,
				"linked": size_word >> 8 != 0,
				"silent": size_word & 0x8000 != 0,
				"frames": _expand(part["frames"]),
				"start_delay": int(part["start_delay"]),
				"update": "0x37ca" if part.get("update", "") == "0x37ca" else "",
			})

		enemy_types[int(key)] = parts

	# code 0xabdf, 0xabf5 : level 3's types 3 and 4, which the extractor cannot read

	if level_number == 3:
		enemy_types.merge(Level3.wave_types(), true)


func _texture(key: String) -> Texture2D:
	if not textures.has(key):
		textures[key] = _gfx("res://assets/sprites/%s.png" % key)

	return textures[key]


func _gfx(path: String) -> Texture2D:

	# ENHANCED : the same picture from assets_hd, drawn large but sized as the original

	var texture: Texture2D = load(path)
	var large := HD_TEXTURE.hd_path(path.replace("res://assets/", "res://assets_hd/"))

	if ResourceLoader.exists(large):
		return HD_TEXTURE.new(texture, load(large))

	return texture


func _set_enhanced(on: bool) -> void:

	# ORIGINAL draws the 320x200 picture and enlarges it, ENHANCED draws every picture at
	# the window's resolution

	# the tune moves to the player of the version, from its start (the two arrangements do
	# not line up : the full one opens with its 15 s introduction)

	var before := _tune_player() if amiga_sound != null else null
	HD_TEXTURE.on = on

	if before != null and use_amiga and before != _tune_player() and before.music_playing():
		_amiga_tune(tune_volume)

	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if on else Window.CONTENT_SCALE_MODE_VIEWPORT
	_set_aspect()

	for canvas in [map, world, star_layer, overlay, hud, hud_values]:
		if canvas != null:
			canvas.queue_redraw()


func _screen_height() -> int:

	# the height of the 320 wide picture on screen, in its pixels : 240 in 4:3

	return 240 if four_three and HD_TEXTURE.on else 200


func _set_aspect() -> void:

	# remake (ENHANCED, F4) : 4:3 draws the 320x200 picture in a 320x240 area, every canvas
	# 1.2 times taller (the global canvas transform applies to all of them), and the window
	# takes the new height

	var root := get_tree().root
	var high := _screen_height()

	if root.content_scale_size.y == high:
		return

	root.content_scale_size = Vector2i(320, high)
	root.global_canvas_transform = Transform2D.IDENTITY.scaled(Vector2(1, high / 200.0))

	if shot_path != "":
		DisplayServer.window_set_size(Vector2i(1280, 4 * high))
	elif root.mode == Window.MODE_WINDOWED:
		_size_window()


func _hd_image(path: String) -> Image:

	# a picture of assets_hd, named _NB2 or _xBRZ by how it was enlarged

	path = HD_TEXTURE.hd_path(path)

	if not ResourceLoader.exists(path):
		return null

	var image: Image = load(path).get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _hd_pair(base: Image, large: Image) -> Texture2D:

	# a picture made while the game runs (masked tile, flash) with its xBRZ version

	var texture := ImageTexture.create_from_image(base)

	if large == null:
		return texture

	return HD_TEXTURE.new(texture, ImageTexture.create_from_image(large))


func _hd_tile(sheet: Image, tile: int) -> Image:

	# the tile's square in an xBRZ tile sheet (factor from the sheet's width)

	if sheet == null:
		return null

	var k := sheet.get_width() / tile_image.get_width()
	return sheet.get_region(Rect2i(_tile_origin(tile) * k, Vector2i(16, 16) * k))


func _painted(image: Image, colour: Color) -> Image:

	# the flash : every pixel in the colour, keeping its transparency (the xBRZ edge)

	if image == null:
		return null

	var out := image.duplicate()
	out.convert(Image.FORMAT_RGBA8)

	for y in out.get_height():
		for x in out.get_width():
			var a: float = out.get_pixel(x, y).a

			if a > 0.0:
				out.set_pixel(x, y, Color(colour.r, colour.g, colour.b, a))

	return out


func _image(texture: Texture2D) -> Image:

	# the original pixels, also of an ENHANCED picture (collisions, masks, flashes)

	if texture is HD_TEXTURE:
		return texture.base.get_image()

	return texture.get_image()


func _flash_texture(key: String) -> Texture2D:

	# code 0xff41 : a hit flash draws only the mask plane of the sprite, solid in colour 7

	if not flash_textures.has(key):
		var image := _image(_texture(key))
		image.convert(Image.FORMAT_RGBA8)

		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0.5:
					image.set_pixel(x, y, COLOUR_7)

		var texture := _texture(key)
		var large: Image = null

		if texture is HD_TEXTURE:
			large = _painted(texture.hd.diffuse_texture.get_image(), COLOUR_7)

		flash_textures[key] = _hd_pair(image, large)

	return flash_textures[key]


func _make_bullet_texture(rows: Array) -> Texture2D:
	var width: int = rows[0].length()
	var image := Image.create(width, rows.size(), false, Image.FORMAT_RGBA8)

	for y in rows.size():
		for x in width:
			if rows[y][x] == "#":
				image.set_pixel(x, y, COLOUR_7)

	# ENHANCED : the shape smoothed with Scale2x twice (one colour, so xBRZ would add nothing)

	return _hd_pair(image, _scale2x(_scale2x(image)))


func _scale2x(image: Image) -> Image:

	# EPX / Scale2x : each pixel becomes 2x2, a corner taking the neighbours' colour where two
	# of them meet and the other two differ

	var w := image.get_width()
	var h := image.get_height()
	var out := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)

	for y in h:
		for x in w:
			var e := image.get_pixel(x, y)
			var b := image.get_pixel(x, maxi(y - 1, 0))
			var d := image.get_pixel(maxi(x - 1, 0), y)
			var f := image.get_pixel(mini(x + 1, w - 1), y)
			var hh := image.get_pixel(x, mini(y + 1, h - 1))
			var e0 := e
			var e1 := e
			var e2 := e
			var e3 := e

			if b != hh and d != f:
				e0 = d if d == b else e
				e1 = f if b == f else e
				e2 = d if d == hh else e
				e3 = f if hh == f else e

			out.set_pixel(x * 2, y * 2, e0)
			out.set_pixel(x * 2 + 1, y * 2, e1)
			out.set_pixel(x * 2, y * 2 + 1, e2)
			out.set_pixel(x * 2 + 1, y * 2 + 1, e3)

	return out


func _step_animation(item: Dictionary, entries: Array, loop_to: int) -> void:

	# code 0x41b1 : the count goes down each update, at 0 the next (frame, count) entry is
	# loaded, after the last one the list starts again at loop_to. A count that goes below
	# 0 is set back to 0, so a frame with count 0 stays.

	item["count"] -= 1

	if item["count"] < 0:
		item["count"] = 0
		return

	if item["count"] == 0:
		item["anim"] += 1

		if item["anim"] >= entries.size():
			item["anim"] = loop_to

		item["count"] = entries[item["anim"]][1]


func _frame(frame: Dictionary) -> String:
	return "%s/%03d" % [frame["set"], int(frame["frame"])]


func _expand(frames: Array) -> Array:

	# code 0x41b1 : each animation entry is shown for its count of ticks, then the list
	# restarts. A first entry with a count of 0 never advances, so the sprite is static.

	var out: Array = []

	if frames.is_empty():
		return out

	if int(frames[0]["ticks"]) == 0:
		return [_frame(frames[0])]

	for frame in frames:
		for i in int(frame["ticks"]):
			out.append(_frame(frame))

	return out


func _box(set_name: String, frame: int, x: int, y: int) -> Array:
	return _box_of("%s/%03d" % [set_name, frame], x, y)


func _box_of(key: String, x: int, y: int) -> Array:

	# code 0x3589 : x1 = x + f0 - f4, x2 = x1 + f2 - 1, the same for y with f1, f3, f5

	var h: Array = headers[key]
	var x1: int = x + h[0] - h[4]
	var y1: int = y + h[1] - h[5]
	return [x1, y1, x1 + h[2] - 1, y1 + h[3] - 1]


func _overlap(a: Array, b: Array) -> bool:

	# code 0xf2f : signed and inclusive

	return b[2] >= a[0] and b[0] <= a[2] and b[3] >= a[1] and b[1] <= a[3]


func _random() -> int:

	# code 0x4191 : 16 bit linear congruential generator

	seed = (seed * 0x6255 + 0x3619) & 0xffff
	return seed


func _direction(ax: int, bx: int) -> int:

	# code 0x1b90 : one of 8 directions (0 up, clockwise) towards (ax, bx), with
	# 0x3504 / 0x8000 = tan 22.5 degrees as the border

	if bx < 0:
		return (4 - _direction_x(ax, -bx)) & 7

	return _direction_x(ax, bx)


func _direction_x(ax: int, bx: int) -> int:
	if ax < 0:
		return (8 - _octant(-ax, bx)) & 7

	return _octant(ax, bx)


func _octant(a: int, b: int) -> int:
	if a == 0:
		return 4

	if b == 0:
		return 2

	if a == b:
		return 3

	if a < b:
		return 3 if (((a >> 1) << 16) / b) >= 0x3504 else 4

	return 3 if (((b >> 1) << 16) / a) >= 0x3504 else 2


# ---------------------------------------------------------------- ship

func _fill_history() -> void:
	history.clear()

	for i in 17:
		history.append([scroll, ship_x, ship_y])


func _fill_trail() -> void:

	# code 0x19cd : the trail (ds:0x8ebc) and the last position (ds:0x8f34) at the ship.
	# unconfirmed : ds:0x8f34 is not set there, taken as the ship's place

	trail = [Vector2i(ship_x, ship_y), Vector2i(ship_x, ship_y), Vector2i(ship_x, ship_y)]
	ship_prev = Vector2i(ship_x, ship_y)


func _update_ship() -> void:

	# code 0x4311

	if dying:

		# code 0x431d : the scroll stops, the explosion plays, then the ship disappears and
		# the life is lost once ds:0x991e has reached 16

		scroll_asked = 0

		# code 0x41b1 : a count that has reached 0 stays there (static frame)

		if death_count > 0:
			death_count -= 1

			if death_count == 0:
				death_index += 1

				if death_index < SHIP_DEATH_FRAMES.size():
					death_count = 1
				else:
					ship_visible = false

		if death_count == 0 and not ship_visible and attach >= 16:
			life_lost = true

		return

	if not blocked and shades != 0:

		# code 0x4356 : with the bitmap shades the box is 0x40 around the ship's position
		# both ways. The first enemy in it (0x1bea) takes 0x7f (0x3a33, no type test), the
		# ship takes nothing. None : the level's extra target (0xf96). Then the ship's own
		# box again (0x3589).

		var shades_box := [ship_x - 0x40, ship_y - 0x40, ship_x + 0x40, ship_y + 0x40]
		var touched := false

		for enemy in enemies:
			if _overlap(shades_box, enemy["box"]):
				_hit_enemy(enemy, RAM_DAMAGE)
				touched = true
				break

		if not touched:
			_block_hit(shades_box)

		ship_box = _box("X2SPR", ship_frame, ship_x, ship_y)
	elif not blocked:

		# code 0x1bea : the first enemy whose box (from the last frame) overlaps the ship's
		# box. Removed enemies keep their box until their next update and still count.

		ship_box = _box("X2SPR", ship_frame, ship_x, ship_y)
		var touched := false

		for enemy in enemies:
			if _overlap(ship_box, enemy["box"]):
				touched = true
				ship_flash = true
				_damage_ship(CONTACT_DAMAGE_LARGE if enemy["large"] else CONTACT_DAMAGE_SMALL)

				if dying:
					return

				# code 0x43a9 : no hit on an object of type 0x50 (level 2's guardian, level 3's
				# worm)

				if not enemy.get("type50", false):
					_hit_enemy(enemy, RAM_DAMAGE)

				break

		# code 0x1c13 : no enemy, the level's extra target (0xf96)

		if not touched:
			_block_hit(ship_box)

	if push_back != 0:
		if push_back < 0:
			if _touches_ground():
				if push_back == -0x11:
					_kill_ship()
					return

				_rewind()
			else:
				push_back = 0
				_move_ship()
		else:
			_rewind()
	else:
		_move_ship()

	# code 0x4483 : the trail moves on and takes the position from before the move

	trail.pop_front()
	trail.append(ship_prev)

	# code 0x449b : the frame by the tilt, or while diving by the depth (ds:0x3258, X2SPR
	# 90 to 93), drawn by 0x853. The depth moves by its step. Back at 0 the step stops and
	# a push back of -15 starts (0x8e7e = 0xfff1), so a ship that comes up on the ground
	# is pushed back and crushed at -17. At 4 the step stops, and from the next frame on
	# the ship is drawn by 0x897 (under the map tiles).

	under_map = false

	if not blocked:
		ship_frame = SHIP_FRAMES[tilt + 6]
		return

	ship_frame = DIVE_FRAMES[depth]
	depth += depth_step

	if depth == 0:
		depth_step = 0
		push_back = -15
	elif depth == 4:
		if depth_step == 0:
			under_map = true

		depth_step = 0


func _update_flames() -> void:

	# code 0x4759 : animation step, follow the ship, hidden unless its key is held and the
	# ship is not blocked

	for flame in flames:
		flame["count"] -= 1

		if flame["count"] == 0:
			flame["frame"] = 1 - flame["frame"]
			flame["count"] = 1

		var offsets: Array = FLAME_X_ODD if flame["index"] & 1 else FLAME_X_EVEN
		flame["x"] = ship_x + offsets[absi(tilt)]
		flame["y"] = ship_y
		flame["visible"] = false

		if blocked:
			continue

		if flame["index"] >= 2:
			flame["visible"] = held_down
		else:
			flame["visible"] = held_up


func _rewind() -> void:

	# code 0x43d7 : the ship takes the position of the previous history entry, shifted by
	# the scroll since then, and the history moves down by one

	push_back -= 1
	scroll_asked = scroll_base

	var entry: Array = history[1]
	ship_x = entry[1]
	ship_y = entry[2] + entry[0] - scroll

	if ship_y > SHIP_Y_MAX:
		scroll_asked -= ship_y - SHIP_Y_MAX
		ship_y = SHIP_Y_MAX

	if ship_y < SHIP_Y_MIN:
		scroll_asked -= ship_y - SHIP_Y_MIN
		ship_y = SHIP_Y_MIN

	history.pop_front()
	history.append(history[-1].duplicate())

	if push_back == 0:
		push_back = -1


func _move_ship() -> void:

	# code 0x44f3 : the position kept (ds:0x8f34), then tilt, vertical and horizontal
	# movement

	ship_prev = Vector2i(ship_x, ship_y)

	if held_left:
		if tilt > 0:
			tilt = 0

		if tilt > -6:
			tilt -= 1
	elif held_right:
		if tilt < 0:
			tilt = 0

		if tilt < 6:
			tilt += 1
	elif tilt > 0:
		tilt -= 1
	elif tilt < 0:
		tilt += 1

	scroll_asked = scroll_base

	# code 0x4550 : at the top edge, up skips the down test

	var test_down := true

	if held_up:
		if ship_y > SHIP_Y_MIN:
			ship_y -= 3 + speed_level
		else:
			ship_y = SHIP_Y_MIN
			scroll_asked = 1
			test_down = false

	if held_down and test_down:
		if ship_y < SHIP_Y_MAX:
			ship_y += 3 + speed_level
		elif scroll != scroll_max:
			scroll_asked = -1
			ship_y = SHIP_Y_MAX

	var dx := tilt

	if tilt > 0 and held_right:
		dx = 6
	elif tilt < 0 and held_left:
		dx = -6

	# code 0x45c3 : speed level 0 halves the step, 2 and more add half of it

	if speed_level == 0:
		dx >>= 1
	elif speed_level >= 2:
		dx += dx >> 1

	ship_x = clampi(ship_x + dx, 0x10, 0x12e)

	# code 0x4433 : history of {scroll, x, y}, newest first, 17 entries

	history.pop_back()
	history.push_front([scroll, ship_x, ship_y])

	# code 0x4462 : touching the ground starts a one step push back, levels the ship and
	# lets the scroll go back 16 rows from here

	if not blocked and push_back >= 0 and _touches_ground():
		push_back = 1
		tilt = 0
		scroll_max = maxi(scroll_max, scroll + BACK_SCROLL)


func _touches_ground() -> bool:

	# code 0x1e29 : pixel exact, against the tiles' solid pixels (any colour but 0)

	# with the live map words (ds:0x5538 masks by word >> 1)

	for row in GROUND_MASK.size():
		var map_y: int = ship_y - 14 + row + scroll

		if map_y < 0 or map_y >= map_words.size() / 20 * 16:
			continue

		var line: String = GROUND_MASK[row]

		for column in line.length():
			if line[column] != "#":
				continue

			var map_x: int = ship_x - 14 + column

			if map_x < 0 or map_x >= 320:
				continue

			if _solid(map_words[(map_y >> 4) * 20 + (map_x >> 4)] >> 6, map_x & 15, map_y & 15):
				return true

	return false


func _tile_origin(tile: int) -> Vector2i:

	# the tile sheet holds 20 tiles a row with a 17 pixel pitch and a 1 pixel border

	return Vector2i(1 + (tile % 20) * 17, 1 + (tile / 20) * 17)


func _solid(tile: int, x: int, y: int) -> bool:
	var c := tile_image.get_pixelv(_tile_origin(tile) + Vector2i(x, y))
	return c.r8 != 0 or c.g8 != 0 or c.b8 != 0


func _damage_ship(amount: int) -> void:

	# code 0x3c4f : energy down, death when it is not above 0. Nothing while the end of
	# level bonuses are out (ds:0x9164).

	if bonuses_out != 0 or invulnerable:
		return

	# the shield (ds:0x9188) : no damage and no flash

	if shield != 0:
		ship_flash = false
		return

	# code 0x3c5d : the protection halves the damage

	if protection:
		amount >>= 1

	energy -= amount

	if energy <= 0:
		_kill_ship()


func _kill_ship() -> void:

	# code 0x3c01 : not while the end of level bonuses are out

	if bonuses_out != 0:
		return

	# code 0x3c18 : effect 6, first

	sound_request = 6
	sound_priority = 6

	# game $5d12 : $a on both

	amiga_2 = 0xa
	amiga_1 = 0xa
	dying = true
	depth = 1
	energy = 0
	death_index = 0
	death_count = 1
	ship_visible = true


func _input(event: InputEvent) -> void:

	# the keyboard interrupt keeps the last key that went down (ds:0x8f58)

	if event is InputEventKey and event.pressed and not event.echo:

		# remake, not keys of the game (F10 stays the original's exit) : F1 ORIGINAL or
		# ENHANCED, F2 PC or Amiga graphics, F3 PC speaker or Amiga sound, F4 (ENHANCED) square
		# pixels or 4:3, F5 (ENHANCED) smooth motion, at any moment

		if event.physical_keycode == KEY_F1:
			_set_enhanced(not HD_TEXTURE.on)
			return

		if event.physical_keycode == KEY_F4:
			if HD_TEXTURE.on:
				four_three = not four_three
				_set_aspect()

			return

		if event.physical_keycode == KEY_F5:
			if HD_TEXTURE.on:
				smooth = not smooth

			return

		if event.physical_keycode == KEY_F2:
			_switch_graphics(not use_amiga_gfx)

			for canvas in [map, world, star_layer, overlay, hud, hud_values]:
				if canvas != null:
					canvas.queue_redraw()

			return

		if event.physical_keycode == KEY_F3:
			var title_tune := title_tune_on
			_switch_sound(not use_amiga)

			# the tune goes on with the other sound : the title's or the level's, from its start

			if title.running:
				if title_tune:
					_title_tune()
			elif music_on and not shop.running:
				_start_level_tune()

			return

		any_key = true
		last_key = event.physical_keycode

		# code 0x5fd4 : F10 leaves the game at any time (0x54f : sound off, timer and
		# keyboard back, text mode, exit to DOS)

		if event.physical_keycode == KEY_F10:
			_quit()


func _notification(what: int) -> void:

	# remake : closing the window, as F10

	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


func _quit() -> void:

	# remake : the sound players stop first. With a generator still playing, Windows held
	# the closing program for about 10 s.

	for node in [amiga_sound, amiga_music, sound]:
		if node != null and node.player != null:
			node.player.stop()

	get_tree().quit()


func _custom_held(action: String) -> bool:
	return custom_keys.has(action) and Input.is_physical_key_pressed(custom_keys[action])


func _game_keys() -> void:

	# code 0x3d6b : the last key pressed, after the frame's updates, through the table
	# cs:0x3d8f : P (0x19) pause, Esc (1) the title, Enter (0x1c) dive (I, 0x17, the cheat, left out)
	# (in _read_input)

	if escape_event:

		# code 0x3c9d : back to the title at once, no high score and no continue

		escape_event = false
		_game_finished()
		return

	if pause_event:

		# code 0x3df8 : the game waits, the sound goes on

		pause_event = false
		paused = true
		any_key = false
		fire_event = false

	any_key = false
	_dive_key()


func _pause_tick() -> void:

	# code 0x3dfd : until fire (ds:0x8f5b) or any key (ds:0x8f58), both cleared after

	if fire_event or any_key:
		fire_event = false
		any_key = false
		pause_event = false
		enter_event = false
		paused = false


func _dive_key() -> void:

	# code 0x3d6b : the last key pressed, after the frame's updates. Code 0x3dbd : Enter
	# (scancode 0x1c), not while dying. On the surface with dives left it starts one (depth
	# 1 going down, effect 0x18, 0x88 frames), under it (or on the way) the ship comes up
	# on the next frame.

	var pressed := enter_event
	enter_event = false

	if not pressed or dying:
		return

	if depth == 0:
		if dive == 0:
			return

		depth_step = 1
		_dive_sound()
		depth = 1
		dive -= 1
		dive_time = DIVE_FRAMES_LEFT
	else:
		dive_time = 1


func _dive_sound() -> void:

	# ds:0x8e88 = 0x18. Amiga game $7996 and $63f6 : $10 on $414, at the start and at the
	# way up.

	sound_request = 0x18
	amiga_2 = 0x10


func _update_counters() -> void:

	# code 0x4675 : ds:0x991e climbs to 16 while blocked or dying, falls to 0 otherwise

	if blocked or dying:
		attach = mini(attach + 1, 16)
	else:
		attach = maxi(attach - 1, 0)

	# code 0x46e4 : Super Nashwan Power counts down with its gauge, at 0 the weapons put
	# aside come back

	# code 0x46b6 : the dive time counts down with its gauge, at 0 the ship comes up
	# (effect 0x18)

	# code 0x469b : the bitmap shades count down with their gauge at (0x126, 8)

	shades_gauge = -1

	if shades != 0:
		shades -= 1
		shades_gauge = GAUGE_FIRST + 10 * shades / (SHADES_FRAMES + 1)

	dive_gauge = -1

	if dive_time != 0:
		dive_time -= 1
		dive_gauge = GAUGE_FIRST + 10 * dive_time / (DIVE_FRAMES_LEFT + 1)

		if dive_time == 0:
			depth_step = -1
			_dive_sound()

	gauge_frame = -1

	if nashwan != 0:
		nashwan -= 1
		gauge_frame = GAUGE_FIRST + 10 * nashwan / (NASHWAN_FRAMES + 1)

		if nashwan == 0:
			_nashwan_end()

	# code 0x4709 : autofire

	if not held_fire:
		autofire = autofire_period
	else:
		autofire -= autofire_rate

		if autofire <= 0:
			autofire += autofire_period
			fire_event = true


func _lose_life() -> void:

	# code 0x3f13, 0x1a62, 0x195b : energy back to 39, one life less, every enemy and effect
	# removed, the ship back at the checkpoint with the scroll there

	life_lost = false
	autofire_rate = 1
	energy = 39
	lives -= 1

	# code 0x3f30 : no lives left, the high score, a credit, the continue screen
	# (title.gd), then either the game goes on (_continue_game) or it is over

	if lives == 0:
		title.game_over()
		return

	_switch_turn()


func _continue_game() -> void:

	# code 0x3f4b : 3 lives, the score and its digits back to 0, then as after a lost life

	lives = 3
	score = 0
	shown_score = 0
	score_digits = [0, 0, 0, 0, 0, 0, 0]

	# then as after a lost life : the turn passes (0x1a62)

	_switch_turn()


func _game_finished() -> void:

	# code 0x3f97 : back to the title (0x3c9d). The scene starts again with the generator,
	# the settings and the high scores carried over, without the start of the program
	# (0x3c75 to 0x3c94).

	carried = {
		"seed": seed,
		"music": music_on,
		"amiga_sound": use_amiga,
		"amiga_graphics": use_amiga_gfx,
	}
	get_tree().reload_current_scene()


func _next_level() -> void:

	# code 0x40a7 : after the end of level shop. 0x4116 : the screen cleared, every object
	# gone (0x18f5, 0x3760), the level number up (0x4131, after 5 back to 1). 0x4146 :
	# LOADING LEVEL n (0x5cc5), the weapons saved after the shop given back (0x193c), Super
	# Nashwan Power again while frames of it are left (0x2b22), the level set up (0x1b43,
	# which also sets the credits to 0), play goes on (0x3d26). The score, the lives, the
	# energy, the speed and the continues stay. The scene starts again with these carried.

	# code 0x40ac : after level 5 every launcher goes, the base gun, the weapons saved, one
	# continue more. Code 0x4131 : after level 5 level 1, and the loop ds:0x991a one more.

	if level_number == 5:
		for launcher in launchers.duplicate():
			_remove_launcher(launcher)

		_ensure_front()
		_save_weapons()
		title.credits += 1

	# code 0x40cb : with the other player in the game and not done, this one waits and the
	# other plays the same level (0x40e3, 0x18f5, every object freed by 0x3760, 0x1a65)

	level_done = false
	var other := 1 - current

	if player_count == 2 and present[other] and not waiting[other]:
		waiting[current] = true
		enemies.clear()
		effects.clear()
		_swap_players()
		_restart_player()
		return

	_carry_level(level_number % 5 + 1, game_loop + (1 if level_number == 5 else 0))
	get_tree().reload_current_scene()


func _carry_level(next: int, loop: int) -> void:

	# what goes on to the next level, the scene loaded again with it (_ready)

	carried = {
		"seed": seed,
		"music": music_on,
		"amiga_sound": use_amiga,
		"amiga_graphics": use_amiga_gfx,
		"next": {
			"level": next,
			"score": score,
			"shown_score": shown_score,
			"score_digits": score_digits.duplicate(),
			"lives": lives,
			"energy": energy,
			"speed_level": speed_level,
			"weapons": saved_weapons.duplicate(true),
			"continues": title.credits,
			"loop": loop,
			"nashwan": nashwan,
			"dive": dive,
			"shades": shades,
			"shield": shield,
			"players": {"count": player_count, "current": current, "present": present},
			"other": _carry_other(),
			"stars": stars.duplicate(true),
		},
	}



func _carry_other() -> Dictionary:

	# the stored player's part of what goes on to the next level

	if player_count != 2:
		return {}

	return {
		"score": stored["score"],
		"shown_score": stored["shown_score"],
		"score_digits": stored["score_digits"],
		"lives": stored["lives"],
		"energy": stored["energy"],
		"speed_level": stored["speed_level"],
		"weapons": stored["saved_weapons"],
		"continues": stored["continues"],
		"nashwan": stored["nashwan"],
		"dive": stored["dive"],
		"shades": stored["shades"],
		"shield": stored["shield"],
	}


func _restart_player() -> void:

	# code 0x1a62

	# code 0x18f5 : objects with +0x4a set stay (the boss and its tentacle, not moved
	# since their +0x4b is set too), every launcher goes and the weapons come back as saved
	# at the last checkpoint (0x193c)

	_cleanup_objects()
	dying = false

	# code 0x19b6 : only ds:0x8e80, the step and the dive time stay

	depth = 0
	ship_visible = true
	ship_x = checkpoint_x
	ship_y = SHIP_Y_MAX
	scroll = checkpoint_scroll
	scroll_max = checkpoint_scroll
	wave_check = checkpoint_scroll + 1
	wall_check = checkpoint_scroll + 1 + 0xbf
	push_back = 0
	tilt = 0
	ship_frame = SHIP_FRAMES[6]

	for slot in groups:
		slot[0] = 0
		slot[1] = 0

	_fill_history()
	attach = 8

	# code 0x195b : the weapons are rebuilt with the ship at its new place, the trail filled
	# there, and Super Nashwan Power starts again while frames of it are left. The mines
	# out (ds:0x8e86) are not reset here (only 0x1b43 does), so mines lost with the ship
	# stay counted.

	# ENHANCED : the music goes on through the death and GET READY instead of starting
	# again (code 0x18f5 stops it, 0x3f9d starts it from the beginning)

	music_kept = HD_TEXTURE.on and music_on and (not use_amiga or _tune_player().music_playing())
	_restore_weapons()

	# code 0x19a0 : the credits as at the checkpoint

	credits = checkpoint_credits
	_fill_trail()

	# code 0x19f2 : GET READY PLAYER 1 until fire (0x5926 with ds:0x374e set), the game's
	# stars set up again after it (0x5950). Then the rest in _get_ready_done.

	title.get_ready()


func _get_ready_done() -> void:

	# code 0x5950 : the game's stars again

	_init_stars()

	# code 0x1a0e : Super Nashwan Power again while frames of it are left

	if nashwan != 0:
		_nashwan_start()

	# code 0x3f9d : the level tune again when music is on

	if music_on and not music_kept:
		_start_level_tune()

	music_kept = false
	_place()


# ---------------------------------------------------------------- gun

func _save_weapons(always: bool = false) -> void:

	# code 0x35eb : (type, level) of every weapon slot, ds:0x916a. Skipped while Super
	# Nashwan Power runs, except from 0x35f2 (after the shop).

	if nashwan != 0 and not always:
		return

	saved_weapons = []

	for launcher in weapon_slots:
		if launcher == null:
			saved_weapons.append([0, 0])
		else:
			saved_weapons.append([launcher["type"], launcher["level"]])


func _restore_weapons() -> void:

	# code 0x18f5 : the sound stops (interrupt 0x80, function 1).
	# Super Nashwan Power gives the weapons back first (0x472d), every
	# launcher goes (0x37a9, a cannon's companion with it) and the drone shots are cleared.
	# Code 0x193c : the slots are built again in slot order by type (0x29d7), each through
	# its purchase routine, then given the saved level.

	if not music_kept:
		_stop_sound()

	if nashwan != 0:
		_nashwan_end()

	for launcher in launchers.duplicate():
		_remove_launcher(launcher)

	sparks.clear()

	for entry in saved_weapons:
		if entry[0] == 0:
			continue

		var launcher: Variant = _give_by_type(entry[0])

		if launcher != null:
			launcher["level"] = entry[1]


func _give_by_type(type: int) -> Variant:

	# code 0x29d7

	match type:
		0x44:
			return _give_rear()
		0x98:
			return _give_side()
		0x34:
			return _give_cannon()
		0x2c:
			return _give_drone()
		0x20:
			return _give_laser()
		0x4c:
			return _give_electro()
		0x3c:
			return _give_mine(0x3c)
		0x38:
			return _give_mine(0x38)
		0xc0:
			return _give_double()
		0x94:
			return _give_base_gun()

		0x90:
			return _give_missile_launcher()
		0x48:
			return _give_homing()
		0xb0:
			return _give_flamer()
		0x28:
			return _give_bomb()

	return null


func _launch(kind: String, type: int, item: int, level: int, top: int, slot: int, frames: Array, offset: Vector2i) -> Dictionary:

	# code 0x77c : a new launcher at the front of the list (ds:0x9008), its slot word
	# (ds:0x9134 + 4 * slot) set to its type

	var launcher := {
		"kind": kind,
		"type": type,
		"item": item,
		"level": level,
		"max": top,
		"slot": slot,
		"frames": frames,
		"anim": 0,
		"count": frames[0][1] if not frames.is_empty() else 0,
		"offset": offset,
		"x": ship_x + offset.x,
		"y": ship_y + offset.y,
		"state": 0,
		"cool": -1,
		"visible": true,
		"freed": false,
	}
	launchers.push_front(launcher)
	weapon_slots[slot] = launcher
	return launcher


func _drop_launcher(launcher: Variant) -> void:

	# code 0x7c0 : the record leaves its list and is freed. The slot word is not touched.

	if launcher == null:
		return

	launchers.erase(launcher)
	launcher["freed"] = true


func _remove_launcher(launcher: Dictionary) -> void:

	# code 0x3788, 0x37a9 : a cannon's companion first, then the launcher, and its slot
	# word is cleared

	if launcher["kind"] == "cannon":
		for item in effects:
			if item["kind"] == "companion" and item["cannon"] == launcher:
				item["dead"] = true

	_drop_launcher(launcher)

	if weapon_slots[launcher["slot"]] == launcher:
		weapon_slots[launcher["slot"]] = null


func _pack_side_slots() -> void:

	# ENHANCED : after a sale the side weapons left move to the first side slots at once,
	# in slot order, as the original does only when it rebuilds the weapons (0x193c, after
	# a lost life or on the next level). A laser no longer hangs in the air at an outer
	# slot when the cannon next to the ship was sold. A cannon's companion follows the
	# cannon's offset by itself.

	var side: Array = []

	for slot in range(1, 5):
		if weapon_slots[slot] != null:
			side.append(weapon_slots[slot])
			weapon_slots[slot] = null

	for i in side.size():
		var launcher: Dictionary = side[i]
		launcher["slot"] = i + 1
		launcher["offset"] = CANNON_OFFSETS[i]
		launcher["x"] = ship_x + CANNON_OFFSETS[i].x
		launcher["y"] = ship_y + CANNON_OFFSETS[i].y
		weapon_slots[i + 1] = launcher


func _power_slot(slot: int) -> Dictionary:

	# code 0x2c21, 0x2d19, 0x2ef8 : one level more while below the maximum

	var launcher: Dictionary = weapon_slots[slot]

	if launcher["max"] > launcher["level"]:
		launcher["level"] += 1

	return launcher


func _is_type(slot: int, type: int) -> bool:
	return weapon_slots[slot] != null and weapon_slots[slot]["type"] == type


func _clear_rear_slot() -> void:

	# code 0x2e73 : the launcher of the rear slot goes (its slot word stays until the new
	# weapon writes it)

	_drop_launcher(weapon_slots[5])


func _give_base_gun() -> Dictionary:

	# code 0x2bcc : the forward gun (type 0x94, item 1), levels 0 to 2, draws nothing

	_drop_launcher(weapon_slots[0])
	autofire_period = 8
	return _launch("gun", 0x94, 1, 0, 2, 0, [], Vector2i.ZERO)


func _ensure_front() -> void:

	# code 0x3319 : the base gun when the front slot is empty

	if weapon_slots[0] == null:
		_give_base_gun()


func _give_double() -> Dictionary:

	# code 0x2c32 : double shot (type 0xc0, item 14) in the front slot, X2WEAPS 101 on the
	# ship, or one level more if it is already there

	if _is_type(0, 0xc0):
		return _power_slot(0)

	_drop_launcher(weapon_slots[0])
	autofire_period = 8
	return _launch("double", 0xc0, 14, 0, 2, 0, DOUBLE_FRAMES, Vector2i.ZERO)


func _give_side() -> Dictionary:

	# code 0x2ca6 : side shot (type 0x98, item 10) in the outer slot. A rear shot in the
	# rear slot goes.

	if _is_type(6, 0x98):
		return _power_slot(6)

	_drop_launcher(weapon_slots[6])

	if _is_type(5, 0x44):
		_drop_launcher(weapon_slots[5])
		weapon_slots[5] = null

	autofire_period = 8
	return _launch("side", 0x98, 10, 0, 2, 6, [], Vector2i.ZERO)


func _give_rear() -> Dictionary:

	# code 0x308c : rear shot (type 0x44, item 8) in the rear slot. A side shot goes, so does
	# whatever held the rear slot.

	if _is_type(5, 0x44):
		return _power_slot(5)

	if _is_type(6, 0x98):
		_drop_launcher(weapon_slots[6])
		weapon_slots[6] = null

	_clear_rear_slot()
	return _launch("rear", 0x44, 8, 0, 2, 5, REAR_FRAMES, Vector2i.ZERO)


func _give_electro() -> Dictionary:

	# code 0x2f08 : electro ball (type 0x4c, item 11) in the rear slot, 25 rows below the
	# ship, no levels

	if _is_type(5, 0x4c):
		return _power_slot(5)

	_clear_rear_slot()
	return _launch("electro", 0x4c, 11, 0, 0, 5, ELECTRO_FRAMES, Vector2i(0, 0x19))


func _give_mine(type: int) -> Dictionary:

	# code 0x2f7c (type 0x38, item 9, level 0) and 0x3004 (type 0x3c, item 13, level 1) :
	# mines in the rear slot, 25 rows below the ship. The last drop point x is set to -100.

	if _is_type(5, 0x38) or _is_type(5, 0x3c):
		return _power_slot(5)

	_clear_rear_slot()
	mine_mark.x = -100

	if type == 0x38:
		return _launch("mine", 0x38, 9, 0, 1, 5, MINE_FRAMES_SMALL, Vector2i(0, 0x19))

	return _launch("mine", 0x3c, 13, 1, 1, 5, MINE_FRAMES_LARGE, Vector2i(0, 0x19))


func _give_drone() -> Dictionary:

	# code 0x2e84 : drone (type 0x2c, item 19) in the rear slot, 25 rows below the ship

	if _is_type(5, 0x2c):
		return _power_slot(5)

	_clear_rear_slot()
	var launcher := _launch("drone", 0x2c, 19, 0, 2, 5, DRONE_FRAMES, Vector2i(0, 0x19))
	launcher["cool"] = 0
	return launcher


func _give_cannon() -> Variant:

	# code 0x3246 : a side cannon (type 0x34, item 15) in the first free side slot
	# (0x100e), at the offset of that slot, with its companion at the end of the effects
	# list. No free slot : only the front gun check.

	var slot := _free_cannon_slot()

	if slot == 0:
		_ensure_front()
		return null

	var cannon := _launch("cannon", 0x34, 15, 0, 0, slot, [], CANNON_OFFSETS[slot - 1])
	cannon["anim"] = CANNON_REST
	cannon["count"] = 0
	var companion := {
		"kind": "companion",
		"cannon": cannon,
		"anim": 0,
		"count": 1,
		"x": cannon["x"],
		"y": cannon["y"],
		"visible": true,
		"dead": false,
	}
	effects.append(companion)
	appended.append(companion)
	_ensure_front()
	return cannon


func _give_laser() -> Variant:

	# code 0x31b6 : a laser (type 0x20, item 18) in the first free side slot, levels 0 to 2

	var slot := _free_cannon_slot()

	if slot == 0:
		_ensure_front()
		return null

	var laser := _launch("laser", 0x20, 18, 0, 2, slot, LASER_FRAMES, CANNON_OFFSETS[slot - 1])
	_ensure_front()
	return laser



# ---------------------------------------------------------------- weapons of the later shops

func _give_missile_launcher() -> Variant:

	# code 0x3126 : a missile launcher (type 0x90, item 17) in the first free side slot,
	# no levels

	var slot := _free_cannon_slot()

	if slot == 0:
		_ensure_front()
		return null

	var launcher := _launch("missile_launcher", 0x90, 17, 0, 0, slot, MISSILE_LAUNCHER_FRAMES, CANNON_OFFSETS[slot - 1])
	launcher["count"] = 0
	_ensure_front()
	return launcher


func _give_bomb() -> Dictionary:

	# code 0x2d2a : bombs (type 0x28, item 21) in the outer slot, autofire period 0xc

	if _is_type(6, 0x28):
		return _power_slot(6)

	_drop_launcher(weapon_slots[6])
	autofire_period = 0xc
	return _launch("bomb_launcher", 0x28, 21, 0, 0, 6, [], Vector2i.ZERO)


func _give_homing() -> Dictionary:

	# code 0x2d86 : homing missiles (type 0x48, item 23) in the rear slot when it is empty,
	# else the outer slot (its weapon goes), autofire period 0x1e

	if _is_type(5, 0x48):
		return _power_slot(5)

	if _is_type(6, 0x48):
		return _power_slot(6)

	var slot := 5 if weapon_slots[5] == null else 6

	if slot == 6:
		_drop_launcher(weapon_slots[6])

	autofire_period = 0x1e
	return _launch("homing_launcher", 0x48, 23, 0, 0, slot, [], Vector2i.ZERO)


func _give_flamer() -> Dictionary:

	# code 0x2df0 : the flamer (type 0xb0, item 20) in the front slot, levels 0 to 2

	if _is_type(0, 0xb0):
		return _power_slot(0)

	_drop_launcher(weapon_slots[0])
	autofire_period = 8
	return _launch("flamer", 0xb0, 20, 0, 2, 0, FLAMER_FRAMES, Vector2i.ZERO)


func _update_missile_launcher(launcher: Dictionary, latched: bool) -> void:

	# code 0x250b : at its side slot offset. On frame 80 two missiles leave, 3 to the left
	# and 5 to the right, 16 rows up, 9 a frame up (the bullet routine 0x39ee). A fire
	# event at rest (frame 79) starts the frames.

	_step_animation(launcher, MISSILE_LAUNCHER_FRAMES, 0)
	var offset: Vector2i = launcher["offset"]
	launcher["x"] = ship_x + offset.x
	launcher["y"] = ship_y + offset.y
	launcher["visible"] = true
	var key: String = MISSILE_LAUNCHER_FRAMES[launcher["anim"]][0]

	if attach != 0:
		_place_attachment(launcher, key)
		return

	if key == "X2WEAPS/080":
		for dx in [-3, 5]:
			effects.push_front({
				"kind": "missile",
				"x": launcher["x"] + dx,
				"y": launcher["y"] - 0x10,
				"vx": 0,
				"vy": -9,
				"level": launcher["level"],
				"frames": HOMING_FRAMES[0],
				"anim": 0,
				"count": HOMING_FRAMES[0][0][1],
				"dead": false,
			})
	elif latched and key == "X2WEAPS/079":
		launcher["count"] = 1


func _update_missile(missile: Dictionary) -> void:

	# code 0x39ee with the frames of cs:0x1380

	_step_animation(missile, missile["frames"], 0)
	_update_gun_bullet(missile)


func _effect_alive(kind: String) -> bool:
	for item in effects:
		if item["kind"] == kind and not item["dead"]:
			return true

	return false


func _update_bomb_launcher(launcher: Dictionary, latched: bool) -> void:

	# code 0x3872 : a bomb on a fire event at most every 16 frames, only one at a time. It
	# starts 12 rows above the ship and rises 6 a frame for y / 16 + 4 frames.

	if blocked:
		return

	if launcher["cool"] >= 0:
		launcher["cool"] -= 1

	if not latched or launcher["cool"] >= 0 or _effect_alive("bomb"):
		return

	launcher["cool"] = 0xf
	var y := ship_y - 0xc
	effects.push_front({
		"kind": "bomb",
		"x": ship_x,
		"y": y,
		"state": -((y >> 4) + 4),
		"frames": BOMB_FRAMES,
		"anim": 0,
		"count": BOMB_FRAMES[0][1],
		"dead": false,
	})


func _update_bomb(bomb: Dictionary) -> void:

	# code 0x262d : rises, waits 3 frames, then 4 large explosions in 40 by 40 and every
	# enemy in 64 by 64 takes 8 (cs:0x3db0)

	if dying:
		bomb["dead"] = true
		return

	_step_animation(bomb, BOMB_FRAMES, 0)

	if bomb["state"] < 0:
		bomb["state"] += 1
		bomb["y"] -= 6
		return

	if bomb["state"] == 0:
		bomb["state"] = 3
		return

	bomb["state"] -= 1

	if bomb["state"] != 0:
		return

	sound_request = 0

	# Amiga game `$42d2 : `$82, then `$83 on both from the explosions

	amiga_2 = 0x82
	var x: int = bomb["x"]
	var y: int = bomb["y"]
	_explosions(x - 0x14, y - 0x14, 0x28, 0x28, LARGE_EXPLOSION)
	bomb["dead"] = true
	_area_damage([x - 0x20, y - 0x20, x + 0x1f, y + 0x1f], 8)


func _update_homing_launcher(launcher: Dictionary, latched: bool) -> void:

	# code 0x3900 : four missiles on a fire event at most every 19 frames, only while none
	# is out, leaving in directions 7, 5, 3 and 1, each the newest in front

	if blocked:
		return

	if launcher["cool"] >= 0:
		launcher["cool"] -= 1

	if not latched or launcher["cool"] >= 0 or _effect_alive("homing"):
		return

	launcher["cool"] = 0x12
	sound_request = 0

	# Amiga game `$5714 : 9

	amiga_2 = 9

	for direction in [7, 5, 3, 1]:
		var frames := _homing_launch(direction)
		effects.push_front({
			"kind": "homing",
			"x": ship_x,
			"y": ship_y,
			"direction": direction,
			"state": 0xd,
			"target": null,
			"frames": frames,
			"anim": 0,
			"count": frames[0][1],
			"loop": 1,
			"dead": false,
		})


func _homing_launch(direction: int) -> Array:

	# ds:0x324a : the launch frame (X2WEAPS 25 + 3 * direction) for 10 ticks, then the
	# frames of the direction

	var frames: Array = [["X2WEAPS/%03d" % (25 + 3 * direction), 10]]
	frames.append_array(HOMING_FRAMES[direction])
	return frames


func _homing_visible(enemy: Dictionary) -> bool:
	var b: Array = enemy["box"]
	return b[2] >= 0 and b[0] < 0x140 and b[3] >= 0 and b[1] < 0xc0


func _homing_target() -> Variant:

	# code 0x108f : the n-th enemy on the screen, n random below the enemy count
	# (ds:0x8f32), counted over up to 5 passes of the list, the parts of an enemy skipped.
	# unconfirmed : the count is the remake's enemy list size.

	var n: int = _random() % maxi(enemies.size(), 1)

	for pass_number in 5:
		for enemy in enemies:
			if enemy.get("head", null) != null or enemy["dead"]:
				continue

			if not _homing_visible(enemy):
				continue

			n -= 1

			if n < 0:
				return enemy

	return null


func _update_homing(missile: Dictionary) -> void:

	# code 0x1ff3 : 13 frames out on its course (it moves from the 5th on), then it steers
	# toward its target, one eighth of a turn every 3 frames. With no target it explodes.
	# It moves by ds:0x30dc and ds:0x30cc for its direction, gone off the play area, and
	# hits the first enemy box holding its point for 1 (cs:0x3da0).

	if dying:
		missile["dead"] = true
		return

	_step_animation(missile, missile["frames"], missile["loop"])
	var moving := true

	if missile["state"] > 0:
		missile["state"] -= 1
		moving = missile["state"] >= 8
	else:
		var target: Variant = missile["target"]

		if target == null or target["dead"] or int(target.get("id", 0)) < 0xc8 or not _homing_visible(target):
			target = _homing_target()

			if target == null:
				_explode_at(missile["x"], missile["y"], SMALL_EXPLOSION)
				missile["dead"] = true
				return

			missile["target"] = target

		if missile["state"] != 0:
			missile["state"] += 1

		if missile["state"] == 0:
			var b: Array = target["box"]
			var want := _octant_direction(b[0] + 2 - missile["x"], b[1] + 2 - missile["y"])
			var turn: int = want - missile["direction"]

			if turn != 0:
				if turn < 0:
					turn += 8

				missile["direction"] = (missile["direction"] + (-1 if turn >= 4 else 1)) & 7
				missile["state"] = -3
				missile["frames"] = HOMING_FRAMES[missile["direction"]]
				missile["loop"] = 0
				missile["anim"] = 0
				missile["count"] = missile["frames"][0][1]

	if moving:
		var d: int = missile["direction"]
		var x: int = missile["x"] + HOMING_DX[d]

		if x < 0 or x >= 0x140:
			missile["dead"] = true
			return

		missile["x"] = x
		var y: int = missile["y"] + HOMING_DY[d]

		if y < 0 or y >= 0xc0:
			missile["dead"] = true
			return

		missile["y"] = y

	for enemy in enemies:
		var b: Array = enemy["box"]

		if missile["x"] >= b[0] and missile["x"] <= b[2] and missile["y"] >= b[1] and missile["y"] <= b[3]:
			missile["dead"] = true
			_hit_enemy(enemy, 1, {"box": [missile["x"], missile["y"], missile["x"], missile["y"]]})
			return

	if _block_hit([missile["x"], missile["y"], missile["x"], missile["y"]]):
		missile["dead"] = true


func _octant_direction(ax: int, bx: int) -> int:

	# code 0x1b90 : 0 up, clockwise, from the signs and the octant (0x1bb4)

	if bx < 0:
		var v := _octant_direction(ax, -bx)
		return (-(v - 4)) & 7

	if ax < 0:
		var v := _octant_direction(-ax, bx)
		return (-(v - 8)) & 7

	return _octant(ax, bx)


func _explode_at(x: int, y: int, frames: Array) -> void:

	# code 0x3326 : an explosion at the point, effect 6 first

	sound_priority = 6
	amiga_1 = 0x85 if frames == SMALL_EXPLOSION else 0x83
	effects.push_front({"kind": "explosion", "x": x, "y": y, "frames": frames, "index": 0, "count": 1, "dead": false})


func _update_flamer(launcher: Dictionary) -> void:

	# code 0x213c : on the ship. While fire is held, effect 5 when none plays, and two
	# flames a frame, 16 rows up (the second 6 more) plus 0 to 3, drifting sideways by a
	# random signed byte / 64 a frame

	_step_animation(launcher, FLAMER_FRAMES, 0)
	launcher["x"] = ship_x
	launcher["y"] = ship_y
	launcher["visible"] = true

	if attach != 0:
		_place_attachment(launcher, FLAMER_FRAMES[launcher["anim"]][0])
		return

	if not held_fire:
		return

	if launcher["state"] == 0 or sound.call_driver(0x11, 0) == 0:
		sound_request = 5
		launcher["state"] = 1

	# Amiga game `$3bb8 : effect 1 while channel 2 has no effect

	if amiga_sound.channel_busy(2) == false:
		amiga_2 = 1

	for second in [false, true]:
		var y: int = (_random() & 3) + launcher["y"] - 0x10

		if second:
			y -= 6

		var drift := _random() & 0xff

		if drift >= 0x80:
			drift -= 0x100

		effects.push_front({
			"kind": "flame",
			"x": launcher["x"] << 16 | 0x8000,
			"y": y,
			"drift": drift << 10,
			"hits": not second,
			"level": launcher["level"],
			"frames": FLAMER_FLAME_FRAMES,
			"anim": 0,
			"count": FLAMER_FLAME_FRAMES[0][1],
			"dead": false,
		})


func _update_flame(flame: Dictionary) -> void:

	# code 0x399c : its frames end it (0x41fb), it drifts, rises 12 a frame, and the first
	# of each pair hits the first enemy its box overlaps for level + 1

	if dying:
		flame["dead"] = true
		return

	flame["count"] -= 1

	if flame["count"] == 0:
		flame["anim"] += 1

		if flame["anim"] >= FLAMER_FLAME_FRAMES.size():
			flame["dead"] = true
			return

		flame["count"] = FLAMER_FLAME_FRAMES[flame["anim"]][1]

	flame["x"] += flame["drift"]
	var x: int = flame["x"] >> 16

	if x < 0 or x >= 0x140:
		flame["dead"] = true
		return

	flame["y"] -= 0xc

	if flame["y"] < 0:
		flame["dead"] = true
		return

	if not flame["hits"]:
		return

	var box := _box_of(FLAMER_FLAME_FRAMES[flame["anim"]][0], x, flame["y"])

	for enemy in enemies:
		if _overlap(box, enemy["box"]):
			flame["dead"] = true
			_hit_enemy(enemy, flame["level"] + 1, {"box": box})
			return

	if _block_hit(box):
		flame["dead"] = true

func _power_up() -> void:

	# code 0x2a6e : one level more for the slot with the lowest level below its maximum,
	# the earliest slot on a tie

	var best: Variant = null
	var lowest := 0x7f

	for launcher in weapon_slots:
		if launcher == null or launcher["level"] == launcher["max"]:
			continue

		if launcher["level"] < lowest:
			lowest = launcher["level"]
			best = launcher

	if best != null:
		best["level"] += 1


func _nashwan_start() -> void:

	# code 0x2b22 : the launcher list and the slots are put aside (ds:0x91b4), then the base
	# gun, two cannons, two lasers, the drone, the side shot and the double shot, the last
	# five at level 2

	nashwan_saved = {"launchers": launchers, "slots": weapon_slots}
	launchers = []
	weapon_slots = [null, null, null, null, null, null, null]
	_give_base_gun()
	_give_cannon()
	_give_cannon()

	for launcher in [_give_laser(), _give_laser(), _give_drone(), _give_side(), _give_double()]:
		if launcher != null:
			launcher["level"] = 2


func _nashwan_end() -> void:

	# code 0x472d : every launcher of the list goes (0x37a9), the list and the slots put
	# aside come back

	for launcher in launchers.duplicate():
		_remove_launcher(launcher)

	if not nashwan_saved.is_empty():
		launchers = nashwan_saved["launchers"]
		weapon_slots = nashwan_saved["slots"]
		nashwan_saved = {}


func _update_cannon(cannon: Dictionary, latched: bool) -> void:

	# code 0x246d : follows the ship at its offset. While ds:0x991e is not 0 it is placed by
	# 0x47a9 and does not fire. On frame 53 the shell leaves, on a fire event at rest (51)
	# the firing frames start.

	_step_animation(cannon, CANNON_FRAMES, CANNON_REST)
	var offset: Vector2i = cannon["offset"]
	cannon["x"] = ship_x + offset.x
	cannon["y"] = ship_y + offset.y
	cannon["visible"] = true
	var key: String = CANNON_FRAMES[cannon["anim"]][0]

	if attach != 0:
		_place_attachment(cannon, key)
		return

	if key == "X2WEAPS/053":
		effects.push_front({
			"kind": "shell",
			"x": cannon["x"],
			"y": cannon["y"] - 11,
			"anim": 0,
			"count": SHELL_FRAMES[0][1],
			"box": [1000, 0, 1000, 0],
			"dead": false,
		})
	elif latched and key == "X2WEAPS/051":

		# code 0x24a6 : effect 0x15

		sound_request = 0x15

		# game $40e0 : $80

		amiga_2 = 0x80
		cannon["anim"] = 0
		cannon["count"] = CANNON_FRAMES[0][1]


func _update_companion(companion: Dictionary) -> void:

	# code 0x21e9 : with its cannon, gone when the cannon is

	_step_animation(companion, COMPANION_FRAMES, 0)
	var cannon: Dictionary = companion["cannon"]

	# the record must still be a cannon : a cannon put aside by Super Nashwan Power keeps
	# its companion, which goes on following the ship at that cannon's offset

	if cannon["freed"]:
		companion["dead"] = true
		return

	var offset: Vector2i = cannon["offset"]
	companion["x"] = ship_x + offset.x
	companion["y"] = ship_y + offset.y
	companion["visible"] = true

	if attach != 0:
		_place_attachment(companion, COMPANION_FRAMES[companion["anim"]][0])


func _update_shell(shell: Dictionary) -> void:

	# code 0x28b8 : up 10 a frame, gone above the screen. Its box against the enemy boxes,
	# the first overlap takes 2. It is not removed by a hit (0x3a99 excepted).

	if dying:
		shell["dead"] = true
		return

	_step_animation(shell, SHELL_FRAMES, 0)
	shell["y"] += SHELL_SPEED

	if shell["y"] < 0:
		shell["dead"] = true
		return

	shell["box"] = _box_of(SHELL_FRAMES[shell["anim"]][0], shell["x"], shell["y"])

	for enemy in enemies:
		if _overlap(shell["box"], enemy["box"]):
			_hit_enemy(enemy, SHELL_DAMAGE, shell)
			return

	_block_hit(shell["box"])


func _update_gun(gun: Dictionary, latched: bool) -> void:

	# code 0x37df : the base gun fires on the latched fire event

	if blocked or not latched:
		return

	_fire_bullet(0, GUN_OFFSET_Y, 0, GUN_SPEED, gun["level"], gun_textures, GUN_PICTURES)


func _fire_bullet(offset_x: int, offset_y: int, vx: int, vy: int, level: int, textures_by_level: Array, pictures: Array) -> void:

	# code 0x45f4 : effect 2 unless one is already asked for, then a bullet at the front of
	# the effects list, at the ship plus the offset, with its speed, the picture of the
	# weapon level and the level

	if sound_request == 0:
		sound_request = 2

	# game $615a : $89 unless one is asked for

	if amiga_2 < 0:
		amiga_2 = 0x89

	effects.push_front({
		"kind": "gun",
		"x": ship_x + offset_x,
		"y": ship_y + offset_y,
		"vx": vx,
		"vy": vy,
		"level": level,
		"texture": textures_by_level[level],
		"hot": Vector2i(pictures[level][0], pictures[level][1]),
		"dead": false,
	})


func _update_rear(launcher: Dictionary, latched: bool) -> void:

	# code 0x3835 : follows the ship. While ds:0x991e is not 0 it is placed by 0x47a9 and
	# does not fire. A shot plays the recoil frames and fires down (no blocked test here,
	# the bullets remove themselves while the ship is dying).

	_step_animation(launcher, REAR_FRAMES, 0)
	launcher["x"] = ship_x
	launcher["y"] = ship_y
	launcher["visible"] = true

	if attach != 0:
		_place_attachment(launcher, REAR_FRAMES[launcher["anim"]][0])
		return

	if latched:
		launcher["count"] = 1
		_fire_bullet(0, REAR_OFFSET_Y, 0, REAR_SPEED, launcher["level"], rear_textures, REAR_PICTURES)


func _update_double(launcher: Dictionary, latched: bool) -> void:

	# code 0x20f7 : on the ship, two bullets 12 rows above it, 5 to the left and 6 to the
	# right, with the base gun pictures

	launcher["x"] = ship_x
	launcher["y"] = ship_y
	launcher["visible"] = true

	if attach != 0:
		_place_attachment(launcher, DOUBLE_FRAMES[0][0])
		return

	if latched:
		_fire_bullet(-5, -12, 0, GUN_SPEED, launcher["level"], gun_textures, GUN_PICTURES)
		_fire_bullet(6, -12, 0, GUN_SPEED, launcher["level"], gun_textures, GUN_PICTURES)


func _update_side(launcher: Dictionary, latched: bool) -> void:

	# code 0x3801 : no picture, two bullets sideways, 9 a frame, from (x - 2, y - 3) and
	# (x + 2, y - 3)

	if blocked or not latched:
		return

	_fire_bullet(-2, -3, -9, 0, launcher["level"], side_left_textures, SIDE_LEFT_PICTURES)
	_fire_bullet(2, -3, 9, 0, launcher["level"], side_right_textures, SIDE_RIGHT_PICTURES)


func _update_laser(launcher: Dictionary, latched: bool) -> void:

	# code 0x237e : at its side slot offset, a beam on a fire event at most every 7 frames

	_step_animation(launcher, LASER_FRAMES, 0)
	var offset: Vector2i = launcher["offset"]
	launcher["x"] = ship_x + offset.x
	launcher["y"] = ship_y + offset.y
	launcher["visible"] = true

	if attach != 0:
		_place_attachment(launcher, LASER_FRAMES[launcher["anim"]][0])
		return

	if launcher["cool"] >= 0:
		launcher["cool"] -= 1

	if latched and launcher["cool"] < 0:

		# code 0x23b8 : effect 0x10

		sound_request = 0x10

		# game $3f82 : 6

		amiga_2 = 6
		effects.push_front({
			"kind": "beam",
			"owner": launcher,
			"x": launcher["x"],
			"y": launcher["y"],
			"length": -0x20,
			"level": launcher["level"],
			"dead": false,
		})
		launcher["cool"] = 6


func _update_beam(beam: Dictionary) -> void:

	# code 0x23ed : grows by 32 a frame under its laser (x - 7, y - 24) up to 64 rows, then
	# leaves it (length 0x41) and goes up 32 a frame. Every frame its box hurts every enemy
	# it overlaps, for 3 * (level + 1).

	if dying:
		beam["dead"] = true
		return

	if beam["length"] != 0x41:
		var owner: Dictionary = beam["owner"]
		beam["x"] = owner["x"] - 7
		beam["y"] = owner["y"] - 0x18
		beam["length"] += 0x20

	if beam["length"] == 0x60 or beam["length"] == 0x41:
		beam["length"] = 0x41
		beam["y"] -= 0x20

		if beam["y"] < 0:
			beam["dead"] = true
			return

	var level: int = beam["level"]
	var x1: int = beam["x"] + 4 - 2 * level
	var y1: int = beam["y"] - beam["length"]
	var y2 := y1 + 0x20

	if y2 < 0:
		return

	_area_damage([x1, maxi(y1, 0), x1 + 4 * level + 7, y2], 3 * (level + 1))


func _update_electro(launcher: Dictionary) -> void:

	# code 0x229b : sits 25 rows below where the ship was (ds:0x8ebc). While fire is held it
	# moves four times as far as the ship does, inside the screen, and hits the first enemy
	# its box overlaps for 4 a frame. Released, it comes back at most 8 a frame.

	_step_animation(launcher, ELECTRO_FRAMES, 0)
	var key: String = ELECTRO_FRAMES[launcher["anim"]][0]

	if attach != 0:
		_place_attachment(launcher, key)
		return

	launcher["visible"] = true
	var home: Vector2i = trail[0] + Vector2i(0, 0x19)

	if launcher["state"] == 0:
		if not held_fire:
			launcher["x"] = home.x
			launcher["y"] = home.y
			return

		launcher["state"] = 1
	elif launcher["state"] > 0:
		if not held_fire:
			launcher["state"] = -1
			return

		launcher["x"] = clampi((ship_x - ship_prev.x) * 4 + launcher["x"], 0, 0x13f)
		launcher["y"] = clampi((ship_y - ship_prev.y) * 4 + launcher["y"], 0, 0xbf)
	else:
		_home(launcher, home)
		return

	var box := _box_of(key, launcher["x"], launcher["y"])

	for enemy in enemies:
		if _overlap(box, enemy["box"]):

			# code 0x22d7 : the effect asked for is cancelled

			sound_request = 0

			# game $3e72 : on the Amiga the hit has an effect, $15

			amiga_2 = 0x15
			_hit_enemy(enemy, ELECTRO_DAMAGE, {"box": box})
			return

	if _block_hit(box):
		sound_request = 0
		amiga_2 = 0x15


func _home(launcher: Dictionary, home: Vector2i) -> void:

	# code 0x2330, 0x286a : at most 8 a frame on each axis, state 0 once there

	launcher["x"] += clampi(home.x - launcher["x"], -8, 8)
	launcher["y"] += clampi(home.y - launcher["y"], -8, 8)

	if launcher["x"] == home.x and launcher["y"] == home.y:
		launcher["state"] = 0


func _update_mine_launcher(launcher: Dictionary) -> void:

	# code 0x2697 : 25 rows below the ship. Fire held : it climbs 12 a frame to y 16, then
	# the joystick steers it 8 a frame and it drops a mine every 32 pixels, at most 10 out.
	# Released : it comes back and the mines go off one after the other (0x26d4).

	var frames: Array = launcher["frames"]
	_step_animation(launcher, frames, 0)

	if attach != 0:
		_place_attachment(launcher, frames[launcher["anim"]][0])
		return

	launcher["visible"] = true

	match launcher["state"]:
		0:
			launcher["x"] = ship_x
			launcher["y"] = ship_y + 0x19

			if held_fire:
				launcher["state"] = 1
		1:
			if not held_fire:
				launcher["state"] = 3
			elif launcher["y"] > 0x10:
				launcher["y"] -= 0xc
			else:
				launcher["state"] = 2
		2:
			if not held_fire:
				launcher["state"] = 3
				return

			var x: int = launcher["x"]
			var y: int = launcher["y"]

			if held_left:
				x = maxi(x - 8, 0)

			if held_right:
				x = mini(x + 8, 0x13f)

			if held_up:
				y = maxi(y - 8, 0)

			if held_down:
				y = mini(y + 8, 0xbf)

			launcher["x"] = x
			launcher["y"] = y

			if mines_out == 10:
				return

			if absi(mine_mark.x - x) < 0x20 and absi(mine_mark.y - y) < 0x20:
				return

			mine_mark = Vector2i(x, y)
			mines_out += 1
			effects.push_front({
				"kind": "mine",
				"frames": frames,
				"anim": launcher["anim"],
				"count": frames[launcher["anim"]][1],
				"x": x,
				"y": y,
				"level": launcher["level"],
				"state": -mines_out * 4,
				"dead": false,
			})
		_:
			_home(launcher, Vector2i(ship_x, ship_y + 0x19))


func _update_mine(mine: Dictionary) -> void:

	# code 0x26d4 : waits while fire is held, then counts up to 0 (4 frames per place in
	# the drop order) and goes off : 4 explosions (small, or large at level 1) and every
	# enemy in the blast takes 4 + 2 * level

	_step_animation(mine, mine["frames"], 0)

	if dying:
		mine["dead"] = true
		return

	if held_fire:
		return

	mine["state"] += 1

	if mine["state"] != 0:
		return

	var x: int = mine["x"]
	var y: int = mine["y"]

	if mine["level"] == 0:
		_explosions(x - 8, y - 8, 0x10, 0x10, SMALL_EXPLOSION)
		_area_damage([x - 0x10, y - 0x10, x + 0x10, y + 0x10], 4)
	else:
		_explosions(x - 0x12, y - 0x12, 0x14, 0x14, LARGE_EXPLOSION)
		_area_damage([x - 0x18, y - 0x18, x + 0x17, y + 0x17], 6)

	mine["dead"] = true
	mines_out -= 1


func _explosions(x: int, y: int, width: int, height: int, frames: Array, count: int = 4) -> void:

	# code 0x1588 : count explosions (cx + 1) at random places of the area, each in front of
	# the last, then effect 6, first

	for i in count:
		var ex: int = (_random() % width) + x
		var ey: int = (_random() % height) + y
		effects.push_front({
			"kind": "explosion",
			"x": ex,
			"y": ey,
			"frames": frames,
			"index": 0,
			"count": 1,
			"dead": false,
		})

	sound_request = 6
	sound_priority = 6

	# game $428c : $83 on both

	amiga_2 = 0x83
	amiga_1 = 0x83


func _block_hit(box: Array) -> bool:

	# code 0xf96 : the level's extra target for a shot that met no enemy, level 2 only
	# (0x8ca7, see BLOCK_LISTS). True when a block broke (0x8d18, the damage not used).

	if level_number != 2:
		return false

	var x1: int = box[0]
	var y1: int = box[1] + scroll
	var x2: int = box[2]
	var y2: int = box[3] + scroll

	if y1 >= BLOCK_LINE:
		return false

	var index := (1 if y1 <= 0x80 else 0) | (2 if x1 <= 0x80 else 0)
	var states: Array = blocks[index]
	var list: Array = BLOCK_LISTS[index]

	for i in list.size():
		if states[i] == 0:
			continue

		var bx: int = list[i][0]
		var by: int = list[i][1]

		if bx > x2:
			return false

		if not _overlap([x1, y1, x2, y2], [bx, by, bx + 15, by + 15]):
			continue

		# code 0x8d18

		states[i] = 0
		map_words[(by >> 4) * 20 + (bx >> 4)] = 0
		_explode_at(bx + 8, by - scroll + 8, SMALL_EXPLOSION)
		return true

	return false


func _block_rebuild(box: Array) -> void:

	# code 0x8d5f (level 2, from the crawler 0x84e1) : the first broken block of the list
	# 0x8c85 picks whose square overlaps the box (scroll added) is there again, its map word
	# back. No stop on x here.

	var x1: int = box[0]
	var y1: int = box[1] + scroll
	var world_box := [x1, y1, box[2], box[3] + scroll]
	var index := (1 if y1 <= 0x80 else 0) | (2 if x1 <= 0x80 else 0)
	var states: Array = blocks[index]
	var list: Array = BLOCK_LISTS[index]

	for i in list.size():
		if states[i] != 0:
			continue

		var bx: int = list[i][0]
		var by: int = list[i][1]

		if _overlap(world_box, [bx, by, bx + 15, by + 15]):
			states[i] = 1
			map_words[(by >> 4) * 20 + (bx >> 4)] = list[i][2]
			return


func _bonus_pairs(pairs: int) -> void:

	# code 0x15e4 : pairs of bonuses (small, large) at random places at the end of the
	# effects list, each counted in ds:0x9164. unconfirmed : the bonuses' first direction is
	# left from older records, 0 here.

	for i in pairs:
		for large in [false, true]:
			var bx := _random() % 300 + 10
			var by := _random() % 180 + 6
			var bonus := {
				"kind": "bonus",
				"x": bx,
				"y": by,
				"large": large,
				"frames": LARGE_BONUS if large else SMALL_BONUS,
				"index": 0,
				"phase": 7,
				"direction": 0,
				"dead": false,
				"box": [1000, 0, 1000, 0],
			}
			effects.append(bonus)
			appended.append(bonus)
			bonuses_out += 1


func _draw_grid(grid: Array, x: int, y: int, flash: bool) -> void:

	# stubs 0x941 and 0x963 : a grid of tiles, 0 empty, negative masked (colour 0
	# transparent), or every non empty pixel in colour 7 for the flash

	for row in grid.size():
		for column in grid[row].size():
			var word: int = grid[row][column]

			if word == 0:
				continue

			var tile := absi(word)
			var at := Vector2(x + column * 16, y + row * 16)

			if flash:
				world.draw_texture(_tile_flash(tile), at)
			elif word < 0:
				world.draw_texture(_tile_masked(tile), at)
			else:
				var origin := _tile_origin(tile)
				world.draw_texture_rect_region(tile_atlas, Rect2(at, Vector2(16, 16)), Rect2(origin.x, origin.y, 16, 16))


func _area_damage(box: Array, damage: int) -> void:

	# code 0x1c4f : every enemy whose box overlaps, once for a segmented enemy (0x1689).
	# Only the first one while end of level bonuses are out. Code 0x1cb3 : after a hit the
	# next object (past the hit one's linked parts, 0x1689) is looked at, and when the hit
	# freed it (type 4, 0x7c0 : a killed enemy's parts) the damage stops there, the level's
	# extra target too.

	var hit_heads: Array = []
	var order := enemies.duplicate()

	for i in order.size():
		var enemy: Dictionary = order[i]

		if not _overlap(box, enemy["box"]):
			continue

		var head: Variant = enemy.get("head", null)
		var target: Dictionary = enemy if head == null else head

		if hit_heads.has(target):
			continue

		hit_heads.append(target)
		var next := i + 1

		while next < order.size() and order[next].get("head", null) == target:
			next += 1

		var next_was_dead: bool = next >= order.size() or order[next]["dead"]
		_hit_enemy(enemy, damage, {"box": box})

		if bonuses_out != 0:
			return

		if not next_was_dead and order[next]["dead"]:
			return

	# code 0x1cc1 : the level's extra target once the list is done

	_block_hit(box)


func _update_drone(launcher: Dictionary) -> void:

	# code 0x221a : 25 rows below where the ship was (ds:0x8ebc). With fire held, every 7
	# frames a burst of shots (4, 8 or 12 by level, ds:0x30ec) goes to the free entries of
	# the shot table (ds:0x9c80, 80 entries).

	_step_animation(launcher, DRONE_FRAMES, 0)
	launcher["x"] = trail[0].x
	launcher["y"] = trail[0].y + 0x19

	if attach != 0:
		_place_attachment(launcher, DRONE_FRAMES[launcher["anim"]][0])
		return

	launcher["visible"] = true

	if launcher["cool"] != 0:
		launcher["cool"] -= 1

	if not held_fire or launcher["cool"] != 0:
		return

	launcher["cool"] = 6
	var slot := 0

	for shot in DRONE_SHOTS[launcher["level"]]:
		while slot < SPARK_COUNT and sparks.has(slot):
			slot += 1

		if slot >= SPARK_COUNT:
			return

		sparks[slot] = [launcher["x"] + shot[0], launcher["y"] + shot[1], shot[2], shot[3]]
		slot += 1


func _update_sparks() -> void:

	# code f29:13c3 (stub 0xa95) : each shot moves, goes when off the area, hits the first
	# enemy whose box holds it. The damage is read with es = ds at ds:0x3da8, which holds
	# the text "AT" (0x5441), not the 1 at cs:0x3da8 that the other display modes read : in
	# EGA and VGA a drone shot kills what it hits. Otherwise a 2 by 2 dot is drawn.

	spark_dots.clear()

	for slot in range(SPARK_COUNT):
		if not sparks.has(slot):
			continue

		var s: Array = sparks[slot]
		var x: int = s[0] + s[2]
		var y: int = s[1] + s[3]

		if x < 0 or x >= 0x13c or y < 0 or y >= 0xbc:
			sparks.erase(slot)
			continue

		s[0] = x
		s[1] = y
		var hit := false

		for enemy in enemies:
			var b: Array = enemy["box"]

			if x >= b[0] and x <= b[2] and y >= b[1] and y <= b[3]:
				_hit_enemy(enemy, DRONE_DAMAGE, {"box": [x, y, x, y]})
				hit = true
				break

		if not hit:
			hit = _block_hit([x, y, x, y])

		if hit:
			sparks.erase(slot)
		else:
			spark_dots.append(Vector2i(x, y))


func _update_shield(item: Dictionary) -> void:

	# code 0x1fb4 : the next frame, on the ship. While ds:0x991e is not 0 it is placed by
	# 0x47a9 and counts nothing. Else one frame less with its gauge at (4, 0xa0) by 10 *
	# frames left / 0xab (0x465c), and at 0 the picture goes.

	_step_animation(item, SHIELD_FRAMES, 0)
	item["x"] = ship_x
	item["y"] = ship_y
	item["visible"] = true

	if attach != 0:
		_place_attachment(item, SHIELD_FRAMES[item["anim"]][0])
		return

	shield -= 1
	shield_gauge = GAUGE_FIRST + 10 * shield / (SHIELD_ADD + 1)

	if shield == 0:
		item["dead"] = true


func _place_attachment(item: Dictionary, key: String) -> void:

	# code 0x47a9 : hidden at 16, otherwise the distance between its centre and the ship's
	# centre is multiplied by ds:0x991e, so it slides in from far away

	if attach == 16:
		item["visible"] = false
		return

	var own := _centre(key, item["x"], item["y"])
	var ship_centre := _centre("X2SPR/%03d" % ship_frame, ship_x, ship_y)
	item["x"] = attach * (own.x - ship_centre.x) + ship_centre.x
	item["y"] = attach * (own.y - ship_centre.y) + ship_centre.y


func _centre(key: String, x: int, y: int) -> Vector2i:

	# code 0xef5 : the centre of a frame drawn at (x, y)

	var h: Array = headers[key]
	return Vector2i(((x - h[4]) * 2 + h[6]) >> 1, ((y - h[5]) * 2 + h[7] - 1) >> 1)


func _update_gun_bullet(bullet: Dictionary) -> void:

	# code 0x39ee : moves by its speed, gone when off the play area (x tested before y moves),
	# hits the first enemy box (newest first) that holds its point, for its level + 1

	if dying:
		bullet["dead"] = true
		return

	bullet["x"] += bullet["vx"]

	if bullet["x"] < 0 or bullet["x"] >= 0x138:
		bullet["dead"] = true
		return

	bullet["y"] += bullet["vy"]

	if bullet["y"] < 0 or bullet["y"] >= 0xc0:
		bullet["dead"] = true
		return

	for enemy in enemies:
		var b: Array = enemy["box"]

		if bullet["x"] >= b[0] and bullet["x"] <= b[2] and bullet["y"] >= b[1] and bullet["y"] <= b[3]:
			bullet["dead"] = true
			_hit_enemy(enemy, bullet["level"] + 1, {"box": [bullet["x"], bullet["y"], bullet["x"], bullet["y"]]})
			return

	if _block_hit([bullet["x"], bullet["y"], bullet["x"], bullet["y"]]):
		bullet["dead"] = true


# ---------------------------------------------------------------- enemies

func _check_waves() -> void:

	# code 0x3615 : waves fire when scroll <= y < last check. Only when the scroll is
	# below the last wave check does that become the scroll and the wall objects are
	# checked (0x364b) the same way, with their own last check (ds:0x9194).

	for event in events:
		var y := int(event["y"])

		if y < wave_check and scroll <= y:
			_spawn_wave(event)

	if scroll >= wave_check:
		return

	wave_check = scroll

	for wall in walls:
		var y := int(wall["y"])

		if y < wall_check and scroll <= y:
			_spawn_wall(wall)

	if scroll < wall_check:
		wall_check = scroll


func _spawn_wall(wall: Dictionary) -> void:

	# code 0xfd2 and 0x6ef6 : level 1 wall object handlers by type

	var type := int(wall["type"])
	var side := int(wall["side"])
	var x := int(wall["x"]) - 8
	var world_y := int(wall["world_y"]) - 8

	if type == 0:

		# code 0x35ce : checkpoint, the scroll and x the ship restarts from

		checkpoint_scroll = int(wall["y"])
		checkpoint_x = int(wall["x"])

		# code 0x35df : the credits too (ds:0x9166)

		checkpoint_credits = credits
		_save_weapons()
		return

	if level2 != null:
		level2.spawn_wall(wall)
		return

	if level3 != null:
		level3.spawn_wall(wall)
		return

	if level4 != null:
		level4.spawn_wall(wall)
		return

	if level5 != null:
		level5.spawn_wall(wall)
		return

	if level_number != 1:
		return

	if type == 4:
		_spawn_wall_pod(wall, side, x, world_y)
		return

	if not WALL_TYPES.has(type):
		return

	# code 0x3529 : a creature made of 2x2 map tiles, at the front of the enemies list.
	# Its map cell is from (x - 8, y - 8). Type 2 on the left side sits one column left.

	var spec: Dictionary = WALL_TYPES[type]

	if type == 2 and side == 0:
		x -= 16

	var creature := {
		"kind": "wall",
		"type": type,
		"side": side,
		"x": x,
		"world_y": world_y,
		"cell": (world_y >> 4) * 20 + (x >> 4),
		"frames": spec["frames"][side],
		"death": spec["death"][side],
		"first": spec["frames"][side][0] if type != 3 else spec["init"][side],
		"counter": 0,
		"fire_counter": 0,
		"energy": 2,
		"score": 100,
		"large": false,
		"hit": "0x3b76",
		"box": [1000, 0, 1000, 0],
		"flash": false,
		"dead": false,
		"group": 0,
		"head": null,
		"segments": [],
	}

	# the first map write : type 1 only its top row, types 2 and 3 all four words

	var first: Array = creature["first"]
	_write_tiles(creature["cell"], first, 4 if type != 1 else 2)
	enemies.push_front(creature)


func _write_tiles(cell: int, words: Array, count: int) -> void:

	# words in the order top left, top right, bottom left, bottom right, as tile numbers
	# with bit 0 set (tile << 6 | 1), 0 meaning the word 0

	for i in count:
		var index := cell + (i >> 1) * 20 + (i & 1)

		if index >= 0 and index < map_words.size():
			var tile: int = words[i]
			map_words[index] = 0 if tile == 0 else (tile << 6) | 1


func _update_wall(creature: Dictionary) -> void:

	# code 0x6d22 (type 1), 0x6ac7 (type 2), 0x6bca (type 3) : removed far below the
	# furthest scroll, box in screen rows, map write, animation, fire

	if creature["world_y"] > scroll_max + 0xd0:
		creature["dead"] = true
		return

	var type: int = creature["type"]
	var x: int = creature["x"]
	var sy: int = creature["world_y"] - scroll
	var box: Array = WALL_TYPES[type]["box"]
	creature["box"] = [x + box[0], sy + box[1], x + box[2], sy + box[3]]
	var spec: Dictionary = WALL_TYPES[type]

	if type == 1:
		_write_tiles(creature["cell"], creature["frames"][creature["counter"] >> 2], 4)
		creature["counter"] = (creature["counter"] + 1) & 15
	elif type == 2:
		_write_tiles(creature["cell"], creature["frames"][creature["counter"]], 4)
		creature["counter"] = (creature["counter"] + 1) & 3
	else:

		# type 3 : only the top row, 20 frames of 2 updates. Closed until the timer
		# carries, then 40 updates with the shot at 24.

		_write_tiles(creature["cell"], creature["frames"][creature["counter"] >> 1], 2)

		if creature["counter"] == 0:
			creature["fire_counter"] += spec["rate"]

			if creature["fire_counter"] < 0x100:
				return

			creature["fire_counter"] = _random() & 0x3f

		creature["counter"] += 1

		if creature["counter"] == 40:
			creature["counter"] = 0
		elif creature["counter"] == 24:
			_wall_shot(creature, sy)

		return

	creature["fire_counter"] += spec["rate"]

	if creature["fire_counter"] >= 0x100:
		creature["fire_counter"] = _random() & 0x3f
		_wall_shot(creature, sy)


func _wall_shot(creature: Dictionary, sy: int) -> void:

	# a shot sideways, out of the wall : right on the left side, left on the right side

	var spec: Dictionary = WALL_TYPES[creature["type"]]
	var left: bool = creature["side"] == 0
	var bx: int = creature["x"] + (spec["shot_x"] if left else 0)
	_enemy_bullet(bx, sy + spec["shot_y"], 2 if left else 6, spec["bullet"], spec["speed"])


func _update_boss() -> void:

	# code 0x72c4

	if scroll > 0x1c0:
		boss["box"] = [1000, 0, 1000, 0]
		return

	if not boss["made"]:

		# the tentacle : 8 segments at the front of the enemies list in order, the last the
		# tip (type 0x100), each following the one before it

		boss["made"] = true
		var parent: Dictionary = boss
		var made: Array = []

		for i in 8:
			var segment := {
				"kind": "segment",
				"tip": i == 7,
				"parent": parent,
				"x": 0, "y": -100, "x_frac": 0, "y_frac": 0,
				"heading": 0, "turn": 0, "change": 0, "reach": 0,
				"key": "S1/038",
				"hit": "0x3a99",
				"large": false,
				"group": 0,
				"head": null,
				"segments": [],
				"fire_counter": 0,
				"box": [1000, 0, 1000, 0],
				"flash": false,
				"dead": false,
			}
			made.append(segment)
			parent = segment

		enemies = made + enemies
		boss["heading"] = 0
		boss["turn"] = 0
		boss["change"] = 0

	if scroll_max > 0x1c0:
		scroll_max = 0x1c0

	var sy: int = boss["y"] - scroll
	boss["box"] = [128, sy + 4, 200, sy + 84]

	if boss["phase"] == 0 and scroll > 0x30:
		_boss_mouth()
		boss["box"] = [1000, 0, 1000, 0]
		return

	if boss["phase"] == 0:
		boss["phase"] = 1
		boss["velocity"] = 0
		boss["timer"] = 170

	# the tentacle grows to 11 steps a segment in 99 frames, shrinks in 40

	if boss["phase"] >= 0 and boss["reach"] < 11:

		# code 0x73c8 : effect 1, first, when the tentacle starts to come out

		if boss["reach"] == 0:

			# Amiga level 1 code (disk 2, at $54e00) $564d4 : $f on $418

			sound_priority = 1
			amiga_1 = 0xf

		boss["reach"] += 1
	elif boss["phase"] < 0 and boss["reach"] > 0:
		boss["reach"] -= 1

	boss["phase"] += 1

	if boss["phase"] == 0:
		boss["phase"] += 1

	if boss["phase"] >= 100:
		boss["phase"] = -40

	# its waving, from the frame count

	var t := frame_count
	var a := t & 0x7f
	boss["heading"] = (32 + (127 - a if a >= 64 else a)) << 16
	var b := (t + 0x50) & 0xff
	boss["turn"] = ((255 - b if b >= 128 else b) - 64) << 10
	var c := (t + 0xa0) & 0x1ff
	boss["change"] = ((511 - c if c >= 256 else c) - 128) << 5

	# up and down between 16 and 480

	var y: int = boss["y"] + boss["velocity"]

	if y < 16 or y > 480:
		y = clampi(y, 16, 480)
		boss["timer"] = 0

	boss["y"] = y
	boss["timer"] -= 1

	if boss["timer"] < 0:
		if boss["velocity"] == -1:
			boss["velocity"] = 0
			boss["timer"] = 170
		elif boss["velocity"] == 1:
			boss["velocity"] = 0
			boss["timer"] = 60
		else:
			boss["timer"] = 50
			boss["velocity"] = 1 if y == 16 else -1

	boss["eye"] = (boss["eye"] + 30 - boss["energy"]) & 0xff
	_boss_mouth()


func _boss_mouth() -> void:

	# cs:0x76e4 : the mouth tiles change every 4 frames

	var mouth: Array = BOSS_MOUTHS[(frame_count >> 2) & 3]
	var body: Array = boss["body"]

	for column in 4:
		body[5][column + 1] = mouth[0][column]
		body[6][column + 1] = mouth[1][column]


func _update_segment(segment: Dictionary) -> void:

	# code 0x71dd : takes the state of the segment before it (the first one starts at
	# (160, boss y + 0x60) with the boss's last frame state), then spends "reach" arc steps
	# of the path interpreter. The tip aims at the ship and fires once fully out.

	if not boss["made"]:
		segment["dead"] = true
		return

	var parent: Dictionary = segment["parent"]

	for field in ["x", "y", "x_frac", "y_frac", "heading", "turn", "change", "reach"]:
		if parent.has(field):
			segment[field] = parent[field]

	if parent == boss:
		segment["x"] = 160
		segment["x_frac"] = 0
		segment["y"] = boss["y"] + 0x60 - scroll
		segment["y_frac"] = 0

	for i in segment["reach"]:
		var angle: int = (segment["heading"] >> 16) & 0xff
		var dy: int = int(sine[angle]) * 4
		var dx: int = int(sine[angle + 64]) * 4
		segment["y_frac"] += dy & 0xff
		segment["y"] += (dy >> 8) + (segment["y_frac"] >> 8)
		segment["y_frac"] &= 0xff
		segment["x_frac"] += dx & 0xff
		segment["x"] += (dx >> 8) + (segment["x_frac"] >> 8)
		segment["x_frac"] &= 0xff
		segment["heading"] = (segment["heading"] + segment["turn"]) & 0xffffff
		segment["turn"] += segment["change"]

	if segment["reach"] == 0:
		segment["box"] = [1000, 0, 1000, 0]
	else:
		if segment["tip"]:
			var direction := _direction(ship_x - segment["x"], ship_y - segment["y"])
			segment["key"] = "S1/%03d" % TIP_FRAMES[direction]

			if segment["reach"] >= 11:
				segment["fire_counter"] += 15

				if segment["fire_counter"] >= 0x100:
					segment["fire_counter"] = _random() & 0x3f
					_enemy_bullet(segment["x"], segment["y"], direction, TIP_BULLET[0][0], 4)
					effects[0]["frames"] = TIP_BULLET
					effects[0]["anim"] = 0
					effects[0]["count"] = TIP_BULLET[0][1]

		segment["box"] = _box_of(segment["key"], segment["x"], segment["y"])


func _kill_boss() -> void:

	# code 0x71a9 : 9 pairs of bonuses (small, large) at random places at the end of the
	# effects list, 20 large explosions at random places at the front, every enemy freed.
	# No score. unconfirmed : the bonuses' first direction is left from older records, 0 here.

	boss["made"] = false

	for i in 9:
		for large in [false, true]:
			var bx := _random() % 300 + 10
			var by := _random() % 180 + 6
			var bonus := {
				"kind": "bonus",
				"x": bx,
				"y": by,
				"large": large,
				"frames": LARGE_BONUS if large else SMALL_BONUS,
				"index": 0,
				"phase": 7,
				"direction": 0,
				"dead": false,
				"box": [1000, 0, 1000, 0],
			}
			effects.append(bonus)
			appended.append(bonus)
			bonuses_out += 1

	for i in 20:
		var ex := _random() % 320
		var ey := _random() % 192
		effects.push_front({
			"kind": "explosion",
			"x": ex,
			"y": ey,
			"frames": LARGE_EXPLOSION,
			"index": 0,
			"count": 1,
			"dead": false,
		})

	for enemy in enemies:
		enemy["dead"] = true

	enemies.clear()
	level_done = true


func _spawn_wall_pod(wall: Dictionary, side: int, x: int, world_y: int) -> void:

	# code 0x705b : a sprite on the enemies list that goes up and down b * 16 rows and
	# fires three shots when level with the ship

	var travel := int(wall["b"]) * 16
	var pod := {
		"kind": "wall_pod",
		"side": side,
		"x": x + (16 if side == 1 else 0),
		"y": world_y - scroll,
		"frames": WALL_POD_FRAMES[side],
		"anim": 0,
		"count": WALL_POD_FRAMES[side][0][1],
		"velocity": -1,
		"left": travel,
		"travel": travel,
		"energy": 2,
		"score": 250,
		"large": true,
		"hit": "0x3aa7",
		"group": 0,
		"flash": false,
		"dead": false,
		"head": null,
		"segments": [],
	}
	pod["key"] = pod["frames"][0][0]
	pod["box"] = _box_of(pod["key"], pod["x"], pod["y"])
	enemies.push_front(pod)


func _update_wall_pod(pod: Dictionary) -> void:

	# code 0x6e2c

	if pod["y"] > scroll_max + 0xd0 - scroll:
		pod["dead"] = true
		return

	_step_animation(pod, pod["frames"], 0 if pod["velocity"] != 0 else -1)

	if pod["anim"] < 0:
		pod["dead"] = true
		return

	pod["key"] = pod["frames"][pod["anim"]][0]
	pod["y"] += scroll_applied

	if pod["velocity"] == 0:
		return

	var d: int = pod["y"] - ship_y

	if d >= -30 and d <= 10 and (_random() & 0xff) < 0x32:

		# fires : leaves the enemies list for the front of the effects list, plays its
		# opening frames and goes, three shots at 8

		pod["velocity"] = 0
		enemies.erase(pod)
		effects.push_front(pod)
		pod["frames"] = WALL_POD_OPEN[pod["side"]]
		pod["anim"] = 0
		pod["count"] = pod["frames"][0][1]
		pod["key"] = pod["frames"][0][0]

		for direction in ([7, 6, 5] if pod["side"] == 1 else [3, 2, 1]):
			_enemy_bullet(pod["x"], pod["y"] + 7, direction, "%s/%03d" % [LEVEL, ENEMY_BULLET_FRAMES[level_number]], 8)

		return

	pod["y"] += pod["velocity"]
	pod["left"] += pod["velocity"]

	if pod["left"] == 0 or pod["left"] == pod["travel"]:
		pod["velocity"] = -pod["velocity"]

	pod["box"] = _box_of(pod["key"], pod["x"], pod["y"])


func _spawn_wave(event: Dictionary) -> void:
	var type := int(event["type"])

	if not enemy_types.has(type):
		return

	var path: Dictionary = paths[int(event["path"])]
	var speed := int(event["speed"])

	if type == POD_TYPE:
		speed = POD_SPEED

	var spacing := int(event["spacing"])
	var fire := int(event["extra"]) & 0xff
	var offset := 0
	var large := false
	var spawned: Array = []

	for i in int(event["count"]):
		var head = null

		for part in enemy_types[type]:
			if part["frames"].is_empty():
				continue

			# code 0x3408 : with a spacing under 100 each enemy waits for the summed
			# spacing in steps before moving. With 100 or more they all start together,
			# shifted sideways by the summed spacing (minus the hundreds).
			# Parts after the first wait their own extra delay.

			var steps := 0

			if spacing < 100:
				steps -= offset

			if head != null:
				steps -= part["start_delay"]

			# code 0x346b : the fire counter starts at a random byte

			var enemy := {
				"frames": part["frames"],
				"path": path,
				"speed": speed,
				"steps": steps,
				"shift": offset if spacing >= 100 else 0,
				"age": 0,
				"x": 0,
				"y": 0,
				"box": [1000, 0, 1000, 0],
				"large": part["large"],
				"linked": part["linked"],
				"silent": part["silent"],
				"score": part["score"],
				"hit": part["hit"],
				"energy": part.get("energy", ENERGIES.get(level_number, ENERGIES[1])[1 if part["large"] else 0] * game_loop),
				"update": part.get("update", ""),
				"fire": fire,
				"item": int(event["speed"]),
				"fire_counter": _random() & 0xff,
				"group": 0,
				"flash": false,
				"dead": false,
				"head": head,
				"segments": [],
			}

			_place_enemy(enemy)

			if head == null:
				head = enemy
			else:
				head["segments"].append(enemy)

			enemies.push_front(enemy)
			spawned.append(enemy)
			large = part["large"]

		offset += spacing % 100

	if spawned.is_empty() or type == POD_TYPE:
		return

	# code 0x34e5 : the wave joins the group of this 4 frame window and size

	var id := large_group if large else small_group
	var slot_found = null

	for slot in groups:
		if slot[0] == id:
			slot_found = slot
			break

	if slot_found != null:
		slot_found[1] += int(event["count"])
	else:
		for slot in groups:
			if slot[0] == 0:
				slot[0] = id
				slot[1] = int(event["count"])
				slot_found = slot
				next_group += 1
				break

	if slot_found == null:
		return

	for enemy in spawned:
		enemy["group"] = id


func _place_enemy(enemy: Dictionary) -> void:
	var path: Dictionary = enemy["path"]
	var point: Vector2i = path["start"]

	if enemy["steps"] > 0:
		point = path["points"][enemy["steps"] - 1]

	enemy["x"] = point.x + enemy["shift"]
	enemy["y"] = point.y
	var frames: Array = enemy["frames"]
	enemy["key"] = frames[enemy["age"] % frames.size()]


func _update_enemies() -> void:

	# code 0x480b : animation, path, box, fire. Removed enemies are dropped here.

	var snapshot := enemies.duplicate()

	for enemy in snapshot:
		if enemy["dead"]:
			enemies.erase(enemy)
			continue

		if level2 != null and String(enemy.get("kind", "")).begins_with("l2_"):
			level2.update_enemy(enemy)
			continue

		if level3 != null and String(enemy.get("kind", "")).begins_with("l3_"):
			level3.update_enemy(enemy)
			continue

		if level4 != null and String(enemy.get("kind", "")).begins_with("l4_"):
			level4.update_enemy(enemy)
			continue

		if level5 != null and String(enemy.get("kind", "")).begins_with("l5_"):
			level5.update_enemy(enemy)
			continue

		match enemy.get("kind", "wave"):
			"wall":
				_update_wall(enemy)
				continue
			"wall_pod":
				_update_wall_pod(enemy)
				continue
			"boss":
				_update_boss()
				continue
			"segment":
				_update_segment(enemy)
				continue
			"hole_leader":
				_update_hole_leader(enemy)
				continue
			"hole_segment":
				_update_hole_segment(enemy)
				continue

		enemy["age"] += 1

		# code 0x37ca : a part that follows the first one (level 1 type 7, level 4 type 1) :
		# its animation, the first part's position as it was (it is updated before it), the
		# box. No path, so no end of its own, and no fire.

		if enemy.get("update", "") == "0x37ca":
			var lead: Dictionary = enemy["head"]
			var frames: Array = enemy["frames"]
			enemy["key"] = frames[enemy["age"] % frames.size()]
			enemy["x"] = lead["x"]
			enemy["y"] = lead["y"]
			enemy["box"] = _box_of(enemy["key"], enemy["x"], enemy["y"])
			continue

		var total: int = enemy["path"]["points"].size()

		# code 0x4871 : spend "speed" steps on the path. The end command is reached when a
		# tick starts with no steps left, or with budget left over after the last step.
		# code 0x49b5 : the end removes the enemy and cancels its group

		if enemy["speed"] != 0:
			var ended: bool = enemy["steps"] >= total

			if not ended:
				var before: int = enemy["steps"]
				enemy["steps"] += enemy["speed"]

				if enemy["steps"] > total:
					ended = true
				elif enemy["steps"] > 0 and enemy["steps"] > before:
					path_bx = enemy["path"]["angles"][enemy["steps"] - 1]

			if ended:
				_end_enemy(enemy)
				continue

		_place_enemy(enemy)

		if enemy.get("update", "") != "":
			Level3.wave_update(enemy)

		enemy["box"] = _box_of(enemy["key"], enemy["x"], enemy["y"])
		_enemy_fire(enemy)


func _end_enemy(enemy: Dictionary) -> void:
	_cancel_group(enemy["group"])
	enemies.erase(enemy)

	# the linked byte (definition byte 15) removes all parts together

	if enemy["linked"]:
		var head: Dictionary = enemy if enemy["head"] == null else enemy["head"]

		for part in [head] + head["segments"]:
			enemies.erase(part)


func _cancel_group(id: int) -> void:
	if id == 0:
		return

	for slot in groups:
		if slot[0] == id:
			slot[0] = 0
			slot[1] = 0


func _clear_groups() -> void:

	# code 0x36d3 : a slot whose id no enemy carries is cleared

	for slot in groups:
		if slot[0] == 0:
			continue

		var used := false

		for enemy in enemies:
			if enemy["group"] == slot[0]:
				used = true
				break

		if not used:
			slot[0] = 0
			slot[1] = 0


func _enemy_fire(enemy: Dictionary) -> void:

	# code 0x4813 : the rate (field 5 low byte, hundreds removed) is added to a byte
	# counter, a shot leaves on the carry. Under 100 it goes one of 8 random ways, from
	# 100 it is aimed. The aimed shot passes the vertical distance in DX, but 0x1b90 reads
	# BX, which still holds what the path interpreter left there : the heading of the last
	# step (the original's bug, kept).

	var rate: int = enemy["fire"]

	if rate == 0:
		return

	var add := rate

	while add >= 100:
		add -= 100

	enemy["fire_counter"] += add

	if enemy["fire_counter"] < 0x100:
		return

	enemy["fire_counter"] = _random() & 0x3f
	var direction := 0

	if rate < 100:
		direction = _random() & 7
	else:
		direction = _direction(ship_x - enemy["x"], path_bx)

	_enemy_bullet(enemy["x"], enemy["y"], direction, "%s/%03d" % [LEVEL, ENEMY_BULLET_FRAMES[level_number]], ENEMY_BULLET_SPEED)


func _enemy_bullet(x: int, y: int, direction: int, key: String, speed: int) -> void:

	# code 0x1ed3 : an enemy bullet (type 0x14) at the front of the effects list

	effects.push_front({
		"kind": "enemy_bullet",
		"x": x << 16,
		"y": y << 16,
		"direction": direction,
		"key": key,
		"speed": speed,
		"dead": false,
		"box": [1000, 0, 1000, 0],
	})


func _hit_enemy(enemy: Dictionary, damage: int, projectile: Dictionary = {}) -> void:

	# code 0x3a36 : the enemy's hit routine (definition +8)

	if enemy["dead"]:
		return

	if level2 != null and Level2.HITS.has(enemy["hit"]):
		level2.hit(enemy, damage)
		return

	if level5 != null and Level5.HITS.has(enemy["hit"]):
		level5.hit(enemy, damage, projectile)
		return

	if level4 != null and Level4.HITS.has(enemy["hit"]):
		level4.hit(enemy, damage, projectile)
		return

	if level3 != null and Level3.HITS.has(enemy["hit"]):
		level3.hit(enemy, damage)
		return

	if enemy["hit"] == "0x6696" or enemy["hit"] == "0x66a6":
		_hole_hit(enemy, damage)
		return

	if enemy["hit"] == "none":
		return

	if enemy["hit"] == "0x3aa7":

		# code 0x3aa7 : flash, energy down (unsigned), killed when not above 0

		enemy["flash"] = true

		if damage >= enemy["energy"]:
			_kill_enemy(enemy)
		else:
			enemy["energy"] -= damage
	elif enemy["hit"] == "0x3a39":

		# code 0x3a39 : every part flashes, the head's energy counts, on death every part
		# after the head is removed, exploding only when its byte +0x26 (definition byte 15)
		# is not negative (0x3a5c), then the head is killed

		var head: Dictionary = enemy if enemy["head"] == null else enemy["head"]

		for part in [head] + head["segments"]:
			part["flash"] = true

		if damage >= head["energy"]:
			for part in head["segments"]:
				if not part["dead"]:
					if not part.get("silent", false):
						_explode(part, head["large"])

					part["dead"] = true

			_kill_enemy(head)
		else:
			head["energy"] -= damage

	elif enemy["hit"] == "0x714d":

		# code 0x714d : only the eye (x 152..167, from y + 0x44 for 15 rows) counts, against
		# the projectile's box. A flash and the damage, death when not above 0.

		if not boss["made"] or projectile.is_empty():
			return

		var by: int = boss["y"] - scroll + 0x44
		var eye := [152, by, 167, by + 0xe]

		if not _overlap(projectile["box"], eye):
			return

		boss["flash"] = true

		if damage >= boss["energy"]:
			_kill_boss()
		else:
			boss["energy"] -= damage
	elif enemy["hit"] == "0x3a99":

		# code 0x3a99 : a tentacle segment takes no damage, the projectile is removed

		if not projectile.is_empty():
			projectile["dead"] = true
	elif enemy["hit"] == "0x3b76":

		# code 0x3b76 : wall creature. A one frame flash of its first frame's tiles, energy
		# down. When killed : 100 points, a large explosion at (x + 16, screen y + 16) with
		# no centring, no wave group, its death tiles written to the map, removed.

		enemy["flash"] = true

		if damage >= enemy["energy"]:

			# code 0x3bb1 : the explosion through 0x3326, effect 6 first

			score += enemy["score"]
			sound_priority = 6
			amiga_1 = 0x83
			var size: int = enemy.get("size", 2)
			effects.push_front({
				"kind": "explosion",
				"x": enemy["x"] + 8 * size,
				"y": enemy["world_y"] - scroll + 8 * size,
				"frames": LARGE_EXPLOSION,
				"index": 0,
				"count": 1,
				"dead": false,
			})
			_write_tiles(enemy["cell"], enemy["death"], size * size)
			enemy["flash"] = false
			enemy["dead"] = true
		else:
			enemy["energy"] -= damage
	elif enemy["hit"] == "0x1e61":

		# code 0x1e61 : any hit frees the pod's item at its position, the pod disappears
		# with no explosion and no score. unconfirmed : the item's direction (+0x1c) is
		# left from the record's last owner, taken as 0 (up) here

		var index: int = enemy["item"]
		sound_request = 0xe

		# game $36cc : $11

		amiga_2 = 0x11
		effects.push_front({
			"kind": "item",
			"item": index,
			"x": enemy["x"],
			"y": enemy["y"],
			"frames": ITEM_FRAMES.get(index, ITEM_FRAMES[0]),
			"anim": 0,
			"count": ITEM_FRAMES.get(index, ITEM_FRAMES[0])[0][1],
			"phase": 7,
			"direction": 0,
			"dead": false,
			"box": [1000, 0, 1000, 0],
		})
		enemy["dead"] = true


func _collect_item(index: int) -> void:

	# code ds:0x31d8 : the item's effect

	match index:
		0:

			# code 0x2ab2 : speed level up to 2

			if speed_level != 2:
				speed_level += 1
		2:

			# code 0x2a48 : energy + 20, at most 39, effect 0x12

			energy = mini(energy + ENERGY_ITEM, ENERGY_MAX)
			sound_request = 0x12

			# game $489a : 7

			amiga_2 = 7
		1:

			# code 0x2aa4 : the autofire step, up to 4

			if autofire_rate < 4:
				autofire_rate += 1
		3:

			# code 0x2a66 : energy + 40, then as item 2 (effect 0x12, at most 39). Amiga game
			# $48b4 : the same, 7.

			energy = mini(energy + 0x28, ENERGY_MAX)
			sound_request = 0x12
			amiga_2 = 7
		4:

			# code 0x308c : rear shot, or one level more if already there

			_give_rear()
		5:

			# code 0x2aca : jumps to 0x2ca6, the side shot

			_give_side()
		8:

			# code 0x2e84

			_give_drone()
		9:

			# code 0x31b6

			_give_laser()
		10:

			# code 0x2f08

			_give_electro()
		11:

			# code 0x2f7c

			_give_mine(0x38)
		12:

			# code 0x3126

			_give_missile_launcher()
		13:

			# code 0x2d86

			_give_homing()
		14:

			# code 0x2df0

			_give_flamer()
		15:

			# code 0x2d2a

			_give_bomb()
		16:

			# code 0x2b80 : the shield's picture when there is none (ds:0x9188 = 0), then
			# 0xaa frames more

			if shield == 0:
				effects.push_front({
					"kind": "shield",
					"x": ship_x,
					"y": ship_y,
					"anim": 0,
					"count": SHIELD_FRAMES[0][1],
					"visible": true,
					"box": [1000, 0, 1000, 0],
					"dead": false,
				})

			shield += SHIELD_ADD
		17:

			# code 0x2ac4 : 3 dives more

			dive += 3
		6:

			# code 0x2a6e

			_power_up()
		7:

			# code 0x3246 : a side cannon in the first free slot

			_give_cannon()
		18:

			# code 0x2ad0 : every enemy (parts after a head skipped, 0x1689) takes 0x7f,
			# every enemy bullet goes, the wave groups are cleared. Its flash (stub 0xeb3,
			# VGA f29:006f) turns colour 0 white and black 16 times without waiting, so it
			# is over within the frame and not drawn. With the Amiga graphics the Amiga
			# flash is shown (_z_flash_start).

			sound_request = 0xb
			_z_flash_start()

			# game $4932 : 2

			amiga_2 = 2

			for enemy in enemies.duplicate():

				# code 0x2ae9 : level 2's guardian (0x50) and targets (0x54) skipped

				if enemy["head"] == null and not enemy.get("type50", false) and not enemy.get("z_immune", false) and enemy.get("kind", "") != "l2_target":
					_hit_enemy(enemy, RAM_DAMAGE)

			for item in effects:
				if item["kind"] == "enemy_bullet":
					item["dead"] = true

			for slot in groups:
				slot[0] = 0
				slot[1] = 0


func _kill_enemy(enemy: Dictionary) -> void:

	# code 0x3ab2 : explosion, wave group count, score, removal

	_explode(enemy, enemy["large"])

	if enemy["group"] != 0:
		for slot in groups:
			if slot[0] == enemy["group"]:
				slot[1] -= 1

				if slot[1] == 0:
					slot[0] = 0
					_spawn_bonus(enemy)

				break

	score += enemy["score"]
	enemy["dead"] = true


func _explode(enemy: Dictionary, large: bool) -> void:

	# code 0xef5 : the centre of the current frame. Code 0x3326 : effect 6 first.

	sound_priority = 6

	# game $31ec : $85 for the small explosion, $83 for the large one, on $418

	amiga_1 = 0x83 if large else 0x85
	var h: Array = headers[enemy["key"]]
	var cx: int = ((enemy["x"] - h[4]) * 2 + h[6]) >> 1
	var cy: int = ((enemy["y"] - h[5]) * 2 + h[7] - 1) >> 1
	effects.push_front({
		"kind": "explosion",
		"x": cx,
		"y": cy,
		"frames": LARGE_EXPLOSION if large else SMALL_EXPLOSION,
		"index": 0,
		"count": 1,
		"dead": false,
	})


func _spawn_bonus(enemy: Dictionary) -> void:

	# code 0x3aec : at the enemy's position, phase 7, a random direction

	effects.push_front({
		"kind": "bonus",
		"x": enemy["x"],
		"y": enemy["y"],
		"large": enemy["large"],
		"frames": LARGE_BONUS if enemy["large"] else SMALL_BONUS,
		"index": 0,
		"phase": 7,
		"direction": _random() & 7,
		"dead": false,
		"box": [1000, 0, 1000, 0],
	})


# ---------------------------------------------------------------- effects

func _update_effects() -> void:

	# objects added at the front during this pass wait for the next one, objects added at
	# the end (0x78e : companions, end of level bonuses) are reached in this same pass

	var queue := effects.duplicate()
	appended.clear()

	while not queue.is_empty():
		for item in queue:
			_update_effect(item)

		queue = appended.duplicate()
		appended.clear()


func _update_effect(item: Dictionary) -> void:
	if item["dead"]:
		effects.erase(item)
		return

	match item["kind"]:
		"gun":
			_update_gun_bullet(item)
		"enemy_bullet":
			_update_enemy_bullet(item)
		"explosion":
			item["count"] -= 1

			if item["count"] == 0:
				item["index"] += 1

				if item["index"] >= item["frames"].size():
					item["dead"] = true
				else:
					item["count"] = 1
		"bonus", "item":
			_update_bonus(item)
		"wall_pod":
			_update_wall_pod(item)
		"shell":
			_update_shell(item)
		"companion":
			_update_companion(item)
		"beam":
			_update_beam(item)
		"mine":
			_update_mine(item)
		"missile":
			_update_missile(item)
		"bomb":
			_update_bomb(item)
		"homing":
			_update_homing(item)
		"flame":
			_update_flame(item)
		"shield":
			_update_shield(item)
		"hole_debris":
			_update_hole_debris(item)
		_:
			if level2 != null:
				level2.update_effect(item)
			elif level4 != null:
				level4.update_effect(item)
			elif level5 != null:
				level5.update_effect(item)


func _update_enemy_bullet(bullet: Dictionary) -> void:

	# code 0x1f4d : 16.16 movement, plus the scroll applied last frame, gone off the play
	# area, hits the ship's box for 4. unconfirmed : the fractions start at 0 here

	if bullet.has("frames"):
		_step_animation(bullet, bullet["frames"], 0)
		bullet["key"] = bullet["frames"][bullet["anim"]][0]

	var d: int = bullet["direction"]
	bullet["x"] += BULLET_DX[d] * bullet["speed"] * 4
	bullet["y"] += BULLET_DY[d] * bullet["speed"] * 4
	bullet["y"] += scroll_applied << 16

	var x: int = bullet["x"] >> 16
	var y: int = bullet["y"] >> 16

	if x < 0 or x >= 320 or y < 0 or y >= PLAY_HEIGHT:
		bullet["dead"] = true
		return

	bullet["box"] = _box_of(bullet["key"], x, y)

	# code 0xa7b4 : level 3's walker shots zig-zag

	if bullet.has("zigzag") and level3 != null:
		level3.zigzag(bullet)

	if blocked or not _overlap(bullet["box"], ship_box):
		return

	ship_flash = true
	_damage_ship(BULLET_DAMAGE)
	bullet["dead"] = true


func _update_bonus(bonus: Dictionary) -> void:

	# code 0x28df (wave bonuses and pod items) : drifts, heads for the screen centre every
	# 8 frames, spins once there, then falls 8 rows a frame. Touching the ship collects it :
	# a wave bonus gives 100 or 50 credits, a pod item its effect. Pod items can't be shot.

	if bonus["kind"] == "item":
		_step_animation(bonus, bonus["frames"], 0)
	else:
		bonus["index"] = (bonus["index"] + 1) % bonus["frames"].size()

	if bonus["phase"] > 0:
		bonus["phase"] &= 7

		if bonus["phase"] == 0:
			bonus["direction"] = _direction(160 - bonus["x"], 100 - bonus["y"])

		bonus["phase"] += 1
		var dx: int = 160 - bonus["x"]
		var dy: int = 100 - bonus["y"]

		if dx * dx + dy * dy < 400:
			bonus["phase"] = -34

		_step_bonus(bonus)
	elif bonus["phase"] < 0:
		bonus["phase"] += 1

		if bonus["phase"] & 3 == 0:
			bonus["direction"] = (bonus["direction"] + 1) & 7

		_step_bonus(bonus)
	else:
		bonus["y"] += 8

		if bonus["y"] >= 200:
			bonus["dead"] = true
			_bonus_gone()
			return

	bonus["box"] = _box_of(_bonus_key(bonus), bonus["x"], bonus["y"])

	if blocked or not _overlap(bonus["box"], ship_box):
		return

	bonus["dead"] = true

	if bonus["kind"] == "item":

		# code 0x29b5 : effect 0xf, then the item's routine (which may ask for its own)

		sound_request = 0xf

		# game $47be : $81, or 4 for the items whose routine has the flag

		amiga_2 = 4 if bonus["item"] in AMIGA_ITEM_FLAGS else 0x81
		_collect_item(bonus["item"])
	else:

		# code 0x2990 : effect 4

		credits += 100 if bonus["large"] else 50
		sound_request = 4

		# game $4730 : 5

		amiga_2 = 5
		_bonus_gone()


func _bonus_gone() -> void:

	# ds:0x9164 counts the end of level bonuses still out, the shop is due when it is 0

	if bonuses_out != 0:
		bonuses_out -= 1

		if bonuses_out == 0:
			shop_due = true


func _bonus_key(bonus: Dictionary) -> String:
	if bonus["kind"] == "item":
		return bonus["frames"][bonus["anim"]][0]

	return "X2SPR/%03d" % bonus["frames"][bonus["index"]]


func _step_bonus(bonus: Dictionary) -> void:
	var step: Vector2i = BONUS_STEP[bonus["direction"]]
	bonus["x"] += step.x
	bonus["y"] += step.y


# ---------------------------------------------------------------- scroll and score

func _scroll() -> void:

	# code 0x3e1a : asking off the base speed for 35 frames doubles the ask every frame.
	# The new scroll is clamped, ds:0x9198 keeps what was applied. The upper limit trails
	# the scroll by 16 rows and only comes down, except while held down against it.

	var old := scroll
	var asked := scroll_asked

	if asked != scroll_base:
		scroll_off_base += 1

		if scroll_off_base >= 0x23:
			asked <<= 1
	else:
		scroll_off_base = 0

	var new_scroll := scroll - asked

	if new_scroll < scroll_min:
		asked += new_scroll - scroll_min
		new_scroll = scroll_min

	if new_scroll > scroll_max:
		asked += new_scroll - scroll_max
		new_scroll = scroll_max

	scroll_applied = asked
	scroll = new_scroll
	var limit := new_scroll

	if old != scroll_max or not held_down:
		limit += BACK_SCROLL

	if limit <= scroll_max:
		scroll_max = limit


func _count_score() -> void:

	# code 0x10854 : once a tick the shown score moves towards the score by 1000 when 2000
	# or more behind, by 100 when 200 or more behind, otherwise by 10. One digit is
	# increased and the carry runs up to the millions. A shown score above the score
	# sets the score back to it.

	var behind := score - shown_score

	if behind < 0:
		score = shown_score
		return

	if behind == 0:
		return

	var digit := 5

	if behind >= 2000:
		digit = 3
		shown_score += 1000
	elif behind >= 200:
		digit = 4
		shown_score += 100
	else:
		shown_score += 10

	while digit >= 0:
		score_digits[digit] = (score_digits[digit] + 1) % 10

		if score_digits[digit] != 0:
			break

		digit -= 1


# ---------------------------------------------------------------- stars

func _init_stars() -> void:

	# code 0x426a : the table of 48 is written again from the start

	stars.clear()

	for i in STAR_COUNT:
		var row := _random() % 192
		var column := _random() % 40
		stars.append({"y": row, "x": column * 8 + 4, "fraction": 0})

	for i in STAR_LEAD:
		_move_stars(1)


func _move_stars(speed: int) -> void:

	# code 0x421c : star i adds speed * 8 * (i + 1) to its fraction and moves one row
	# for every 0x180, so the last star moves at the scroll speed. Rows wrap within 0 to 191.

	for i in STAR_COUNT:
		var star: Dictionary = stars[i]
		star["fraction"] += speed * 8 * (i + 1)

		while star["fraction"] < 0:
			star["y"] = 191 if star["y"] == 0 else star["y"] - 1
			star["fraction"] += 0x180

		while star["fraction"] >= 0x180:
			star["y"] = 0 if star["y"] == 191 else star["y"] + 1
			star["fraction"] -= 0x180


# ---------------------------------------------------------------- drawing

func _draw_map() -> void:

	# code 0x985 : every visible tile, opaque, from the words as they were when the frame
	# started (tile = word >> 6, bit 0 ignored here)

	var first_row := drawn_scroll >> 4
	var rows := drawn_words.size() / 20

	if use_amiga_gfx:

		# Amiga game $17d6 : the background from line $436 to the bottom, then from its top

		var rest := PLAY_HEIGHT - background_line
		map.draw_texture_rect_region(amiga_background, Rect2(0, 0, 320, rest), Rect2(0, background_line, 320, rest))

		if background_line > 0:
			map.draw_texture_rect_region(amiga_background, Rect2(0, rest, 320, background_line), Rect2(0, 0, 320, background_line))

		# ENHANCED, smooth : the map moves by part of a scroll step, the background's line
		# before the top shown over it

		if _smoothing():
			var start := posmod(background_line - 16, PLAY_HEIGHT)
			var first := mini(16, PLAY_HEIGHT - start)
			map.draw_texture_rect_region(amiga_background, Rect2(0, -16, 320, first), Rect2(0, start, 320, first))

			if first < 16:
				map.draw_texture_rect_region(amiga_background, Rect2(0, first - 16, 320, 16 - first), Rect2(0, 0, 320, 16 - first))

	if _smoothing() and first_row > 0:
		first_row -= 1

	for row in range(first_row, mini(first_row + 14, rows)):
		for column in 20:
			_draw_cell(map, row, column)


func _draw_cell(canvas: CanvasItem, row: int, column: int) -> void:
	var tile := drawn_words[row * 20 + column] >> 6
	var origin := _tile_origin(tile)
	var place := Rect2(column * 16, row * 16 - drawn_scroll, 16, 16)

	if use_amiga_gfx:

		# Amiga game $190c : an empty cell draws nothing, a masked tile only where its mask
		# is set

		var kind: Variant = amiga_tiles.get(str(tile), 1)

		if kind is Array:
			canvas.draw_texture(_amiga_masked(tile, kind), place.position)
			return

		if int(kind) == 0:
			return

	canvas.draw_texture_rect_region(tile_atlas, place, Rect2(origin.x, origin.y, 16, 16))


func _draw_under_map(key: String, x: int, y: int) -> void:

	# code f29:0c11 (0x897 with VGA, display mode 3) : the sprite, then the map cells of its top left corner,
	# 16 to the right, 16 down and both, drawn again over it (0x2a4f, map words of this
	# frame). With the dive's frame 93 (16x14, hot spot 7, 7) the ship is fully covered.
	# With Amiga graphics the cells are drawn again over the background of their place.
	# unconfirmed : what the Amiga game does.

	var h: Array = headers[key]
	var left: int = x - int(h[4])
	var top: int = y - int(h[5])

	for corner in [Vector2i(left, top), Vector2i(left + 16, top), Vector2i(left + 16, top + 16), Vector2i(left, top + 16)]:
		var column: int = corner.x >> 4

		if corner.x < 0 or column >= 20:
			continue

		var row: int = (corner.y + drawn_scroll) >> 4

		if row < 0 or (row + 1) * 20 > drawn_words.size():
			continue

		if use_amiga_gfx:
			var screen_y := row * 16 - drawn_scroll

			for part in 16:
				var line := screen_y + part

				if line < 0 or line >= PLAY_HEIGHT:
					continue

				var source := (line + background_line) % PLAY_HEIGHT
				world.draw_texture_rect_region(amiga_background, Rect2(column * 16, line, 16, 1), Rect2(column * 16, source, 16, 1))

		_draw_cell(world, row, column)


func _amiga_masked(tile: int, mask: Array) -> Texture2D:
	if not amiga_masked.has(tile):
		var image := tile_image.get_region(Rect2i(_tile_origin(tile), Vector2i(16, 16)))
		image.convert(Image.FORMAT_RGBA8)

		for y in 16:
			for x in 16:
				if (int(mask[y]) >> (15 - x)) & 1 == 0:
					image.set_pixel(x, y, Color(0, 0, 0, 0))

		amiga_masked[tile] = _hd_pair(image, _hd_tile(tile_amiga_hd, tile))

	return amiga_masked[tile]


func _draw_boss() -> void:

	# code 0x7520 : drawn while the scroll is under 0x280. The body grid at (112, y), each
	# tile opaque or masked, then the eye. The hit flash (0x7569) draws every non empty
	# tile pixel in colour 7 and no eye, for one frame.

	if scroll >= 0x280:
		return

	var by: int = boss["y"] - scroll
	var body: Array = boss["body"]

	for row in body.size():
		for column in body[row].size():
			var word: int = body[row][column]

			if word == 0:
				continue

			var tile := absi(word)
			var at := Vector2(112 + column * 16, by + row * 16)

			# ENHANCED : the mouth rows (5 and 6) always masked. The original draws the
			# opaque mouth tiles (cs:0x76e4) with their black, a box over the background
			# as the guardian moves.

			if boss["flash"]:
				world.draw_texture(_tile_flash(tile), at)
			elif word < 0 or (HD_TEXTURE.on and row >= 5):
				world.draw_texture(_tile_masked(tile), at)
			else:
				var origin := _tile_origin(tile)
				world.draw_texture_rect_region(tile_atlas, Rect2(at, Vector2(16, 16)), Rect2(origin.x, origin.y, 16, 16))

	if not boss["flash"]:
		var key := "S1/%03d" % BOSS_EYE[(boss["eye"] >> 6) & 3]
		world.draw_texture(_texture(key), Vector2(152, by + 0x42))

	flash_drawn(boss)


func _tile_masked(tile: int) -> Texture2D:

	# a tile drawn with its colour 0 transparent

	var key := -1 - tile

	if not tile_flash.has(key):
		var origin := _tile_origin(tile)
		var image := tile_image.get_region(Rect2i(origin, Vector2i(16, 16)))
		image.convert(Image.FORMAT_RGBA8)

		for y in 16:
			for x in 16:
				if not _solid(tile, x, y):
					image.set_pixel(x, y, Color(0, 0, 0, 0))

		tile_flash[key] = _hd_pair(image, _hd_tile(tile_masked_hd, tile))

	return tile_flash[key]


func _tile_flash(tile: int) -> Texture2D:

	# a tile's non zero pixels in colour 7 (bit 0 set, drawn transparently)

	if not tile_flash.has(tile):
		var origin := _tile_origin(tile)
		var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)

		for y in 16:
			for x in 16:
				if _solid(tile, x, y):
					image.set_pixel(x, y, COLOUR_7)

		tile_flash[tile] = _hd_pair(image, _painted(_hd_tile(tile_masked_hd, tile), COLOUR_7))

	return tile_flash[tile]


func _place() -> void:
	star_layer.visible = not use_amiga_gfx
	_shades_display()
	map.queue_redraw()
	world.queue_redraw()
	star_layer.queue_redraw()
	overlay.queue_redraw()
	hud_values.queue_redraw()


func _draw_sprite(key: String, x: int, y: int, flash: bool) -> void:

	# code 0x853 : drawn at its position minus the hot spot of its frame header

	var h: Array = headers[key]
	var texture := _flash_texture(key) if flash else _texture(key)
	world.draw_texture(texture, Vector2(x - h[4], y - h[5]))


func _draw_world() -> void:

	# code 0x3682 : draws in list order, ship, enemies, bullets and effects, newest first

	# ENHANCED, smooth : each object moved by the part of its last move not yet shown

	var smoothing := smooth_alpha < 1.0

	if ship_visible:
		if smoothing:
			world.draw_set_transform(Vector2(_limited(prev_ship.x - ship_x), _limited(prev_ship.y - ship_y)))

		if dying:
			_draw_sprite("X2SPR/%03d" % SHIP_DEATH_FRAMES[death_index], ship_x, ship_y, false)
		else:
			_draw_sprite("X2SPR/%03d" % ship_frame, ship_x, ship_y, ship_flash)

			if under_map:
				_draw_under_map("X2SPR/%03d" % ship_frame, ship_x, ship_y)

	if _smoothing():
		ship_flash_later = true
	else:
		ship_flash = false

	for flame in flames:
		if flame["visible"]:
			if smoothing:
				world.draw_set_transform(_lag(flame))

			_draw_sprite("X2SPR/%03d" % FLAME_FRAMES[flame["index"]][flame["frame"]], flame["x"], flame["y"], false)

	# launchers, newest first : the base gun and the side shot draw nothing, the others
	# their current frame

	for launcher in launchers:
		if not launcher["visible"]:
			continue

		if smoothing:
			world.draw_set_transform(_lag(launcher))

		match launcher["kind"]:
			"rear":
				_draw_sprite(REAR_FRAMES[launcher["anim"]][0], launcher["x"], launcher["y"], false)
			"cannon":
				_draw_sprite(CANNON_FRAMES[launcher["anim"]][0], launcher["x"], launcher["y"], false)
			"double", "laser", "electro", "mine", "drone", "missile_launcher", "flamer":
				_draw_sprite(launcher["frames"][launcher["anim"]][0], launcher["x"], launcher["y"], false)

	for enemy in enemies:
		if enemy["dead"]:
			continue

		if smoothing:
			if enemy.get("kind", "") == "wall":
				world.draw_set_transform(_scroll_lag())
			else:
				world.draw_set_transform(_lag(enemy))

		if enemy.get("kind", "") == "boss":
			if smoothing:
				var lag := _scroll_lag()

				if boss.has("py"):
					lag.y += _limited(boss["py"] - boss["y"])

				world.draw_set_transform(lag)

			_draw_boss()
			continue

		if level2 != null and String(enemy.get("kind", "")).begins_with("l2_"):
			level2.draw_enemy(enemy)
			continue

		if level3 != null and String(enemy.get("kind", "")).begins_with("l3_"):
			level3.draw_enemy(enemy)
			continue

		if level4 != null and String(enemy.get("kind", "")).begins_with("l4_"):
			level4.draw_enemy(enemy)
			continue

		if level5 != null and String(enemy.get("kind", "")).begins_with("l5_"):
			level5.draw_enemy(enemy)
			continue

		if enemy.get("kind", "") == "hole_leader":
			continue

		if enemy.get("kind", "") == "hole_segment":
			if enemy["shown"]:
				_draw_sprite(enemy["key"], enemy["x"], enemy["y"], enemy["flash"])

			flash_drawn(enemy)
			continue

		if enemy.get("kind", "") == "wall":

			# code 0x3bdf : a wall creature draws nothing (its tiles are in the map) except
			# the hit flash, the silhouettes of its first frame's tiles in colour 7

			if enemy["flash"]:
				var sy: int = enemy["world_y"] - scroll
				var first: Array = enemy["first"]

				for i in 4:
					if first[i] != 0:
						world.draw_texture(_tile_flash(first[i]), Vector2(enemy["x"] + (i & 1) * 16, sy + (i >> 1) * 16))

			flash_drawn(enemy)
			continue

		# ENHANCED : a part that follows the first one (code 0x37ca, level 1 type 7's tail,
		# level 4 type 1) drawn where the first one is now, so it stays on the body. The
		# original takes its place a tick late (the part is updated first), and the tail
		# floats off the capsule by a tick's move. Its box stays the original's.

		var at := Vector2i(enemy["x"], enemy["y"])
		var lead = enemy.get("head")

		if HD_TEXTURE.on and enemy.get("update", "") == "0x37ca" and lead != null and not lead["dead"]:
			at = Vector2i(lead["x"], lead["y"])

			if smoothing:
				world.draw_set_transform(_lag(lead))

		_draw_sprite(enemy["key"], at.x, at.y, enemy["flash"])
		flash_drawn(enemy)

	for item in effects:
		if item["dead"]:
			continue

		if smoothing:
			match item["kind"]:
				"enemy_bullet":
					world.draw_set_transform(_lag(item, true, true))
				"flame":
					world.draw_set_transform(_lag(item, true, false))
				"gun":
					world.draw_set_transform(_scroll_lag())
				_:
					world.draw_set_transform(_lag(item))

		match item["kind"]:
			"gun":

				# code 0x91f : skipped unless its top left is inside the play area

				var gx: int = item["x"] - item["hot"].x
				var gy: int = item["y"] - item["hot"].y

				if gx >= 0 and gx < 320 and gy >= 0 and gy < PLAY_HEIGHT:
					world.draw_texture(item["texture"], Vector2(gx, gy))
			"enemy_bullet":
				_draw_sprite(item["key"], item["x"] >> 16, item["y"] >> 16, false)
			"wall_pod":
				_draw_sprite(item["key"], item["x"], item["y"], false)
			"shell":
				_draw_sprite(SHELL_FRAMES[item["anim"]][0], item["x"], item["y"], false)
			"companion":
				if item["visible"]:
					_draw_sprite(COMPANION_FRAMES[item["anim"]][0], item["x"], item["y"], false)
			"explosion":
				_draw_sprite("X2SPR/%03d" % item["frames"][item["index"]], item["x"], item["y"], false)
			"bonus", "item":
				_draw_sprite(_bonus_key(item), item["x"], item["y"], false)
			"mine", "missile", "bomb", "homing":
				_draw_sprite(item["frames"][item["anim"]][0], item["x"], item["y"], false)
			"hole_debris":
				_draw_sprite(item["frames"][item["anim"]][0], item["x"], item["y"], false)
			"shield":
				if item["visible"]:
					_draw_sprite(SHIELD_FRAMES[item["anim"]][0], item["x"], item["y"], false)
			"flame":
				_draw_sprite(FLAMER_FLAME_FRAMES[item["anim"]][0], item["x"] >> 16, item["y"], false)
			"beam":
				_draw_beam(item)
			"l2_debris", "l2_pod":
				level2.draw_effect(item)
			"l4_capsule":
				level4.draw_effect(item)
			"l5_laser":
				level5.draw_effect(item)

	# code 0x36d0 : the list ds:0x90e2 is drawn last (level 3's holes)

	if smoothing:
		world.draw_set_transform(_scroll_lag())

	if level3 != null:
		level3.draw_overlay()

	if level4 != null:
		level4.draw_tile_objects()

	if smoothing:
		world.draw_set_transform(Vector2.ZERO)


func _draw_beam(beam: Dictionary) -> void:

	# code f29:1478 (stub 0xab7) : skipped unless x + 4 - 2 * level is between -16 and 320.
	# Once free the tail at (x, y + 1), then the head at the top, then the column from y up
	# for the length, in colour 7, a byte at a time and only for bytes inside the screen.

	var level: int = beam["level"]
	var x: int = beam["x"] + 4 - 2 * level
	var y: int = beam["y"]
	var length: int = beam["length"]

	if x <= -0x10 or x >= 0x140:
		return

	if length >= 0x41:
		_draw_sprite(BEAM_TAILS[level], x, y + 1, false)

	_draw_sprite(BEAM_HEADS[level], x, y - length, false)

	if y < 0 or length <= 0:
		return

	var top := maxi(y - length + 1, 0)
	var mask: int = BEAM_MASKS[level]

	for i in 16:
		if (mask >> (15 - i)) & 1 == 0:
			continue

		var px := x + i
		var byte_x := (x & ~7) + (((x & 7) + i) >> 3) * 8

		if byte_x < 0 or byte_x >= 0x140:
			continue

		world.draw_rect(Rect2(px, top, 1, y - top + 1), COLOUR_7)


func _draw_overlay() -> void:

	# code 0x465c : the gauge, then (0xa95) the drone shots, 2 by 2 in colour 7 (one pixel
	# wide in the last column of a byte)

	# the shades gauge as in the PC game, also with the Amiga graphics (the Amiga game draws
	# none, $6396, the remake keeps the PC's)

	if shades_gauge >= 0:
		var key := "X2SPR/%03d" % shades_gauge
		var h: Array = headers[key]
		overlay.draw_texture(_texture(key), Vector2(0x126 - h[4], 8 - h[5]))

	if shield_gauge >= 0:
		var key := "X2SPR/%03d" % shield_gauge
		var h: Array = headers[key]
		overlay.draw_texture(_texture(key), Vector2(4 - h[4], 0xa0 - h[5]))

	if dive_gauge >= 0:
		var key := "X2SPR/%03d" % dive_gauge
		var h: Array = headers[key]
		overlay.draw_texture(_texture(key), Vector2(0x98 - h[4], 8 - h[5]))

	if gauge_frame >= 0:
		var key := "X2SPR/%03d" % gauge_frame
		var h: Array = headers[key]
		overlay.draw_texture(_texture(key), Vector2(0x98 - h[4], 0xa0 - h[5]))

	for dot in spark_dots:
		var width := 1 if dot.x & 7 == 7 else 2
		overlay.draw_rect(Rect2(dot.x, dot.y, width, 2), COLOUR_7)


func _draw_stars() -> void:
	for i in STAR_COUNT:
		var star: Dictionary = stars[i]
		var lag := _lag(star) if smooth_alpha < 1.0 else Vector2.ZERO
		star_layer.draw_rect(Rect2(Vector2(star["x"], star["y"]) + lag, Vector2(1, 1)), STAR_COLOURS[i / 16])


func _draw_hud() -> void:

	# each player's slot (ds:0x8e7a picks it) : score at x 24 or 240, lives at x 136 or
	# 176, energy bar from x 91 or 190. The stored player's figures stay as last drawn. Code
	# 0x16a9 : player 2 is drawn as seven zeros at game start, and with one player his lives
	# as 0 (0x18ad).

	var other := 1 - current
	var other_digits: Array = stored.get("score_digits", [0, 0, 0, 0, 0, 0, 0])
	var other_lives: int = stored.get("lives", 0) if player_count == 2 else 0

	for i in 7:
		hud_values.draw_texture(digit_textures[score_digits[i]], Vector2(SCORE_X[current] + i * 8, SCORE_Y))
		hud_values.draw_texture(digit_textures[other_digits[i]], Vector2(SCORE_X[other] + i * 8, SCORE_Y))

	# code 0x108f9 : lives above 9 are shown as 9

	hud_values.draw_texture(digit_textures[10 + mini(lives, 9)], LIVES_POSITIONS[current])
	hud_values.draw_texture(digit_textures[10 + mini(other_lives, 9)], LIVES_POSITIONS[other])

	# code 0x10ad0 : the bar is 39 pixels, colour 14 up to the energy, colour 0 after it.
	# Player 2's bar only once he plays.

	_draw_energy(ENERGY_POSITIONS[current], energy)

	if player_count == 2:
		_draw_energy(ENERGY_POSITIONS[other], stored.get("energy", ENERGY_WIDTH))


func _draw_energy(position: Vector2, value: int) -> void:
	var filled := clampi(value, 0, ENERGY_WIDTH)
	hud_values.draw_rect(Rect2(position, Vector2(filled, ENERGY_ROWS)), ENERGY_COLOUR)
	hud_values.draw_rect(Rect2(position + Vector2(filled, 0), Vector2(ENERGY_WIDTH - filled, ENERGY_ROWS)), Color.BLACK)


func _save_shot() -> void:
	if wav_path != "":
		if use_amiga:
			amiga_sound.save_wav(wav_path, amiga_music.recording if amiga_music != null else PackedFloat32Array())
		else:
			sound.save_wav(wav_path)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_path)
	get_tree().quit()
