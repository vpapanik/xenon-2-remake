class_name TitleScreen
extends Node2D

# Port of the title sequence of XENON2.EXE : the credits (0x5863), the high score page
# (0x59aa), the menu (0x5b21), the loading message (0x5b10) and GET READY (0x5926), with
# the EGA and VGA drawing of segment 0xf29 : the logo (f29:1f3c), the large and medium fonts
# (f29:16fc, f29:17b7, glyphs looked up in ds:0x33ca, others left blank) and the title stars
# (f29:0202). Every frame is cleared and drawn whole, then shown at the next game tick
# (0xa51), so one picture is enough. The palette is ds:0x427d (0xde7), the shop's.
#
# The remake adds two lines to the menu : the sound (PC speaker or Amiga) and the graphics
# (PC, or Amiga with its background picture).

signal ticked

const LARGE_ROWS := 22
const MEDIUM_ROWS := 14
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ.:><0123456789"

# ds:0x3625 : six pages of two lines

const CREDITS := [
	["    DESIGNED BY     ", "THE BITMAP BROTHERS "],
	["    PROGRAMMING     ", " THE ASSEMBLY LINE  "],
	["      GRAPHICS      ", "    MARK COLEMAN    "],
	["       MUSIC        ", "   BOMB THE BASS    "],
	[" MUSIC PROGRAMMING  ", "  DAVID WHITTAKER   "],
	["         FX         ", "  DAVID WHITTAKER   "],
]

# ds:0x3477 on : the menu lines, plain and chosen

const SELECT := "       SELECT       "
const ONE_PLAYER := ["   1 PLAYER GAME    ", " > 1 PLAYER GAME <  "]
const TWO_PLAYER := ["   2 PLAYER GAME    ", " > 2 PLAYER GAME <  "]
const MUSIC_ON := ["     MUSIC  ON      ", "   > MUSIC  ON <    "]
const MUSIC_OFF := ["     MUSIC OFF      ", "   > MUSIC OFF <    "]
const HIGH_SCORE := "     HIGH SCORE     "
const LOADING := "   LOADING LEVEL 1  "
const GET_READY := " GET READY PLAYER 1 "
const CONTINUE := "   CONTINUE GAME    "
const GAME_OVER := "     GAME OVER      "

# remake : the sound and graphics lines, in the same style

const SOUND_PC := ["     SOUND  PC      ", "   > SOUND  PC <    "]
const SOUND_AMIGA := ["    SOUND AMIGA     ", "  > SOUND AMIGA <   "]
# remake : the opening screen, before the original title : ORIGINAL or ENHANCED (the
# xBRZ graphics drawn at the window's resolution, main.gd _set_enhanced ; F1 switches too)

const INTRO_BY := "REMAKE BY VPAPANIK"
const INTRO_HOLD := 9
const INTRO_FADE := 13
const INTRO_ORIGINAL := ["  ORIGINAL 1989  ", "> ORIGINAL 1989 <"]
const INTRO_ENHANCED := ["  ENHANCED 2026  ", "> ENHANCED 2026 <"]
const GRAPHICS_PC :=["    GRAPHICS  PC    ", "  > GRAPHICS  PC <  "]
const GRAPHICS_AMIGA := ["   GRAPHICS AMIGA   ", " > GRAPHICS AMIGA < "]

# ds:0x373d : star colours by bits 10 to 12 of the depth

const STAR_COLOURS := [7, 7, 7, 5, 5, 5, 4, 4]

var main: Node
var picture: Image
var texture: ImageTexture
var view: Sprite2D

# ENHANCED : the picture's xBRZ twin (hd_mirror.gd) and its texture

const HD_MIRROR = preload("res://scripts/hd_mirror.gd")

var hd = HD_MIRROR.new()
var large_texture: ImageTexture
var logo: Image
var large: Array[Image] = []
var medium: Array[Image] = []
var digits: Array[Image] = []
var colours: Array[Color] = []
var stars: Array = []
var running := false
var ticks := 0
var credits := 3
var item := 0

# ds:0x3567 and ds:0x358f : the ten best scores and their lines, kept from game to game

static var scores: Array = []
static var lines: Array = []

# the Amiga title (game $8236), from data/amiga_title.json and assets/amiga/title_*.png

