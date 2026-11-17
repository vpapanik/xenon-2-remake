extends Texture2D

# ENHANCED : a picture that keeps the original size (so every position, region and
# collision of the game stays in the original pixels) and draws either the original or its
# xBRZ enlargement (assets_hd, factor times larger, linear filtering), as `on` says. The
# switch is immediate, nothing is loaded again. For the detail to show, the canvas must be
# drawn at the window's resolution (content scale mode canvas_items, main.gd _set_enhanced).

static var on := false

# assets_hd names each picture by how it was enlarged : <name>_NB2.png (redrawn with Nano
# Banana 2, x2nb2.py) or <name>_xBRZ.png (x2xbrz.py). A tile sheet with some NB2 tiles is
# _NB2. The path of the enlarged picture for res://assets_hd/<name>.png, or that path when
# there is none.

static func hd_path(path: String) -> String:
	for suffix in ["_NB2", "_xBRZ"]:
		var named: String = path.get_basename() + suffix + "." + path.get_extension()

		if ResourceLoader.exists(named):
			return named

	return path


const K := 4.0

var base: Texture2D
var hd: CanvasTexture
var factor := 1.0

# an NB2 frame may reach past the original frame (x2nb2.py) : its picture is then K times
# the original plus a margin on each side, here in original pixels, drawn around the
# frame (positions and collisions stay those of the original)

var margin := Vector2.ZERO


func _init(original: Texture2D, large: Texture2D) -> void:
	base = original
	factor = float(large.get_width()) / original.get_width()
	var extra := Vector2(large.get_size()) - Vector2(original.get_size()) * K

	if extra.x > 0 and extra.x == extra.y and extra.x <= 4 * K:
		factor = K
		margin = extra / (2 * K)
	hd = CanvasTexture.new()
	hd.diffuse_texture = large
	hd.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _get_width() -> int:
	return base.get_width()


func _get_height() -> int:
	return base.get_height()


func _has_alpha() -> bool:
	return base.has_alpha()


func _is_pixel_opaque(_x: int, _y: int) -> bool:
	return true


func _wider(rect: Rect2) -> Rect2:

	# the whole frame drawn in rect : with the margin around it, at the same scale

	var m := margin * rect.size / Vector2(base.get_size())
	return Rect2(rect.position - m, rect.size + 2 * m)


func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	var rid := hd.get_rid() if on else base.get_rid()
	var rect := Rect2(pos, base.get_size())
	RenderingServer.canvas_item_add_texture_rect(to_canvas_item, _wider(rect) if on else rect, rid, false, modulate, transpose)


func _draw_rect(to_canvas_item: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool) -> void:
	var rid := hd.get_rid() if on else base.get_rid()
	RenderingServer.canvas_item_add_texture_rect(to_canvas_item, _wider(rect) if on and not tile else rect, rid, tile, modulate, transpose)


func _draw_rect_region(to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	if on:
		# a part of the frame : the margin only on the sides where the part ends with the
		# frame (a frame cut by the edge of the screen stays cut there)

		var region := Rect2((src_rect.position + margin) * factor, src_rect.size * factor)

		if margin != Vector2.ZERO:
			var scale := rect.size / src_rect.size
			var size := Vector2(base.get_size())
			var lo := Vector2(margin.x if src_rect.position.x <= 0 else 0.0, margin.y if src_rect.position.y <= 0 else 0.0)
			var hi := Vector2(margin.x if src_rect.end.x >= size.x else 0.0, margin.y if src_rect.end.y >= size.y else 0.0)
			region = Rect2(region.position - lo * factor, region.size + (lo + hi) * factor)
			rect = Rect2(rect.position - lo * scale, rect.size + (lo + hi) * scale)

		RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, rect, hd.get_rid(), region, modulate, transpose, clip_uv)
	else:
		RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, rect, base.get_rid(), src_rect, modulate, transpose, clip_uv)
