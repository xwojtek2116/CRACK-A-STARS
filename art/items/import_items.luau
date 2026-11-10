--!strict
-- WYGENEROWANE (T21) z import_items.template.luau przez art/items/gen_import.py (wstawia META) — nie edytuj wygenerowanego.
-- Uruchom w Studio (execute_luau, Edit) po wstawieniu FBX art/items/<theme>/items_<theme>.fbx do ServerStorage.ItemImport (insert_asset).
-- Wynik: ServerStorage.Items/<itemId> — Model z częściami `<Część>` (kolory i materiały zapieczone), pivot = środek przedmiotu
-- bez obrotu, PrimaryPart = Body (albo największa nieanimowana część), atrybuty ItemId/Rarity.
-- Części animowane przez klienta (BaseController → ItemFx) mają atrybuty: FxType = Spin | Orbit | Pulse,
-- FxAxis (Vector3, układ modelu), FxSpeed (°/s), FxBob (studs przy skali 1), FxAmount, FxRate.
-- Cząsteczki (ParticleEmitter "ItemSparkle<n>") z tekstur VfxIds. Brak Tint — kolory są w modelu (decyzja T21).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VfxIds = require(ReplicatedStorage.Shared.Config.VfxIds) :: any
local META = HttpService:JSONDecode([==[{"iron_pebble":{"name":"Rusty Nugget","rarity":"Common","parts":{"Body":{"material":"Metal","color":"#9A9AA6","center":[-0.0232,-0.0595,0.0226]},"Rust":{"material":"CorrodedMetal","color":"#8A4B2A","center":[0.0495,0.0781,0.1346]},"Glow":{"material":"Neon","color":"#FF9A3C","center":[-0.3407,0.0656,-0.4652]}}},"iron_shard":{"name":"Iron Chunk","rarity":"Uncommon","parts":{"Body":{"material":"Metal","color":"#9A9AA6","center":[0.0561,0.0623,-0.0131]},"Dents":{"material":"Metal","color":"#3A3A40","center":[-0.0272,0.0049,-0.0248]},"Glow":{"material":"Neon","color":"#FF9A3C","center":[-0.0047,0.0045,-0.0124]},"Rust":{"material":"CorrodedMetal","color":"#8A4B2A","center":[-0.0107,-0.5009,0.0686]}}},"iron_crystal":{"name":"Meteor Ingot","rarity":"Rare","parts":{"Dark":{"material":"Metal","color":"#3A3A40","center":[-0.0211,-0.34,0.0034]},"Body":{"material":"Metal","color":"#9A9AA6","center":[-0.0,0.1,0.0]},"Glow":{"material":"Neon","color":"#FF9A3C","center":[0.01,-0.0115,-0.209]},"Rust":{"material":"CorrodedMetal","color":"#8A4B2A","center":[-0.0103,-0.4438,0.1455]}}},"iron_core":{"name":"Magnet Core","rarity":"Epic","parts":{"Core":{"material":"Neon","color":"#FF9A3C","center":[-0.0,0.0,0.0]},"Shell":{"material":"Metal","color":"#3A3A40","center":[-0.0008,0.0006,-0.0024]},"Steel":{"material":"Metal","color":"#C4CAD6","center":[-0.0,0.2265,0.0]},"SpinCage":{"material":"SmoothPlastic","color":"#D23A3A","center":[-0.0,0.347,0.0],"anim":{"type":"spin","axis":[-0.0,1.0,0.0],"speed":35}},"SpinTips":{"material":"Metal","color":"#C4CAD6","center":[-0.0,-0.43,0.0],"anim":{"type":"spin","axis":[-0.0,1.0,0.0],"speed":35}},"SpinField":{"material":"Neon","color":"#FF6A2A","center":[-0.0,0.0,0.0],"anim":{"type":"spin","axis":[-0.0,1.0,0.0],"speed":35}}}},"iron_orb":{"name":"Titan Alloy","rarity":"Legendary","particles":[{"part":"Body","color":"#FF9A3C","rate":4,"size":0.18,"speed":0.4,"tex":"spark","life":1.2}],"parts":{"Body":{"material":"Metal","color":"#C4CAD6","center":[-0.0,0.0,0.0]},"Band":{"material":"Metal","color":"#3A3A40","center":[-0.0,0.0,0.0]},"Rivets":{"material":"Metal","color":"#9A9AA6","center":[-0.0,0.0,0.0]},"Glow":{"material":"Neon","color":"#FF9A3C","center":[-0.0,0.0,0.0]},"SpinRingA":{"material":"Metal","color":"#9A9AA6","center":[-0.0,0.0,0.0],"anim":{"type":"spin","axis":[-0.3875,0.7264,-0.5676],"speed":45}},"SpinRingAGlow":{"material":"Neon","color":"#FFD27A","center":[-0.2259,0.1496,-0.1169],"anim":{"type":"spin","axis":[-0.3875,0.7264,-0.5676],"speed":45}},"SpinRingB":{"material":"Metal","color":"#9A9AA6","center":[-0.0,0.0,0.0],"anim":{"type":"spin","axis":[0.4446,0.6443,0.6222],"speed":-32}},"SpinRingBGlow":{"material":"Neon","color":"#FFD27A","center":[-0.2418,-0.1727,-0.1668],"anim":{"type":"spin","axis":[0.4446,0.6443,0.6222],"speed":-32}},"Orbit":{"material":"Metal","color":"#3A3A40","center":[-0.2003,-0.1264,0.0512],"anim":{"type":"orbit","axis":[-0.0,1.0,0.0],"speed":24,"bob":0.05}},"OrbitGlow":{"material":"Neon","color":"#FF9A3C","center":[-0.2028,-0.1408,0.0554],"anim":{"type":"orbit","axis":[-0.0,1.0,0.0],"speed":24,"bob":0.05}}}},"iron_heart":{"name":"Ironheart Relic","rarity":"Mythic","particles":[{"part":"PulseCore","color":"#FF9A3C","rate":12,"size":0.3,"speed":0.8,"tex":"spark","life":1.4,"aura":true},{"part":"Body","color":"#FFD27A","rate":6,"size":0.16,"speed":0.3,"tex":"glint","life":1.6}],"parts":{"Body":{"material":"Metal","color":"#9A9AA6","center":[-0.0,-0.08,0.0]},"Band":{"material":"Metal","color":"#3A3A40","center":[0.005,-0.05,0.0]},"Rivets":{"material":"Metal","color":"#C4CAD6","center":[0.0003,-0.0797,-0.2876]},"Glow":{"material":"Neon","color":"#FF9A3C","center":[-0.075,0.4428,-0.0205]},"PulseCore":{"material":"Neon","color":"#FFD27A","center":[-0.0,0.1,0.0],"anim":{"type":"pulse","amount":0.12,"rate":1.1}},"Socket":{"material":"Metal","color":"#3A3A40","center":[-0.0,0.0368,0.0]},"Pipes":{"material":"Metal","color":"#3A3A40","center":[-0.075,0.6896,0.0]},"SpinHalo":{"material":"Neon","color":"#FFD27A","center":[-0.0,0.02,0.05],"anim":{"type":"spin","axis":[-0.0,0.0,1.0],"speed":22}},"Orbit":{"material":"Metal","color":"#3A3A40","center":[-0.117,-0.2947,-0.0198],"anim":{"type":"orbit","axis":[-0.0,1.0,0.0],"speed":36,"bob":0.05}},"OrbitGlow":{"material":"Neon","color":"#FF9A3C","center":[-0.1311,-0.2895,-0.0256],"anim":{"type":"orbit","axis":[-0.0,1.0,0.0],"speed":36,"bob":0.05}}}},"lava_pebble":{"name":"Magma Pebble","rarity":"Common","parts":{"Body":{"material":"Basalt","color":"#1C1412","center":[0.1175,-0.0643,-0.0172]},"Glow":{"material":"Neon","color":"#FF5A1F","center":[0.0765,-0.0858,-0.0574]}}},"lava_shard":{"name":"Ember Shard","rarity":"Uncommon","parts":{"Body":{"material":"Glass","color":"#2A0E14","center":[0.0213,0.186,-0.0002]},"Glow":{"material":"Neon","color":"#FFE08A","center":[0.0895,0.8817,0.0]},"GlowMagma":{"material":"Neon","color":"#FF5A1F","center":[-0.025,-0.3805,0.025]},"Base":{"material":"Basalt","color":"#1C1412","center":[0.0094,-0.7112,-0.0353]}}},"lava_crystal":{"name":"Cinder Crystal","rarity":"Rare","parts":{"Base":{"material":"Basalt","color":"#1C1412","center":[-0.0471,-0.5493,0.0039]},"Crystal":{"material":"SmoothPlastic","color":"#C8401A","center":[0.0127,0.2678,-0.0222]},"Glow":{"material":"Neon","color":"#FF5A1F","center":[-0.223,-0.1704,0.018]},"Tips":{"material":"Neon","color":"#FFE08A","center":[0.02,0.5752,-0.0229]}}},"lava_core":{"name":"Molten Core","rarity":"Epic","parts":{"Core":{"material":"Neon","color":"#FF5A1F","center":[-0.0,0.0,0.0]},"CoreHot":{"material":"Neon","color":"#FFE08A","center":[-0.0,0.0,0.0]},"Shell":{"material":"Basalt","color":"#1C1412","center":[-0.0122,-0.0052,0.0137]},"Drips":{"material":"Neon","color":"#FF5A1F","center":[0.04,-0.6996,0.075]},"SpinCage":{"material":"Basalt","color":"#3A2A26","center":[-0.0,0.0442,0.0],"anim":{"type":"spin","axis":[-0.0,1.0,0.0],"speed":30}},"SpinSeam":{"material":"Neon","color":"#FF5A1F","center":[-0.0,0.065,0.0],"anim":{"type":"spin","axis":[-0.0,1.0,0.0],"speed":30}},"SpinGlow":{"material":"Neon","color":"#FFB347","center":[-0.0,0.09,0.0],"anim":{"type":"spin","axis":[-0.0,1.0,0.0],"speed":30}}}},"lava_orb":{"name":"Phoenix Ember","rarity":"Legendary","particles":[{"part":"FeatherCore","color":"#FFB347","rate":10,"size":0.22,"speed":0.9,"tex":"spark","life":1.0,"up":true}],"parts":{"Feather":{"material":"Neon","color":"#FF5A1F","center":[0.0857,0.24,-0.0083]},"FeatherB":{"material":"Neon","color":"#FFB347","center":[0.3044,0.1895,0.0]},"FeatherTip":{"material":"Neon","color":"#FFE08A","center":[0.0518,1.01,0.0]},"FeatherCore":{"material":"Neon","color":"#FFE08A","center":[0.0997,0.1337,0.0]},"Quill":{"material":"Basalt","color":"#1C1412","center":[-0.0051,-0.9126,0.0048]},"SpinRing":{"material":"Neon","color":"#FF5A1F","center":[0.003,0.0007,-0.0052],"anim":{"type":"spin","axis":[0.1392,0.9609,-0.2396],"speed":40}},"SpinRingRock":{"material":"Basalt","color":"#1C1412","center":[0.011,-0.0066,0.0896],"anim":{"type":"spin","axis":[0.1392,0.9609,-0.2396],"speed":40}},"OrbitSparks":{"material":"Neon","color":"#FFE08A","center":[-0.3125,0.0,0.0],"anim":{"type":"orbit","axis":[-0.0,1.0,0.0],"speed":-26,"bob":0.08}}}},"lava_heart":{"name":"Inferno Heart","rarity":"Mythic","particles":[{"part":"PulseCore","color":"#FF7A2A","rate":14,"size":0.32,"speed":1.0,"tex":"spark","life":1.2,"aura":true,"up":true}],"parts":{"PulseCore":{"material":"Neon","color":"#FF5A1F","center":[-0.0,-0.0744,0.0],"anim":{"type":"pulse","amount":0.07,"rate":1.3}},"Body":{"material":"Basalt","color":"#1C1412","center":[0.0034,-0.0825,0.0019]},"Flames":{"material":"Neon","color":"#FFB347","center":[0.008,0.8369,0.0097]},"Drips":{"material":"Neon","color":"#FF5A1F","center":[-0.01,-0.895,0.0]},"SpinHalo":{"material":"Neon","color":"#FF5A1F","center":[-0.0,0.02,0.05],"anim":{"type":"spin","axis":[-0.0,0.0,1.0],"speed":-20}},"Orbit":{"material":"Basalt","color":"#1C1412","center":[-0.0321,-0.2529,0.0415],"anim":{"type":"orbit","axis":[-0.0,1.0,0.0],"speed":34,"bob":0.05}},"OrbitGlow":{"material":"Neon","color":"#FF5A1F","center":[-0.0485,-0.2861,0.0431],"anim":{"type":"orbit","axis":[-0.0,1.0,0.0],"speed":34,"bob":0.05}}}},"frost_pebble":{"name":"Frost Pebble","rarity":"Common","parts":{"Body":{"material":"Ice","color":"#B9D4E6","center":[-0.0496,0.0236,-0.0214]},"Snow":{"material":"Snow","color":"#F4FAFF","center":[0.0253,0.4406,0.0326]},"Glow":{"material":"Neon","color":"#7FD8FF","center":[-0.0857,-0.0325,-0.5352]}}},"frost_shard":{"name":"Icicle Shard","rarity":"Uncommon","parts":{"Body":{"material":"Ice","color":"#B9D4E6","center":[-0.0465,0.5472,-0.0372]},"Snow":{"material":"Snow","color":"#F4FAFF","center":[-0.0003,0.8187,0.0023]},"Icicles":{"material":"Ice","color":"#7FB6DA","center":[-0.0059,-0.2664,0.084]},"Glow":{"material":"Neon","color":"#E6FBFF","center":[-0.0117,-0.3535,-0.0178]}}},"frost_crystal":{"name":"Glacier Crystal","rarity":"Rare","parts":{"Base":{"material":"Snow","color":"#F4FAFF","center":[-0.0373,-0.555,0.0192]},"Crystal":{"material":"Ice","color":"#B9D4E6","center":[0.0097,0.2658,0.0036]},"Tips":{"material":"Neon","color":"#E6FBFF","center":[0.3389,0.4676,-0.1659]},"TipsA":{"material":"Neon","color":"#7FD8FF","center":[-0.4138,0.1835,0.2048]},"CrystalDk":{"material":"Ice","color":"#7FB6DA","center":[0.1122,-0.1769,0.0369]}}},"frost_core":{"name":"Frozen Core","rarity":"Epic","parts":{"Core":{"material":"Neon","color":"#E6FBFF","center":[-0.0,0.0,0.0]},"Shell":{"material":"Ice","color":"#B9D4E6","center":[0.0149,-0.0003,0.0014]},"SpinCage":{"material":"Ice","color":"#7FB6DA","center":[-0.0,0.0,0.0],"anim":{"type":"spin","axis":[-0.0,1.0,0.0],"speed":28}},"SpinGlow":{"material":"Neon","color":"#7FD8FF","center":[-0.0,0.0,0.0],"anim":{"type":"spin","axis":[-0.0,1.0,0.0],"speed":28}}}},"frost_orb":{"name":"Aurora Prism","rarity":"Legendary","particles":[{"part":"Body","color":"#BFF4FF","rate":6,"size":0.18,"speed":0.3,"tex":"glint","life":1.6}],"parts":{"Body":{"material":"Ice","color":"#B9D4E6","center":[-0.0,0.0,0.0]},"Glow":{"material":"Neon","color":"#E6FBFF","center":[-0.0,0.0,0.0]},"SpinRingA":{"material":"Neon","color":"#6CFFB8","center":[-0.0337,0.0408,-0.0037],"anim":{"type":"spin","axis":[-0.2588,0.8365,-0.483],"speed":40}},"SpinRingB":{"material":"Neon","color":"#B98CFF","center":[-0.0343,-0.0419,-0.0171],"anim":{"type":"spin","axis":[0.3256,0.7451,0.5821],"speed":-30}},"Orbit":{"material":"Snow","color":"#F4FAFF","center":[-0.0,0.0,0.0],"anim":{"type":"orbit","axis":[-0.0,1.0,0.0],"speed":22,"bob":0.06}}}},"frost_heart":{"name":"Blizzard Heart","rarity":"Mythic","particles":[{"part":"PulseCore","color":"#E6FBFF","rate":14,"size":0.25,"speed":0.6,"tex":"glint","life":1.6,"aura":true}],"parts":{"PulseCore":{"material":"Neon","color":"#7FD8FF","center":[-0.0,-0.0744,0.0],"anim":{"type":"pulse","amount":0.07,"rate":1.0}},"Body":{"material":"Ice","color":"#B9D4E6","center":[0.0021,-0.0833,0.0027]},"Crown":{"material":"Ice","color":"#7FB6DA","center":[0.0045,0.8101,0.0]},"Snow":{"material":"Snow","color":"#F4FAFF","center":[0.3157,0.5974,0.0242]},"SpinHalo":{"material":"Neon","color":"#E6FBFF","center":[-0.0,0.02,0.05],"anim":{"type":"spin","axis":[-0.0,0.0,1.0],"speed":18}},"Orbit":{"material":"Ice","color":"#B9D4E6","center":[-0.1412,-0.3149,-0.004],"anim":{"type":"orbit","axis":[-0.0,1.0,0.0],"speed":30,"bob":0.05}},"OrbitGlow":{"material":"Neon","color":"#7FD8FF","center":[-0.1458,-0.2983,-0.0125],"anim":{"type":"orbit","axis":[-0.0,1.0,0.0],"speed":30,"bob":0.05}}}},"geode_pebble":{"name":"Quartz Pebble","rarity":"Common","parts":{"Body":{"material":"Glass","color":"#EDE4FA","center":[-0.0255,-0.0374,0.0013]},"Crystal":{"material":"Glass","color":"#B06BFF","center":[0.0361,0.5069,-0.2266]},"Glow":{"material":"Neon","color":"#B06BFF","center":[-0.3643,-0.1906,-0.512]}}},"geode_shard":{"name":"Amethyst Shard","rarity":"Uncommon","parts":{"Base":{"material":"Rock","color":"#5B4A3E","center":[0.0535,-0.6323,0.0052]},"Crystal":{"material":"Glass","color":"#B06BFF","center":[-0.1169,0.2371,-0.0414]},"CrystalDk":{"material":"Glass","color":"#7A3CC8","center":[-0.0469,-0.3279,0.0192]},"Glow":{"material":"Neon","color":"#E3C4FF","center":[-0.1177,0.2811,-0.0107]},"GlowTip":{"material":"Neon","color":"#B06BFF","center":[-0.2028,0.789,-0.0563]}}},"geode_crystal":{"name":"Geode Cluster","rarity":"Rare","parts":{"Body":{"material":"Rock","color":"#5B4A3E","center":[-0.0307,-0.0427,0.1112]},"Rim":{"material":"Glass","color":"#EDE4FA","center":[-0.0,0.0803,-0.0892]},"CrystalDk":{"material":"Glass","color":"#7A3CC8","center":[0.1687,0.0261,-0.1703]},"Crystal":{"material":"Glass","color":"#B06BFF","center":[-0.1263,0.1234,-0.0816]},"Glow":{"material":"Neon","color":"#B06BFF","center":[-0.0,0.1204,-0.1338]}}},"geode_core":{"name":"Crystal Egg","rarity":"Epic","particles":[{"part":"Core","color":"#E3C4FF","rate":5,"size":0.16,"speed":0.3,"tex":"glint","life":1.2}],"parts":{"SpinShell":{"material":"Rock","color":"#5B4A3E","center":[-0.0129,0.0042,0.0095],"anim":{"type":"spin","axis":[-0.0,1.0,0.0],"speed":18}},"Core":{"material":"Neon","color":"#B06BFF","center":[-0.0,0.0,0.0]},"CrystalDk":{"material":"Glass","color":"#7A3CC8","center":[0.0763,-0.0991,0.0099]},"Crystal":{"material":"Glass","color":"#B06BFF","center":[-0.0532,0.0837,0.0145]}}},"geode_orb":{"name":"Prism Geode","rarity":"Legendary","parts":{"Body":{"material":"Glass","color":"#B06BFF","center":[-0.0,0.0,0.0]},"Glow":{"material":"Neon","color":"#E3C4FF","center":[-0.0,0.0,0.0]},"Band":{"material":"Rock","color":"#5B4A3E","center":[0.0037,0.0007,-0.0096]},"SpinRingA":{"material":"Glass","color":"#EDE4FA","center":[-0.0,0.0,-0.0014],"anim":{"type":"spin","axis":[-0.2419,0.8229,-0.5142],"speed":35}},"SpinRingB":{"material":"Neon","color":"#B06BFF","center":[-0.0394,-0.0452,-0.0246],"anim":{"type":"spin","axis":[0.342,0.7198,0.604],"speed":-28}},"Orbit":{"material":"Rock","color":"#3E322A","center":[-0.2553,-0.1935,0.0426],"anim":{"type":"orbit","axis":[-0.0,1.0,0.0],"speed":22,"bob":0.05}},"OrbitGlow":{"material":"Neon","color":"#B06BFF","center":[-0.2546,-0.1886,0.0545],"anim":{"type":"orbit","axis":[-0.0,1.0,0.0],"speed":22,"bob":0.05}}}},"geode_heart":{"name":"Heart of Amethyst","rarity":"Mythic","particles":[{"part":"PulseHeart","color":"#E3C4FF","rate":14,"size":0.25,"speed":0.6,"tex":"glint","life":1.5,"aura":true}],"parts":{"PulseHeart":{"material":"Glass","color":"#B06BFF","center":[-0.0,-0.08,0.0],"anim":{"type":"pulse","amount":0.05,"rate":1.0}},"Glow":{"material":"Neon","color":"#B06BFF","center":[-0.0,-0.04,0.0]},"Husk":{"material":"Rock","color":"#5B4A3E","center":[0.0034,-0.0856,0.0202]},"Crown":{"material":"Glass","color":"#7A3CC8","center":[0.002,0.715,0.0]},"SpinHalo":{"material":"Neon","color":"#E3C4FF","center":[-0.0,0.02,0.05],"anim":{"type":"spin","axis":[-0.0,0.0,1.0],"speed":20}},"Orbit":{"material":"Glass","color":"#7A3CC8","center":[-0.113,-0.2786,0.0],"anim":{"type":"orbit","axis":[-0.0,1.0,0.0],"speed":30,"bob":0.05}}}}}]==])
local TEX = { spark = VfxIds.SPARK, glint = VfxIds.GLINT }