var amiga_logo: Image
var logo_overlay: Sprite2D
var overlay_size := 0.0
var amiga_large: Image
var amiga_small: Image
var amiga_large_letters := ""
var amiga_small_letters := ""
var amiga_colours: Array[Color] = []
var amiga_star_colours: Array = []

# $8724 : the zoom masks by size 0 to 16, a set bit keeps a pixel column or row (the high
# bit first, the mask turning round every 16)

const ZOOM_MASKS := [0x0000, 0x0100, 0x1010, 0x2104, 0x4444, 0x4912, 0x5252, 0x552a, 0xaaaa,
	0xab55, 0xb5b5, 0xb76d, 0xdddd, 0xddf7, 0xbf7f, 0x7ff7, 0xffff]

# $833a : the sizes of the credit lines a frame, -1 ending a part : the first line comes,
# then the second comes, stays and goes, then the first goes

const CREDIT_ZOOMS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 16, 16, 16, 16, -1,
	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16,
	16, 16, 16, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 0, 0, 0, 0, -1,
	15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, -1]

# $8bd6 and $8bf8 : HIGH SCORE coming and going

const TABLE_IN := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, -1]
const TABLE_OUT := [16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, -1]


func _ready() -> void:
	for c in main.shop.data["palette"]:
		colours.append(Color8(c[0], c[1], c[2]))

	picture = Image.create(320, 200, false, Image.FORMAT_RGBA8)
	picture.fill(colours[0])
	hd.target(picture)
	texture = ImageTexture.create_from_image(picture)
	view = Sprite2D.new()
	var shown: Dictionary = hd.view(picture, texture)
	large_texture = shown["large"]
	view.texture = shown["texture"]
	view.centered = false
	add_child(view)
	visible = false
	logo = _load("res://assets/gr/title_logo.png")

	for i in 40:
		large.append(_load("res://assets/gr/font_large/%02d.png" % i))

	for i in 42:
		medium.append(_load("res://assets/gr/font_medium/%02d.png" % i))

	for i in 10:
		digits.append(_load("res://assets/gr/hud_digits/%02d.png" % i))

	_load_amiga()

	# ds:0x358f : the high score table at the start

	if lines.is_empty():
		for i in 10:
			scores.append(0)
			lines.append("%2d_ 0000000 :::" % (i + 1))


func _load(path: String) -> Image:
	var image: Image = load(path).get_image()
	image.convert(Image.FORMAT_RGBA8)
	return hd.source(image, path)


func tick() -> void:
	ticks += 1
	ticked.emit()


func _frame() -> void:

	# 0xa51 : the picture is shown at the next tick

	while ticks == 0:
		await ticked

	ticks = 0
	texture.update(picture)
	hd.show(large_texture, picture)

	# the smooth logo of ENHANCED changes with the picture it goes with

	if logo_overlay != null:
		var t := overlay_size
		var smooth := t * t * (3.0 - 2.0 * t)
		logo_overlay.position = Vector2(160, 100).lerp(Vector2(48 + 104, 20 + 27), smooth)
		logo_overlay.scale = Vector2(smooth, smooth)
		logo_overlay.modulate = Color(1, 1, 1, t)
		logo_overlay.visible = t > 0.0


# ---------------------------------------------------------------- the sequence

func open() -> void:
	running = true
	visible = true
	ticks = 0
	_run()


func loading(level: int) -> void:

	# code 0x4146 and 0x5cd4 : the next level, LOADING LEVEL n for one frame (stars renewed
	# first, 0x5935), then play goes on

	running = true
	visible = true
	ticks = 0
	_new_stars()
	await _show_once(0xc, LOADING.replace("1", str(level)))
	running = false
	visible = false
	main._level_loaded()


func _get_ready_text() -> String:

	# code 0x19f2 : the digit is '1' + ds:0x8e7a, written at ds:0x3727

	return GET_READY.replace("1", str(main.current + 1))


func get_ready() -> void:

	# code 0x19f2 : after a lost life, a continue or a new level, GET READY PLAYER 1 until
	# fire (0x5926 with ds:0x374e set : the title stars renewed, 0x5935), then play goes on

	running = true
	visible = true
	ticks = 0
	_new_stars()

	# 0x596e : a fire press still pending (ds:0x8f5b) ends it at once, as in the original

	while true:
		_clear()
		_text(0x64, _get_ready_text(), large, LARGE_ROWS)
		_stars()
		await _frame()

		if main.fire_event:
			main.fire_event = false
			break

	running = false
	visible = false
	main._get_ready_done()


