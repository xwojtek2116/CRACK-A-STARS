--!strict
-- VfxIds — własne tekstury VFX (T38). Źródło: `python tools/vfx_gen.py` → art/vfx/textures/<nazwa>.png,
-- upload przez Studio MCP (upload_image). Tekstury są białe z alfą — kolor nadaje silnik.

return table.freeze({
	NEBULA = "rbxassetid://74710894167700", -- nebula.png: wnętrze wyrwy (bezszwowa)
	SWIRL = "rbxassetid://102874429136340", -- swirl.png: wir w głębi wyrwy
	RIFT_GLOW = "rbxassetid://118116169293257", -- rift_glow.png: poświata krawędzi (Beam)
	LIGHTNING = table.freeze({
		"rbxassetid://131006130629792", -- lightning_1.png
		"rbxassetid://76319508223110", -- lightning_2.png
		"rbxassetid://131729280965161", -- lightning_3.png
	}),
	SPARK = "rbxassetid://126793922218542", -- spark.png
	EMBER = "rbxassetid://81327212487098", -- ember.png
	SMOKE_SHEET = "rbxassetid://131995462626371", -- smoke_sheet.png: flipbook 4×4
	DUST = "rbxassetid://140088838660294", -- dust.png
	SHOCK_RING = "rbxassetid://109953957502659", -- shock_ring.png
	WARN_RING = "rbxassetid://98505196682510", -- warn_ring.png
	FLARE = "rbxassetid://103565204389184", -- flare.png
	FIRE_TRAIL = "rbxassetid://133225013917694", -- fire_trail.png (Trail)
	ENERGY = "rbxassetid://78781932683130", -- energy.png (Beam z TextureSpeed)
	CRACKS = "rbxassetid://116222846724955", -- cracks.png (Decal krateru)
	-- T39
	LIGHT_SHAFT = "rbxassetid://95481741372385", -- light_shaft.png: snop/słup światła (Beam)
	PLASMA = "rbxassetid://136463784511671", -- plasma.png: ogon plazmy (Beam z TextureSpeed)
	HEAT_RING = "rbxassetid://78691950068423", -- heat_ring.png: pierścień przyspieszenia
	ENERGY_WAVE = "rbxassetid://107174927114880", -- energy_wave.png: fala energii na ziemi
	GLINT = "rbxassetid://121860539319055", -- glint.png: błysk-gwiazdka
})
