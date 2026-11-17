extends RefCounted

# ENHANCED for the screens that build their own picture (title, shop) : every picture they
# draw on has a twin K times larger, and every drawing is done on both. A source picture
# with an xBRZ version (assets_hd) is drawn from it, any other is enlarged with nearest.
# Shown through hd_texture.gd, so F1 and the title's choice switch it at once.

const HD_TEXTURE = preload("res://scripts/hd_texture.gd")

var k := 4
var twin := {}


func source(base: Image, path: String) -> Image:

	# the xBRZ version of a picture loaded from res://assets/..., if there is one

	var large := HD_TEXTURE.hd_path(path.replace("res://assets/", "res://assets_hd/"))

	if ResourceLoader.exists(large):
		var image: Image = load(large).get_image()
		image.convert(Image.FORMAT_RGBA8)
		twin[base] = image

	return base


func target(base: Image) -> Image:

	# a picture drawn on : its twin starts as its nearest enlargement

	var image := base.duplicate()
	image.resize(base.get_width() * k, base.get_height() * k, Image.INTERPOLATE_NEAREST)
	twin[base] = image
	return base


func view(base: Image, shown: ImageTexture) -> Dictionary:

	# the texture to show (original or xBRZ by hd_texture.on) and the large one to update

	var large := ImageTexture.create_from_image(twin[base])
	return {"texture": HD_TEXTURE.new(shown, large), "large": large}


func show(large: ImageTexture, base: Image) -> void:
	if HD_TEXTURE.on and twin.has(base):
		large.update(twin[base])


func _margin(src: Image) -> int:

	# an NB2 frame that reaches past the original one (x2nb2.py) : the margin around it, in
	# large pixels

	if not twin.has(src):
		return 0

	var extra: int = twin[src].get_width() - src.get_width() * k
	return extra / 2 if extra > 0 and extra == twin[src].get_height() - src.get_height() * k else 0


func _part(src: Image, rect: Rect2i) -> Image:
	if twin.has(src):
		var m := _margin(src)
		return twin[src].get_region(Rect2i(rect.position * k + Vector2i(m, m), rect.size * k))

	var part := src.get_region(rect)
	part.resize(rect.size.x * k, rect.size.y * k, Image.INTERPOLATE_NEAREST)
	return part


func blit_rect(dst: Image, src: Image, rect: Rect2i, at: Vector2i) -> void:
	dst.blit_rect(src, rect, at)

	if twin.has(dst):
		var part := _part(src, rect)
		twin[dst].blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), at * k)


func blend_rect(dst: Image, src: Image, rect: Rect2i, at: Vector2i) -> void:
	dst.blend_rect(src, rect, at)

	if not twin.has(dst):
		return

	var m := _margin(src)

	if m == 0:
		var part := _part(src, rect)
		twin[dst].blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), at * k)
		return

	# with the margin on the sides where the part ends with the frame

	var lo := Vector2i(m if rect.position.x <= 0 else 0, m if rect.position.y <= 0 else 0)
	var hi := Vector2i(m if rect.end.x >= src.get_width() else 0, m if rect.end.y >= src.get_height() else 0)
	var region := Rect2i(rect.position * k + Vector2i(m, m) - lo, rect.size * k + lo + hi)
	twin[dst].blend_rect(twin[src], region, at * k - lo)


func fill(dst: Image, colour: Color) -> void:
	dst.fill(colour)

	if twin.has(dst):
		twin[dst].fill(colour)


func fill_rect(dst: Image, rect: Rect2i, colour: Color) -> void:
	dst.fill_rect(rect, colour)

	if twin.has(dst):
		twin[dst].fill_rect(Rect2i(rect.position * k, rect.size * k), colour)


func set_pixel(dst: Image, x: int, y: int, colour: Color) -> void:
	dst.set_pixel(x, y, colour)

	if twin.has(dst):
		twin[dst].fill_rect(Rect2i(x * k, y * k, k, k), colour)


func copy_from(dst: Image, src: Image) -> void:
	dst.copy_from(src)

	if twin.has(dst) and twin.has(src):
		twin[dst].copy_from(twin[src])


func recoloured(base: Image, path: String, from: Array, to: Array) -> void:

	# a sprite drawn with another palette (the shop's) : the xBRZ version mapped too, each
	# pixel by its nearest source colour, keeping the difference (the smoothed edges)

	source(base, path)

	if not twin.has(base):
		return

	var image: Image = twin[base]

	for y in image.get_height():
		for x in image.get_width():
			var p := image.get_pixel(x, y)

			if p.a <= 0.0:
				continue

			var best := 0
			var best_d := 1e9

			for i in from.size():
				var c: Color = from[i]
				var d := (p.r - c.r) * (p.r - c.r) + (p.g - c.g) * (p.g - c.g) + (p.b - c.b) * (p.b - c.b)

				if d < best_d:
					best_d = d
					best = i

			var s: Color = from[best]
			var t: Color = to[best]
			image.set_pixel(x, y, Color(clampf(t.r + p.r - s.r, 0, 1), clampf(t.g + p.g - s.g, 0, 1), clampf(t.b + p.b - s.b, 0, 1), p.a))