func _run() -> void:
	if not main.intro_seen:
		await _intro()

	if main.use_amiga_gfx and amiga_logo != null:
		await _amiga_credits()
	else:
		await _credits()

	await _menu()

	# code 0x5c09 : 1 or 2 players by the item chosen

	main.start_players(item + 1)

	# 0x5cd4 : LOADING LEVEL 1 for one frame (stars renewed first, 0x5935)

	_new_stars()
	await _show_once(0xc, LOADING)

	# 0x3cdc : GET READY until fire (0x5926, ds:0x374e set)

	_new_stars()

	while true:
		_clear()
		_text(0x64, _get_ready_text(), large, LARGE_ROWS)
		_stars()
		await _frame()

		if main.fire_event:
			main.fire_event = false
			break

	running = false
	visible = false
	main._title_done()


func _credits() -> void:

	# 0x5863 : the title tune, new stars, then the credit pages : the first line from
	# frame 18, the second from frame 36 to 53, 72 frames a page. After the last page the
	# high score page. Fire ends it, the sound stops.

	main._title_tune()
	_new_stars()

	while not main.fire_event:
		var page := 0

		while page < CREDITS.size() and not main.fire_event:
			var count := 0

			while count < 0x48:
				_clear()
				hd.blit_rect(picture, logo, Rect2i(Vector2i.ZERO, logo.get_size()), Vector2i(48, 48))

				if count >= 0x12:
					_text(0x78, CREDITS[page][0], large, LARGE_ROWS)

					if count >= 0x24 and count < 0x36:
						_text(0x96, CREDITS[page][1], large, LARGE_ROWS)

				_stars()

				if main.fire_event:
					break

				await _frame()
				count += 1

			page += 1

		if main.fire_event:
			break

		# 0x59aa : the heading for a frame, then the table for 85 frames

		await _show_once(0xc, HIGH_SCORE)

		for i in 0x55:
			_clear()
			_text(0xc, HIGH_SCORE, large, LARGE_ROWS)

			for k in 10:
				_text_at(32, 38 + 16 * k, lines[k], medium, MEDIUM_ROWS)

			_stars()
			await _frame()

			if main.fire_event:
				break

	main.fire_event = false
	main._stop_sound()


func _show_once(y: int, line: String) -> void:

	# 0x595d with ds:0x374e clear : one frame of the line and the stars

	_clear()
	_text(y, line, large, LARGE_ROWS)
	_stars()
	await _frame()


func _customise_keys() -> void:

	# code 0x66e : asks for up, down, left, right ("Press key to move"), fire and dive ("Press
	# key to make ship"), one key each, kept until the program ends

	var asks := [["up", "MOVE UP"], ["down", "MOVE DOWN"], ["left", "MOVE LEFT"], ["right", "MOVE RIGHT"], ["fire", "FIRE"], ["dive", "DIVE"]]
	var chosen := {}

	for ask in asks:
		main.any_key = false

		while true:
			_clear()
			_text(0x3c, "     PRESS KEY      ", large, LARGE_ROWS)
			_text(0x54, ("TO " + ask[1]).lpad(10 + (3 + ask[1].length()) / 2).rpad(20), large, LARGE_ROWS)
			_stars()
			await _frame()

			if main.any_key:
				break

		chosen[ask[0]] = main.last_key
		main._menu_sound(9, 0xd)

	main.custom_keys = chosen
	main.any_key = false
	main.fire_event = false