local import = ServerStorage:FindFirstChild("ItemImport")
assert(import, "Brak ServerStorage.ItemImport — najpierw insert_asset items_<theme>.fbx")
local root = ServerStorage:FindFirstChild("Items") or Instance.new("Folder")
root.Name = "Items"
root.Parent = ServerStorage

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local report = {}
for itemId, m in META do
	local first: BasePart? = nil
	local firstName = ""
	for partName in m.parts do
		local src = import:FindFirstChild(itemId .. "_" .. partName, true) :: BasePart?
		if src then
			first, firstName = src, partName
			break
		end
	end
	if not first then
		continue -- przedmiot z innego pliku FBX
	end
	local old = root:FindFirstChild(itemId)
	if old then
		old:Destroy()
	end
	-- insert_asset obraca i przesuwa model — liczymy części względem pierwszej (jej środek z meta), wynik bez obrotu.
	local base = first.CFrame
	local firstCenter = v3(m.parts[firstName].center)

	local model = Instance.new("Model")
	model.Name = itemId
	model:SetAttribute("ItemId", itemId)
	model:SetAttribute("Rarity", m.rarity)
	model:SetAttribute("DisplayName", m.name)
	local maxErr = 0
	local count = 0
	local primary: BasePart? = nil
	local primaryVolume = 0
	for partName, p in m.parts do
		local src = import:FindFirstChild(itemId .. "_" .. partName, true) :: BasePart?
		if not src then
			table.insert(report, itemId .. ": brak " .. partName)
			continue
		end
		local part = src:Clone()
		part.Name = partName
		local ok, mat = pcall(function()
			return (Enum.Material :: any)[p.material]
		end)
		part.Material = if ok and mat then mat else Enum.Material.SmoothPlastic
		part.Color = Color3.fromHex(p.color)
		part.Transparency = 0
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = part.Material ~= Enum.Material.Neon
		part.CFrame = CFrame.new(firstCenter) * base:ToObjectSpace(src.CFrame)
		maxErr = math.max(maxErr, (part.Position - v3(p.center)).Magnitude)
		local a = p.anim
		if a then
			local fxType = if a.type == "spin" then "Spin" elseif a.type == "orbit" then "Orbit" else "Pulse"
			part:SetAttribute("FxType", fxType)
			if a.axis then
				part:SetAttribute("FxAxis", v3(a.axis))
			end
			part:SetAttribute("FxSpeed", a.speed or 0)
			part:SetAttribute("FxBob", a.bob or 0)
			part:SetAttribute("FxAmount", a.amount or 0)
			part:SetAttribute("FxRate", a.rate or 0)
		else
			local volume = part.Size.X * part.Size.Y * part.Size.Z
			if partName == "Body" then
				volume = math.huge
			end
			if volume > primaryVolume then
				primary, primaryVolume = part, volume
			end
		end
		part.Parent = model
		count += 1
	end
	if not primary then
		primary = model:FindFirstChildWhichIsA("BasePart")
	end
	model.PrimaryPart = primary
	model.WorldPivot = CFrame.new(0, 0, 0)

	for i, pe in m.particles or {} do
		local host = model:FindFirstChild(pe.part) :: BasePart?
		if not host then
			continue
		end
		local e = Instance.new("ParticleEmitter")
		e.Name = "ItemSparkle" .. i
		e.Texture = TEX[pe.tex] or VfxIds.SPARK
		e.Color = ColorSequence.new(Color3.fromHex(pe.color))
		e.Rate = pe.rate
		e.Lifetime = NumberRange.new(pe.life * 0.7, pe.life)
		e.Speed = NumberRange.new(pe.speed * 0.5, pe.speed)
		e.SpreadAngle = Vector2.new(180, 180)
		if pe.up then
			e.Acceleration = Vector3.new(0, 2.5, 0)
		end
		local size = if pe.aura then pe.size * 1.6 else pe.size
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.25, size),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Transparency = NumberSequence.new(if pe.aura then 0.15 else 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-90, 90)
		e.LightEmission = 1
		e.LightInfluence = 0
		if pe.aura then
			e.Shape = Enum.ParticleEmitterShape.Sphere
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		end
		e.Parent = host
	end

	model.Parent = root
	table.insert(report, string.format("%s: %d części, błąd osi %.3f", itemId, count, maxErr))
end
table.sort(report)
return table.concat(report, "\n")
