--!strict
-- Szablon importu propsów mapy (T15). Plik import_props.luau generuje art/map/gen_import.py z props_meta.json.
-- Kroki: build_props.py → props.fbx → upload (Open Cloud, asset 81577794889258) → insert_asset do ServerStorage
-- jako „PropsImport” → ten skrypt (execute_luau, Edit) → tools/studio/T15_props.luau (rozmieszczenie).
-- Wynik: ServerStorage.MapProps.<Nazwa> — Model z MeshPartów, pivot = środek podstawy (y = 0), atrybuty Category
-- (small/medium/large/landmark) i Biome; latarnie dostają PointLight, komin lawy dym, wrak iskry.

local HttpService = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local META = HttpService:JSONDecode([==[{"Lava_Boulder":{"category":"medium","biome":"LavaFields","parts":{"Rock":{"material":"Basalt","color":"#3A2E31","transparency":0,"center":[-0.1277,2.8536,-0.1958],"size":[15.5579,11.4145,11.7652],"collide":true}}},"Lava_Columns":{"category":"large","biome":"LavaFields","parts":{"Rock":{"material":"Basalt","color":"#3A2E31","transparency":0,"center":[-0.2947,9.9656,-0.6393],"size":[16.7674,21.9312,16.6408],"collide":true},"Rock2":{"material":"Basalt","color":"#5A4648","transparency":0,"center":[-0.2635,7.2276,-0.7466],"size":[9.5714,16.4552,9.6454],"collide":true},"Detail":{"material":"Slate","color":"#4A3E44","transparency":0,"center":[-0.4892,0.0,-0.2348],"size":[18.2655,4.2178,18.0209],"collide":false}}},"Lava_Spire":{"category":"large","biome":"LavaFields","parts":{"Rock":{"material":"Basalt","color":"#3A2E31","transparency":0,"center":[0.087,15.422,-0.2708],"size":[14.221,35.1561,12.9079],"collide":true}}},"Lava_Obsidian":{"category":"medium","biome":"LavaFields","parts":{"Rock":{"material":"Glass","color":"#160E1C","transparency":0,"center":[1.5081,3.3542,1.0314],"size":[7.9838,8.8173,7.7196],"collide":true},"Detail":{"material":"Basalt","color":"#3A2E31","transparency":0,"center":[0.2028,0.0,0.0446],"size":[10.0461,3.9144,10.973],"collide":false}}},"Lava_Vent":{"category":"medium","biome":"LavaFields","fx":{"smoke":[0,6.2,0]},"parts":{"Rock":{"material":"Basalt","color":"#3A2E31","transparency":0,"center":[-0.2938,2.55,-0.1734],"size":[20.0106,8.1,20.7303],"collide":true},"Glow":{"material":"Neon","color":"#FF6A1F","transparency":0,"center":[0.5313,3.8375,0.1028],"size":[15.6875,4.125,15.842],"collide":false}}},"Lava_Arch":{"category":"landmark","biome":"LavaFields","parts":{"Rock":{"material":"Basalt","color":"#3A2E31","transparency":0,"center":[0.3603,15.3295,0.0482],"size":[75.663,39.0138,19.1414],"collide":true},"Glow":{"material":"Neon","color":"#FF6A1F","transparency":0,"center":[-0.0,24.5899,-3.6],"size":[46.7416,15.8173,0.7],"collide":false}}},"Lava_Pebbles":{"category":"small","biome":"LavaFields","parts":{"Rock":{"material":"Basalt","color":"#3A2E31","transparency":0,"center":[0.1658,0.654,0.3833],"size":[9.9461,2.6162,10.3369],"collide":false}}},"Frost_Spikes":{"category":"medium","biome":"FrostCrater","parts":{"Crystal":{"material":"Ice","color":"#A8DCFF","transparency":0.15,"center":[-0.9156,6.2579,1.6711],"size":[13.7463,16.5262,14.1527],"collide":true},"Detail":{"material":"Snow","color":"#E4ECFF","transparency":0,"center":[0.1763,0.0,0.5944],"size":[13.0496,3.7787,12.6974],"collide":false}}},"Frost_Boulder":{"category":"medium","biome":"FrostCrater","parts":{"Rock":{"material":"Rock","color":"#5E6E96","transparency":0,"center":[0.8684,3.0427,0.4121],"size":[16.2102,12.1707,15.7478],"collide":true},"Detail":{"material":"Snow","color":"#E4ECFF","transparency":0,"center":[1.3375,6.5265,-0.1305],"size":[16.0707,5.7507,14.8056],"collide":false}}},"Frost_IceBlock":{"category":"medium","biome":"FrostCrater","parts":{"Crystal":{"material":"Ice","color":"#A8DCFF","transparency":0.15,"center":[-0.9588,3.04,-1.3138],"size":[14.2967,12.1602,12.303],"collide":true}}},"Frost_Pillar":{"category":"large","biome":"FrostCrater","parts":{"Crystal":{"material":"Glacier","color":"#8EC4EE","transparency":0,"center":[-0.1984,12.7462,0.0],"size":[9.3393,26.5076,9.0505],"collide":true},"Glow":{"material":"Neon","color":"#9FE6FF","transparency":0,"center":[-0.3475,9.6677,0.0],"size":[3.8249,19.6906,2.7433],"collide":false},"Detail":{"material":"Snow","color":"#E4ECFF","transparency":0,"center":[-0.0784,0.0,-0.2347],"size":[14.6283,4.6705,17.1703],"collide":false}}},"Frost_Drift":{"category":"small","biome":"FrostCrater","parts":{"Detail":{"material":"Snow","color":"#E4ECFF","transparency":0,"center":[0.0325,0.5811,-0.0737],"size":[26.1159,5.8113,14.7452],"collide":false},"Rock":{"material":"Rock","color":"#5E6E96","transparency":0,"center":[-5.0314,1.5881,0.9543],"size":[5.3644,3.9526,5.1013],"collide":false}}},"Frost_Arch":{"category":"landmark","biome":"FrostCrater","parts":{"Crystal":{"material":"Glacier","color":"#8EC4EE","transparency":0,"center":[0.2296,13.6409,-0.1512],"size":[63.1164,34.1492,16.2305],"collide":true},"Detail":{"material":"Snow","color":"#E4ECFF","transparency":0,"center":[0.0547,0.6481,-0.1017],"size":[67.266,6.4814,15.0933],"collide":false},"Ice":{"material":"Ice","color":"#A8DCFF","transparency":0.15,"center":[-5.323,16.6907,0.0],"size":[32.6167,17.0079,1.2],"collide":false}}},"Frost_Pebbles":{"category":"small","biome":"FrostCrater","parts":{"Rock":{"material":"Rock","color":"#5E6E96","transparency":0,"center":[0.6252,0.5293,-1.2721],"size":[6.435,2.1172,5.1072],"collide":false},"Detail":{"material":"Snow","color":"#E4ECFF","transparency":0,"center":[0.0896,0.0,-0.0327],"size":[10.6637,1.5917,8.8032],"collide":false}}},"Crystal_Cluster":{"category":"medium","biome":"CrystalCanyon","parts":{"Crystal":{"material":"Glass","color":"#5AFFDC","transparency":0.35,"center":[-1.6029,3.7303,-1.0237],"size":[12.8575,11.0381,7.8387],"collide":false},"Glow":{"material":"Neon","color":"#3CFFD8","transparency":0,"center":[-1.4941,3.2635,-0.97],"size":[11.5785,9.1566,6.5322],"collide":false},"Rock":{"material":"Rock","color":"#3E4C6E","transparency":0,"center":[-0.1124,0.5141,-0.1361],"size":[10.3593,5.141,10.248],"collide":true}}},"Crystal_Big":{"category":"large","biome":"CrystalCanyon","parts":{"Crystal":{"material":"Glass","color":"#5AFFDC","transparency":0.35,"center":[0.7687,10.0417,-0.7614],"size":[13.377,24.8854,7.1705],"collide":true},"Glow":{"material":"Neon","color":"#3CFFD8","transparency":0,"center":[0.6466,8.5538,-0.8655],"size":[10.9363,21.018,4.267],"collide":false},"Rock":{"material":"Rock","color":"#3E4C6E","transparency":0,"center":[-0.1814,0.706,-0.46],"size":[15.905,7.0603,14.2972],"collide":true}}},"Crystal_Rock":{"category":"medium","biome":"CrystalCanyon","parts":{"Rock":{"material":"Rock","color":"#3E4C6E","transparency":0,"center":[-0.709,3.4372,-0.2696],"size":[18.0115,13.7489,15.6687],"collide":true},"Crystal":{"material":"Glass","color":"#5AFFDC","transparency":0.35,"center":[-0.33,11.2296,0.2885],"size":[4.9792,6.6501,5.4311],"collide":false},"Glow":{"material":"Neon","color":"#3CFFD8","transparency":0,"center":[-0.3815,10.8992,0.1798],"size":[4.348,5.5632,4.5878],"collide":false}}},"Crystal_Geode":{"category":"medium","biome":"CrystalCanyon","parts":{"Rock":{"material":"Rock","color":"#3E4C6E","transparency":0,"center":[0.0682,1.491,1.6828],"size":[14.263,9.4789,11.8609],"collide":true},"Crystal":{"material":"Glass","color":"#5AFFDC","transparency":0.35,"center":[0.3816,3.3548,1.5573],"size":[7.6339,5.789,5.8357],"collide":false},"Glow":{"material":"Neon","color":"#3CFFD8","transparency":0,"center":[0.3528,3.0567,1.6517],"size":[7.2301,4.8484,5.2713],"collide":false}}},"Crystal_Shards":{"category":"small","biome":"CrystalCanyon","parts":{"Crystal":{"material":"Glass","color":"#5AFFDC","transparency":0.35,"center":[-0.6627,1.0476,-1.6888],"size":[9.3625,3.2733,5.9302],"collide":false},"Rock":{"material":"Limestone","color":"#4F8C9C","transparency":0,"center":[0.1379,0.6591,0.067],"size":[3.8262,2.6363,3.0823],"collide":false}}},"Crystal_Spire":{"category":"landmark","biome":"CrystalCanyon","parts":{"Rock":{"material":"Rock","color":"#3E4C6E","transparency":0,"center":[0.0644,3.0817,0.6821],"size":[36.3931,15.4087,32.578],"collide":true},"Crystal":{"material":"Glass","color":"#5AFFDC","transparency":0.35,"center":[1.7739,28.349,-1.3201],"size":[31.8328,62.9687,40.9409],"collide":true},"Glow":{"material":"Neon","color":"#3CFFD8","transparency":0,"center":[1.6681,24.6214,-1.018],"size":[27.9841,53.1269,35.9412],"collide":false}}},"Crystal_Boulder":{"category":"medium","biome":"CrystalCanyon","parts":{"Rock":{"material":"Rock","color":"#3E4C6E","transparency":0,"center":[0.1775,2.9585,0.0928],"size":[15.6967,11.834,11.3595],"collide":true},"Detail":{"material":"Limestone","color":"#4F8C9C","transparency":0,"center":[-0.202,7.4406,0.5706],"size":[14.3277,3.0472,7.4305],"collide":false}}},"Nebula_Hoodoo":{"category":"large","biome":"NebulaPlateau","parts":{"Rock":{"material":"Sandstone","color":"#8A5FB8","transparency":0,"center":[-0.2546,9.6208,-0.4693],"size":[13.66,19.2416,11.1494],"collide":true},"Detail":{"material":"Salt","color":"#CDAAEC","transparency":0,"center":[-0.3246,9.046,0.0979],"size":[6.264,11.2919,5.4658],"collide":false},"Glow":{"material":"Neon","color":"#E07BFF","transparency":0,"center":[-2.5,14.0,-4.6],"size":[1.0733,1.2,1.0208],"collide":false}}},"Nebula_Mesa":{"category":"large","biome":"NebulaPlateau","parts":{"Rock":{"material":"Sandstone","color":"#8A5FB8","transparency":0,"center":[0.0118,8.2807,-0.2336],"size":[26.3888,16.5614,19.8066],"collide":true},"Detail":{"material":"Salt","color":"#CDAAEC","transparency":0,"center":[-0.022,8.3501,0.0364],"size":[21.4833,10.3001,16.5422],"collide":true}}},"Nebula_Spores":{"category":"small","biome":"NebulaPlateau","parts":{"Rock":{"material":"Sandstone","color":"#8A5FB8","transparency":0,"center":[0.002,2.8005,1.2779],"size":[6.2363,6.4008,5.1037],"collide":false},"Glow":{"material":"Neon","color":"#E07BFF","transparency":0,"center":[-0.0824,4.5854,1.3334],"size":[7.4157,5.3391,6.1022],"collide":false},"Detail":{"material":"Salt","color":"#CDAAEC","transparency":0,"center":[-0.0635,0.0,0.0682],"size":[9.0211,1.8267,8.2962],"collide":false}}},"Nebula_FloatRock":{"category":"medium","biome":"NebulaPlateau","parts":{"Rock":{"material":"Sandstone","color":"#8A5FB8","transparency":0,"center":[-0.803,12.2331,-0.0535],"size":[12.9382,12.4662,12.5416],"collide":false},"Glow":{"material":"Neon","color":"#B48CFF","transparency":0,"center":[-0.0,1.0,0.0],"size":[8.96,0.56,8.96],"collide":false},"Detail":{"material":"Salt","color":"#CDAAEC","transparency":0,"center":[-0.0954,0.2138,0.0906],"size":[11.61,2.1378,11.7641],"collide":true}}},"Nebula_Boulder":{"category":"medium","biome":"NebulaPlateau","parts":{"Rock":{"material":"Sandstone","color":"#8A5FB8","transparency":0,"center":[0.1459,2.6264,0.0762],"size":[16.4743,10.5057,13.4056],"collide":true},"Detail":{"material":"Salt","color":"#CDAAEC","transparency":0,"center":[0.3571,5.8412,0.0785],"size":[15.5651,4.3284,13.8077],"collide":false}}},"Nebula_Monolith":{"category":"landmark","biome":"NebulaPlateau","parts":{"Detail":{"material":"Salt","color":"#CDAAEC","transparency":0,"center":[0.228,0.0,0.9124],"size":[49.5441,4.8019,51.2107],"collide":true},"Rock":{"material":"Sandstone","color":"#8A5FB8","transparency":0,"center":[1.7104,22.5,-0.0337],"size":[28.398,47.0,33.1099],"collide":true},"Glow":{"material":"Neon","color":"#B48CFF","transparency":0,"center":[1.859,18.6932,0.0],"size":[21.052,26.4137,26.7045],"collide":false}}},"Nebula_Pebbles":{"category":"small","biome":"NebulaPlateau","parts":{"Rock":{"material":"Sandstone","color":"#8A5FB8","transparency":0,"center":[0.0056,0.5724,-1.1043],"size":[10.8411,2.2895,8.2105],"collide":false}}},"Common_Rock":{"category":"medium","biome":null,"parts":{"Rock":{"material":"Slate","color":"#5C5874","transparency":0,"center":[0.3052,2.0826,-0.0832],"size":[12.4411,8.3305,11.9113],"collide":true}}},"Common_RockPile":{"category":"medium","biome":null,"parts":{"Rock":{"material":"Slate","color":"#5C5874","transparency":0,"center":[0.8378,1.802,-2.3365],"size":[8.8514,7.2078,9.7539],"collide":true}}},"Beacon_Tower":{"category":"landmark","biome":null,"light":[0,67.2,0],"parts":{"Rock":{"material":"Slate","color":"#5C5874","transparency":0,"center":[-0.0506,0.5167,-0.1445],"size":[18.8796,5.1666,18.9793],"collide":true},"Frame":{"material":"Metal","color":"#30344C","transparency":0,"center":[-0.0,32.5821,0.0],"size":[9.1989,65.2358,9.0394],"collide":true},"Frame2":{"material":"Metal","color":"#7A7F9C","transparency":0,"center":[-0.0,32.049,0.0],"size":[8.4398,64.402,8.4396],"collide":false},"Glow":{"material":"Neon","color":"#FFFFFF","transparency":0,"center":[-0.0,67.2,0.0],"size":[3.4238,3.6,3.6],"collide":false},"Glow2":{"material":"Neon","color":"#7CF2FF","transparency":0,"center":[-0.0,36.75,0.0],"size":[8.8,57.8,8.8],"collide":false}}},"Wreck":{"category":"landmark","biome":null,"fx":{"spark":[5.5,3.5,-22.5]},"parts":{"Rock":{"material":"CorrodedMetal","color":"#6B4A5A","transparency":0,"center":[-0.3653,3.7278,-3.9002],"size":[12.4774,14.9747,38.8839],"collide":true},"Frame2":{"material":"Metal","color":"#7A7F9C","transparency":0,"center":[-11.3979,4.0341,-4.0],"size":[18.2096,3.1555,12.0],"collide":true},"Frame":{"material":"Metal","color":"#30344C","transparency":0,"center":[0.0628,2.55,-2.2637],"size":[28.1848,7.1,40.2725],"collide":false},"Glow2":{"material":"Neon","color":"#7CF2FF","transparency":0,"center":[5.5,3.5,-22.5],"size":[4.0,4.0,0.4],"collide":false},"Detail":{"material":"Slate","color":"#5C5874","transparency":0,"center":[-0.4466,-0.4343,-0.3232],"size":[22.3683,4.3426,12.9657],"collide":false}}},"Shield_Pylon":{"category":"landmark","biome":null,"light":[0,40.5,0],"parts":{"Rock":{"material":"Slate","color":"#5C5874","transparency":0,"center":[0.2142,0.5004,-0.6284],"size":[16.3108,5.0041,16.2805],"collide":true},"Frame":{"material":"Metal","color":"#30344C","transparency":0,"center":[-0.0,18.0,0.0],"size":[5.2,36.0,5.2],"collide":true},"Frame2":{"material":"Metal","color":"#7A7F9C","transparency":0,"center":[-0.0,21.0,0.0],"size":[6.4,34.0,6.4],"collide":false},"Glow":{"material":"Neon","color":"#7CC8FF","transparency":0,"center":[-0.0,23.75,0.0],"size":[7.3,37.5,7.3],"collide":false}}}}]==])