func _menu() -> void:

	# 0x5b21 : 3 credits, new stars, SELECT for a frame, then the lines with the chosen
	# one marked, CREDITS at the bottom. Up and down move (effect 8, the Amiga game's $c),
	# fire (effect 9, $d) switches music on the music line or starts the game on the
	# others, with 1 or 2 players by the line (0x5c09, main.start_players).

	credits = 3

	_new_stars()
	await _show_once(0xc, SELECT)
	main.fire_event = false
	main.any_key = false
	item = 0
	var held := 0

	while true:
		_clear()
		_text(0xc, SELECT, large, LARGE_ROWS)
		_text(0x3c, ONE_PLAYER[1 if item == 0 else 0], large, LARGE_ROWS)
		_text(0x54, TWO_PLAYER[1 if item == 1 else 0], large, LARGE_ROWS)
		var music: Array = MUSIC_ON if main.music_on else MUSIC_OFF
		_text(0x6c, music[1 if item == 2 else 0], large, LARGE_ROWS)
		var sound: Array = SOUND_AMIGA if main.use_amiga else SOUND_PC
		_text(0x84, sound[1 if item == 3 else 0], large, LARGE_ROWS)
		var graphics: Array = GRAPHICS_AMIGA if main.use_amiga_gfx else GRAPHICS_PC
		_text(0x9c, graphics[1 if item == 4 else 0], large, LARGE_ROWS)

		# 0x5c7c : CREDITS and their number, medium font

		_text_at(176, 184, "CREDITS %d" % credits, medium, MEDIUM_ROWS)

		# remake : K opens Customise keys (the original's sixth line of its display mode
		# menu, 0x66e)

		_text_at(8, 184, "K KEYS", medium, MEDIUM_ROWS)

		_stars()
		await _frame()

		# the keyboard handler sets a direction bit on each key press, the menu clears it
		# after use (0x5ba8), so a held key moves once

		var dirs := 0

		if main.held_up:
			dirs |= 1

		if main.held_down:
			dirs |= 2

		var pressed := dirs & ~held
		held = dirs

		if main.any_key and main.last_key == KEY_K:
			main.any_key = false
			await _customise_keys()
			held = 3
			continue

		if pressed & 1:
			main._menu_sound(8, 0xc)
			item -= 1

			if item < 0:
				item = 4

			continue

		if pressed & 2:
			main._menu_sound(8, 0xc)
			item += 1

			if item > 4:
				item = 0

			continue

		if not main.fire_event:
			continue

		main.fire_event = false
		main._menu_sound(9, 0xd)

		if item == 2:
			main.music_on = not main.music_on
			continue

		if item == 3:
			main._switch_sound(not main.use_amiga)
			continue

		if item == 4:
			main._switch_graphics(not main.use_amiga_gfx)
			continue

		return


# ---------------------------------------------------------------- drawing

func _clear() -> void:

	# f29:12fd

	hd.fill(picture, colours[0])

	# ENHANCED : no smooth Amiga logo left over (fire on the Amiga credits shrinks it, then
	# the menu clears with this one)

	overlay_size = 0.0


func _text(y: int, line: String, font: Array[Image], rows: int) -> void:

	# f29:16fc : 20 characters from x 0 at line y. ENHANCED : the line without its spaces
	# around, centred to the pixel.

	if main.HD_TEXTURE.on:
		line = line.strip_edges()
		_text_at((320 - 16 * line.length()) / 2, y, line, font, rows)
		return

	_text_at(0, y, line, font, rows)


func _text_at(x: int, y: int, line: String, font: Array[Image], rows: int, letters := LETTERS) -> void:

	# f29:17b7 : one 16 pixel glyph a character, opaque. A character not in ds:0x33ca is
	# skipped.

	for i in line.length():
		var index := letters.find(line[i])

		if index < 0 or index >= font.size():
			continue

		hd.blit_rect(picture, font[index], Rect2i(0, 0, 16, rows), Vector2i(x + 16 * i, y))


func _new_stars() -> void:

	# 0x5935 : 48 stars, x, y and depth (& 0x1fff) from the generator

	stars.clear()

	for i in 48:
		var x: int = main._random()
		var y: int = main._random()
		var z: int = main._random() & 0x1fff
		stars.append([x, y, z])


func _signed(v: int) -> int:
	return v - 0x10000 if v & 0x8000 else v


func _stars() -> void:

	# f29:0202 : each star comes 0x200 nearer. Too near, or projected off the screen, it
	# starts again at random. Projection : x * 16 / depth + 160, y * 16 / depth + 100. It is
	# drawn only on colour 0, else bit 15 of its depth is set.

	var black := colours[0]

	for star in stars:
		var z: int = (star[2] & 0x7fff) - 0x200
		var sx := 0
		var sy := 0

		while true:
			if z <= 0x200:
				while true:
					star[0] = main._random()
					star[1] = main._random()
					z = main._random() & 0x1fff

					if z > 0x200:
						break

			star[2] = z
			sx = (_signed(star[0]) * 16) / z + 0xa0

			if sx < 0 or sx >= 0x140:
				z = 0
				continue

			sy = (_signed(star[1]) * 16) / z + 0x64

			if sy < 0 or sy >= 0xc8:
				z = 0
				continue

			break

		if picture.get_pixel(sx, sy) == black:
			hd.set_pixel(picture, sx, sy, colours[STAR_COLOURS[(z >> 10) & 7]])
		else:
			star[2] = z | 0x8000


# ---------------------------------------------------------------- the end of a game

func game_over() -> void:

	# code 0x3f30 : no lives left

	running = true
	visible = true
	ticks = 0
	_game_over()


func _game_over() -> void:
	await _high_score()

	# code 0x3f40 : a credit less, the continue screen while some are left

	credits -= 1

	if credits != 0 and await _continue():
		running = false
		visible = false
		main._continue_game()
		return

	# code 0x3f7b : GAME OVER for 30 frames, then the title again

	_new_stars()

	for i in 0x1e:
		_clear()
		_text(0x64, GAME_OVER, large, LARGE_ROWS)
		_stars()
		await _frame()

	main._init_stars()
	running = false
	visible = false
	main._player_out()


func _table_frame() -> void:

	# f29:1759 (stub 0xb3f) : the high score page, one frame

	_clear()
	_text(0xc, HIGH_SCORE, large, LARGE_ROWS)

	for k in 10:
		_text_at(32, 38 + 16 * k, lines[k], medium, MEDIUM_ROWS)

	_stars()
	await _frame()


func _high_score() -> void:

	# code 0x59c8 : a score above the tenth (high words signed, low words compared signed
	# too, as the code does) goes into the table, the lower ones move down keeping their
	# ranks, then three initials are chosen

	var score: int = main.score
	var high := score >> 16
	var low := score & 0xffff
	var last: int = scores[9]

	if high < (last >> 16) or (high == (last >> 16) and _signed(low) <= _signed(last & 0xffff)):
		return

	_new_stars()
	await _show_once(0xc, HIGH_SCORE)
	var place := 9

	while place > 0:
		var above: int = scores[place - 1]

		if high < (above >> 16) or (high == (above >> 16) and low <= (above & 0xffff)):
			break

		scores[place] = above
		lines[place] = lines[place].substr(0, 4) + lines[place - 1].substr(4)
		place -= 1

	scores[place] = score
	lines[place] = lines[place].substr(0, 4) + "%07d :::" % (score % 10000000)

	# code 0x5a7c : each initial from the letters of ds:0x33ca. Left and right change it at
	# once, then every 4 frames while held, fire takes it and the next starts from the same
	# letter.

	main.fire_event = false
	var letter := 0

	for initial in 3:
		var at := 12 + initial
		_put(place, at, LETTERS[letter])
		var chosen := false

		while not chosen:
			await _table_frame()

			if main.fire_event:
				break

			var dirs := _sideways()

			if dirs == 0:
				continue

			var step := -1 if dirs & 4 else 1

			while true:
				letter += step

				if letter < 0:
					letter = 0x27

				if letter >= 0x28:
					letter = 0

				_put(place, at, LETTERS[letter])
				var same := true

				for i in 4:
					await _table_frame()

					if main.fire_event:
						chosen = true
						break

					if _sideways() != dirs:
						same = false
						break

				if chosen or not same:
					break

		main.fire_event = false

	for i in 0x12:
		await _table_frame()

	main._init_stars()


func _sideways() -> int:
	var dirs := 0

	if main.held_left:
		dirs |= 4

	if main.held_right:
		dirs |= 8

	return dirs


func _put(place: int, at: int, ch: String) -> void:
	var line: String = lines[place]
	lines[place] = line.substr(0, at) + ch + line.substr(at + 1)


func _continue() -> bool:

	# code 0x5c0f : CONTINUE GAME and a count from 9 to 0, a step every 8 frames. Fire goes
	# on, the end of the count does not.

	_new_stars()
	await _show_once(0x50, CONTINUE)
	main.fire_event = false

	# ENHANCED : the count in seconds, each number one second (10 s in all, the original's
	# about 4.3 s)

	var enhanced: bool = main.HD_TEXTURE.on
	var ticks := ceili(10.0 / main.TICK_SECONDS) if enhanced else 0x4f

	for i in ticks:
		var count := 0x4f - i
		var number := count >> 3

		if enhanced:
			number = 9 - int(i * main.TICK_SECONDS)

		_clear()
		_text(0x50, CONTINUE, large, LARGE_ROWS)
		_text(0x78, "         %d          " % number, large, LARGE_ROWS)
		_text_at(176, 184, "CREDITS %d" % credits, medium, MEDIUM_ROWS)
		_stars()
		await _frame()

		if main.fire_event:
			main.fire_event = false
			main._init_stars()
			return true

	main._init_stars()
	return false