local src = SS:FindFirstChild("PropsImport")
assert(src, "Brak ServerStorage.PropsImport (insert_asset 81577794889258)")

local old = SS:FindFirstChild("MapProps")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "MapProps"

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function emitter(parent: Instance, kind: string)
	local e = Instance.new("ParticleEmitter")
	e.Name = kind
	e.LightEmission = if kind == "Smoke" then 0.2 else 1
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	if kind == "Smoke" then
		e.Color = ColorSequence.new(Color3.fromRGB(90, 70, 80), Color3.fromRGB(40, 34, 44))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(4, 6)
		e.Rate = 3
		e.Speed = NumberRange.new(4, 7)
		e.SpreadAngle = Vector2.new(12, 12)
		e.Acceleration = Vector3.new(1.5, 1, 0)
	else
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(120, 240, 255))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(0.4, 0.9)
		e.Rate = 6
		e.Speed = NumberRange.new(6, 12)
		e.SpreadAngle = Vector2.new(40, 40)
		e.Acceleration = Vector3.new(0, -30, 0)
	end
	e.Parent = parent
end

local count = 0
for name, m in META do
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Category", m.category)
	if m.biome then
		model:SetAttribute("Biome", m.biome)
	end
	local primary: BasePart? = nil
	for partName, p in m.parts do
		local mp = src:FindFirstChild(name .. "_" .. partName) :: MeshPart?
		if not mp then
			warn("Brak " .. name .. "_" .. partName)
			continue
		end
		local part = mp:Clone()
		for _, ch in part:GetChildren() do
			ch:Destroy()
		end
		part.Name = partName
		part.Size = v3(p.size)
		part.CFrame = CFrame.new(v3(p.center))
		part.Material = (Enum.Material :: any)[p.material]
		part.Color = Color3.fromHex(p.color)
		part.Transparency = p.transparency
		part.Anchored = true
		part.CanCollide = p.collide
		part.CanQuery = p.collide
		part.CanTouch = false
		part.CastShadow = p.material ~= "Neon" and m.category ~= "small"
		if p.material == "Glass" or p.material == "Ice" then
			part.Reflectance = 0.1
		end
		part.Parent = model
		if partName == "Rock" or (primary == nil and p.collide) then
			primary = part
		end
	end
	model.PrimaryPart = primary or model:FindFirstChildWhichIsA("BasePart")
	model.WorldPivot = CFrame.new(0, 0, 0)
	if m.light then
		local a = Instance.new("Attachment")
		a.Name = "LightPoint"
		local glow = model:FindFirstChild("Glow") :: BasePart
		a.Parent = glow
		a.WorldPosition = v3(m.light)
		local l = Instance.new("PointLight")
		l.Range = 40
		l.Brightness = 2
		l.Color = glow.Color
		l.Shadows = false
		l.Parent = a
	end
	if m.fx then
		local host = model.PrimaryPart :: BasePart
		for kind, pos in m.fx do
			local a = Instance.new("Attachment")
			a.Name = "Fx_" .. kind
			a.Parent = host
			a.WorldPosition = v3(pos)
			emitter(a, if kind == "smoke" then "Smoke" else "Spark")
		end
	end
	model.Parent = folder
	count += 1
end
folder.Parent = SS
return ("MapProps: %d modeli"):format(count)