# ---------------------------------------------------------------- remake : opening screen

func _intro() -> void:

	# not in XENON2.EXE : the remake's title and the choice of version, drawn as the
	# original menu (large font, title stars). Up and down choose (the current version
	# first), fire or Enter starts it, and the picture changes at once.

	main.intro_seen = true
	_new_stars()
	main.fire_event = false
	main.enter_event = false
	var item := 1 if main.HD_TEXTURE.on else 0
	var held := 3

	while true:
		_intro_screen(item)
		await _frame()

		var dirs := 0

		if main.held_up:
			dirs |= 1

		if main.held_down:
			dirs |= 2

		var pressed := dirs & ~held
		held = dirs

		# the PC speaker's menu sounds (effects 8 and 9) whatever the sound setting

		if pressed & 3:
			main.pc_request = 8
			item = 1 - item
			main._set_enhanced(item == 1)
			continue

		if main.fire_event or main.enter_event:
			main.fire_event = false
			main.enter_event = false
			main.pc_request = 9

			# a short pause so the sound plays out (about 0.5 s), then the screen fades to
			# black (about 0.7 s) before the title and its music

			for i in INTRO_HOLD + INTRO_FADE:
				_intro_screen(item)
				var v := 1.0 - clampf(float(i - INTRO_HOLD + 1) / INTRO_FADE, 0.0, 1.0)
				view.modulate = Color(v, v, v)
				await _frame()

			_clear()
			await _frame()
			view.modulate = Color.WHITE
			return


func _intro_screen(item: int) -> void:
	_clear()
	_intro_logo()
	_centred(0x58, INTRO_BY, large)
	_centred(0x80, INTRO_ORIGINAL[1 if item == 0 else 0], large)
	_centred(0x98, INTRO_ENHANCED[1 if item == 1 else 0], large)

	_version()
	_stars()


func _version() -> void:

	# the remake's version (project.godot, set from the release tag by the CI) small at the
	# lower right : the score digits of the HUD (8 x 8), a dot of two pixels between them

	var version := String(ProjectSettings.get_setting("application/config/version", ""))
	var width := 0

	for c in version:
		width += 3 if c == "." else 8

	var x := 320 - 4 - width
	var y := 200 - 4 - 8

	for c in version:
		if c == ".":
			hd.fill_rect(picture, Rect2i(x, y + 6, 2, 2), digits[0].get_pixel(1, 6))
			x += 3
		elif c >= "0" and c <= "9":
			hd.blit_rect(picture, digits[int(c)], Rect2i(0, 0, 8, 8), Vector2i(x, y))
			x += 8


func _intro_logo() -> void:

	# the title logo of the graphics chosen (both 208 x 54, the same pixels), centred on
	# its drawn part, its top at line 20 as on the Amiga title

	if main.use_amiga_gfx and amiga_logo != null:
		hd.blend_rect(picture, amiga_logo, Rect2i(Vector2i.ZERO, amiga_logo.get_size()), Vector2i(52, 20))
	else:
		hd.blit_rect(picture, logo, Rect2i(Vector2i.ZERO, logo.get_size()), Vector2i(56, 20))

func _centred(y: int, line: String, font: Array[Image]) -> void:

	# remake : centred to the pixel, which the original's 16 pixel text positions cannot do

	_text_at((320 - 16 * line.length()) / 2, y, line, font, LARGE_ROWS)

# ---------------------------------------------------------------- the Amiga title

func _load_amiga() -> void:
	if not FileAccess.file_exists("res://data/amiga_title.json"):
		return

	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/amiga_title.json"))

	for c in data["palette"]:
		amiga_colours.append(Color8(int(c[0]), int(c[1]), int(c[2])))

	amiga_star_colours = data["star_colours"]
	amiga_large_letters = data["large"]
	amiga_small_letters = data["small"]
	amiga_large = _load("res://assets/amiga/title_large.png")
	amiga_small = _load("res://assets/amiga/title_small.png")
	amiga_logo = _load("res://assets/amiga/title_logo.png")

	# ENHANCED : the smooth logo of the zoom, made here hidden (made at its first use it
	# showed for a frame at the top left and held the title up while loading)

	logo_overlay = Sprite2D.new()
	logo_overlay.texture = main._gfx("res://assets/amiga/title_logo.png")
	logo_overlay.visible = false
	add_child(logo_overlay)


func _amiga_credits() -> void:

	# game $8236 : the title tune, new stars, the logo coming ($8190), then the credit pages
	# ($8746, the PC's six pages : this Amiga disk has the cracker's page first, the remake
	# keeps THE BITMAP BROTHERS), each line coming and going by the sizes of $833a. After the
	# last page the logo goes ($81ea), the high score page ($89dc), the logo comes again.
	# Fire stops the tune and, in the pages, lets the logo go first ($866e).

	main._title_tune()
	_new_stars()

	if await _amiga_logo_in():
		return _amiga_end()

	var page := 0
	var index := 0
	var state := 0

	while true:
		_amiga_clear()
		hd.blend_rect(picture, amiga_logo, Rect2i(Vector2i.ZERO, amiga_logo.get_size()), Vector2i(48, 20))
		var last := false

		# $82ae : without a frame of its own, an ended part goes on to the next

		while true:
			var texty := 0x78

			if state == 1:
				_amiga_full(0x78, CREDITS[page][0])
				texty = 0x96

			var size: int = CREDIT_ZOOMS[index]
			index += 1

			if size > 0:
				_amiga_zoom(texty, CREDITS[page][1 if state == 1 else 0], size)
				break

			if size == 0:
				break

			state += 1

			if state != 3:
				continue

			state = 0
			index = 0
			page += 1

			if page == CREDITS.size():
				last = true
				break

		if last:
			if await _amiga_logo_out():
				return _amiga_end()

			if await _amiga_high_score():
				return _amiga_end()

			if await _amiga_logo_in():
				return _amiga_end()

			page = 0
			continue

		# $840e : the stars, then fire before the frame is shown

		_amiga_stars()

		if main.fire_event:
			main.fire_event = false
			main._stop_sound()
			await _amiga_logo_out()
			return _amiga_end()

		await _frame()


func _amiga_end() -> void:

	# $8680 : the tune stopped, fire forgotten

	main.fire_event = false
	main._stop_sound()


func _amiga_logo_in() -> bool:

	# $8190 : 34 frames of stars, then the logo from size 1 to 15 about the middle
	# ($8092). Fire ends it (true).

	for i in 0x22:
		_amiga_clear()
		_amiga_stars()
		await _frame()

		if main.fire_event:
			return true

	for size in range(1, 16):
		if main.fire_event:
			return true

		_amiga_clear()
		_amiga_logo_zoom(size)
		_amiga_stars()
		await _frame()

	return false


func _amiga_logo_out() -> bool:

	# $81ea : the logo from size 16 down to 1. Fire ends it (true).

	for size in range(16, 0, -1):
		if main.fire_event:
			return true

		_amiga_clear()
		_amiga_logo_zoom(size)
		_amiga_stars()
		await _frame()

	return false


func _amiga_high_score() -> bool:

	# $89dc : HIGH SCORE comes from the middle to line 12 ($84ae, no fire there), the page
	# for 85 frames ($8b20), then it goes unless fire was pressed. The remake shows its own
	# table (the scores of this game), in the Amiga style "NN. SCORE ABC".

	await _amiga_heading(TABLE_IN)

	for i in 0x55:
		_amiga_clear()
		_amiga_full(0xc, HIGH_SCORE)

		for k in 10:
			_amiga_small_text(32, 38 + 16 * k, lines[k].replace("_", "."))

		_amiga_stars()
		await _frame()

		if main.fire_event:
			return true

	await _amiga_heading(TABLE_OUT)
	return main.fire_event


func _amiga_heading(sizes: Array) -> void:

	# $84ae : the line drawn at a size a frame, its line from 100 at size 0 to its own at 16

	for size in sizes:
		if size < 0:
			return

		_amiga_clear()

		if size > 0:
			_amiga_zoom(floori((0xc - 0x64) * size / 16.0) + 0x64, HIGH_SCORE, size)

		_amiga_stars()
		await _frame()


func _amiga_clear() -> void:

	# $7eb6

	hd.fill(picture, amiga_colours[0])

	overlay_size = 0.0


func _amiga_full(texty: int, line: String) -> void:

	# $7f12 : 20 characters of the large font from x 0, 8 lines above texty. A character not
	# in $86d2 is skipped. ENHANCED : centred to the pixel, as _text.

	var x0 := 0

	if main.HD_TEXTURE.on:
		line = line.strip_edges()
		x0 = (320 - 16 * line.length()) / 2

	for i in line.length():
		var index := amiga_large_letters.find(line[i])

		if index >= 0:
			hd.blend_rect(picture, amiga_large, Rect2i(16 * index, 0, 16, LARGE_ROWS), Vector2i(x0 + 16 * i, texty - 8))


func _amiga_zoom(texty: int, line: String, size: int) -> void:

	# $7f64 : below size 16, each character keeps the columns and rows of the zoom mask
	# (the rows mask going on from row to row), so it is size pixels wide. The line is
	# centred on x 160, its top size / 2 above texty.

	if size >= 16:
		_amiga_full(texty, line)
		return

	var mask: int = ZOOM_MASKS[size]
	var top := (2 * texty - size) >> 1
	var x := 0xa0 - 10 * size

	if main.HD_TEXTURE.on:
		line = line.strip_edges()
		x = 0xa0 - (line.length() * size) / 2

	for i in line.length():
		var index := amiga_large_letters.find(line[i])

		if index >= 0:
			var y := top

			for r in LARGE_ROWS:
				if mask & (0x8000 >> (r & 15)) == 0:
					continue

				var kx := x

				for b in 16:
					if mask & (0x8000 >> b) == 0:
						continue

					var c := amiga_large.get_pixel(16 * index + b, r)

					if c.a > 0 and kx >= 0 and kx < 320 and y >= 0 and y < 200:
						hd.set_pixel(picture, kx, y, c)

					kx += 1

				y += 1

		x += size


func _amiga_logo_zoom(size: int) -> void:

	# $8092 : the logo (208 x 54) with the columns and rows of the zoom mask, from
	# (160 - 7 size, 100 - 5 size), so it grows from the middle to (48, 20). Its last step
	# (size 15 at x 55) jumps to the full logo at x 48.
	# ENHANCED : the high resolution logo scaled and faded in smoothly from the middle,
	# ending exactly on the full logo's place (48, 20), sizes 1 to 15 as 1/15 to 1.

	if main.HD_TEXTURE.on and logo_overlay != null:
		overlay_size = minf(size / 15.0, 1.0)
		return

	var mask: int = ZOOM_MASKS[size]
	var y := 100 - 5 * size

	for r in amiga_logo.get_height():
		if mask & (0x8000 >> (r & 15)) == 0:
			continue

		var kx := 160 - 7 * size

		for b in amiga_logo.get_width():
			if mask & (0x8000 >> (b & 15)) == 0:
				continue

			var c := amiga_logo.get_pixel(b, r)

			if c.a > 0:
				hd.set_pixel(picture, kx, y, c)

			kx += 1

		y += 1


func _amiga_small_text(x: int, y: int, line: String) -> void:

	# $8b6a : 15 characters of the small font ($86fc), a space skipped

	for i in mini(line.length(), 15):
		var index := amiga_small_letters.find(line[i])

		if index >= 0:
			hd.blend_rect(picture, amiga_small, Rect2i(16 * index, 0, 16, 16), Vector2i(x + 16 * i, y))


func _amiga_stars() -> void:

	# $854c : as the PC's (f29:0202), but a star starts again at depth 0x1fff (y, then x,
	# from the generator) and its colour by depth is from $8614

	var black := amiga_colours[0]

	for star in stars:
		var z: int = (star[2] & 0x7fff) - 0x200
		var sx := 0
		var sy := 0

		if z <= 0x200:
			star[1] = main._random()
			star[0] = main._random()
			z = 0x1fff

		while true:
			star[2] = z
			sx = (_signed(star[0]) * 16) / z + 0xa0
			sy = (_signed(star[1]) * 16) / z + 0x64

			if sx >= 0 and sx < 0x140 and sy >= 0 and sy < 0xc8:
				break

			star[1] = main._random()
			star[0] = main._random()
			z = 0x1fff

		if picture.get_pixel(sx, sy) == black:
			hd.set_pixel(picture, sx, sy, amiga_colours[amiga_star_colours[(z >> 10) & 7]])
		else:
			star[2] = z | 0x8000