--[[
	Config — every tunable number, action, piece of furniture and NPC lives here.
	Both server and client read this module, so UI text always matches game rules.

	Need values run 0..100 where HIGHER IS BETTER (100 = fully satisfied).
]]

local C = Color3.fromRGB

local Config = {}

Config.GameName = "Bahay Buhay"
Config.Version = "0.1.0"

Config.StartingPesos = 1000 -- "puhunan" for new players
Config.DayLengthMinutes = 14 -- real-time minutes per in-game day
Config.StartClockTime = 7 -- 7:00 AM
Config.MorningHour = 6 -- bills are collected and a new "Araw" begins
Config.AutosaveSeconds = 120
Config.DataStoreName = "BahayBuhay_v1"

Config.WalkSpeed = 16
Config.TiredWalkSpeed = 9

-- Building
Config.LotHalfSize = 27 -- furniture must be within ±27 studs of the lot centre
Config.MaxBuildHeight = 14
Config.MaxFurniturePerLot = 40
Config.SellRefund = 0.6

-- Bills ("Bayarin sa kuryente at tubig") charged every morning
Config.BillBase = 25
Config.BillPerFurniture = 5

--------------------------------------------------------------------------
-- NEEDS
--------------------------------------------------------------------------
Config.NeedOrder = { "Hunger", "Energy", "Hygiene", "Fun", "Social", "Bladder" }

Config.Needs = {
	Hunger = {
		label = "Kabusugan",
		english = "Hunger",
		icon = "🍚",
		decayPerMinute = 11,
		color = C(242, 153, 74),
		lowText = "Kumakalam na ang sikmura mo! Kumain ka na.",
	},
	Energy = {
		label = "Lakas",
		english = "Energy",
		icon = "⚡",
		decayPerMinute = 7,
		color = C(250, 210, 70),
		lowText = "Antok na antok ka na. Matulog ka muna.",
	},
	Hygiene = {
		label = "Kalinisan",
		english = "Hygiene",
		icon = "🧼",
		decayPerMinute = 6,
		color = C(110, 190, 240),
		lowText = "Medyo amoy-araw ka na... Maligo ka na!",
	},
	Fun = {
		label = "Saya",
		english = "Fun",
		icon = "🎉",
		decayPerMinute = 9,
		color = C(235, 110, 180),
		lowText = "Nabo-bore ka na. Maglibang ka naman!",
	},
	Social = {
		label = "Pakikisama",
		english = "Social",
		icon = "💬",
		decayPerMinute = 7,
		color = C(150, 120, 240),
		lowText = "Nalulungkot ka. Makipagkwentuhan ka sa kapitbahay!",
	},
	Bladder = {
		label = "Banyo",
		english = "Bladder",
		icon = "🚽",
		decayPerMinute = 14,
		color = C(120, 210, 150),
		lowText = "Ihing-ihi ka na! Hanapin ang CR!",
	},
}

-- Mood is derived from the average of all needs. payMult scales job income.
Config.Moods = {
	{ min = 75, label = "Masayang-masaya", color = C(80, 220, 120), payMult = 1.2 },
	{ min = 55, label = "Ayos lang", color = C(190, 230, 90), payMult = 1.0 },
	{ min = 35, label = "Medyo malungkot", color = C(245, 180, 60), payMult = 0.9 },
	{ min = -1, label = "Pagod at stressed", color = C(235, 80, 70), payMult = 0.75 },
}

function Config.getMood(average: number)
	for _, mood in Config.Moods do
		if average >= mood.min then
			return mood
		end
	end
	return Config.Moods[#Config.Moods]
end

--------------------------------------------------------------------------
-- SKILLS (Kasanayan)
--------------------------------------------------------------------------
Config.SkillOrder = {
	"Pagluluto", "Pagkanta", "Basketball", "Pangingisda", "Pagmamaneho", "Pagtitinda",
	"Pagsasaka", "Pagkakarpintero", "Komunikasyon",
}
Config.Skills = {
	Pagluluto = { label = "Pagluluto", english = "Cooking", icon = "🍳" },
	Pagkanta = { label = "Pagkanta", english = "Singing", icon = "🎤" },
	Basketball = { label = "Basketball", english = "Basketball", icon = "🏀" },
	Pangingisda = { label = "Pangingisda", english = "Fishing", icon = "🎣" },
	Pagmamaneho = { label = "Pagmamaneho", english = "Driving", icon = "🚌" },
	Pagtitinda = { label = "Pagtitinda", english = "Selling", icon = "🧺" },
	Pagsasaka = { label = "Pagsasaka", english = "Farming", icon = "🌾" },
	Pagkakarpintero = { label = "Pagkakarpintero", english = "Construction", icon = "🔨" },
	Komunikasyon = { label = "Komunikasyon", english = "Communication", icon = "🎧" },
}
Config.XpPerLevel = 25
Config.MaxSkillLevel = 10
Config.SkillEffectBonus = 0.06 -- +6% need gain per level on skillBoost actions
Config.SkillPayBonus = 0.08 -- +8% pay per level on payBoost jobs

function Config.skillLevel(xp: number?)
	return math.min(Config.MaxSkillLevel, math.floor((xp or 0) / Config.XpPerLevel))
end

--------------------------------------------------------------------------
-- RELATIONSHIPS (Relasyon)
--------------------------------------------------------------------------
Config.RelationshipLevels = {
	{ min = 85, label = "Parang Kapamilya" },
	{ min = 60, label = "Matalik na Kaibigan" },
	{ min = 30, label = "Kaibigan" },
	{ min = 10, label = "Kakilala" },
	{ min = -1, label = "Hindi pa Kilala" },
}
Config.RelationshipDailyDecay = 2

function Config.relationshipLabel(value: number?)
	value = value or 0
	for _, level in Config.RelationshipLevels do
		if value >= level.min then
			return level.label
		end
	end
	return Config.RelationshipLevels[#Config.RelationshipLevels].label
end

--------------------------------------------------------------------------
-- ACTIONS
--	label         : menu text
--	verb          : progress-bar text while doing it
--	bubble        : emoji thought-bubble shown over the head
--	duration      : seconds
--	cost / pay    : pesos spent up-front / earned over the duration
--	effects       : total need change over the full duration
--	pose          : "stand" (default) or "lie"
--	hours         : {open, close} in-game hours when the action is allowed
--	skill/skillXp : skill trained and xp gained for a full run
--	skillBoost    : positive effects scale with the skill level
--	payBoost      : pay scales with the skill level
--	socialNearby  : extra Social gained if another player is within 18 studs
--	relationship  : relationship points with the NPC on completion
--	doneMessages  : one is picked at random when finished
--	doneHook      : special completion logic ("VideokeScore", "Fishing")
--------------------------------------------------------------------------
Config.Actions = {
	-- Tulugan
	Matulog = { label = "Matulog", verb = "Natutulog", bubble = "💤", duration = 30, pose = "lie",
		effects = { Energy = 85 }, doneMessages = { "Ang sarap ng tulog mo!" } },
	MatulogKama = { label = "Matulog sa kama", verb = "Natutulog", bubble = "💤", duration = 30, pose = "lie",
		effects = { Energy = 100, Fun = 5 }, doneMessages = { "Gising na! Ang himbing ng tulog mo." } },
	Idlip = { label = "Umidlip", verb = "Umiidlip", bubble = "😴", duration = 12, pose = "lie",
		effects = { Energy = 30 } },
	Nahimatay = { label = "Bumagsak sa pagod", verb = "Nakatulog sa sahig", bubble = "😵", duration = 15, pose = "lie",
		effects = { Energy = 35, Fun = -10, Hygiene = -5 }, special = true },

	-- Kusina
	LutoSinangag = { label = "Magluto ng Sinangag at Itlog", verb = "Nagluluto ng sinangag", bubble = "🍳", duration = 8,
		cost = 30, effects = { Hunger = 40 }, skill = "Pagluluto", skillXp = 3, skillBoost = true,
		doneMessages = { "Ang bango ng sinangag na may bawang!" } },
	LutoAdobo = { label = "Magluto ng Adobo", verb = "Nagluluto ng adobo", bubble = "🍗", duration = 12,
		cost = 60, effects = { Hunger = 65 }, skill = "Pagluluto", skillXp = 5, skillBoost = true,
		doneMessages = { "Adobo na naman? Pero ang sarap pa rin!", "Tamang-tama ang asim at alat ng adobo mo." } },
	LutoPancit = { label = "Magluto ng Pancit Bihon", verb = "Nagluluto ng pancit", bubble = "🍜", duration = 10,
		cost = 50, effects = { Hunger = 55, Social = 5 }, skill = "Pagluluto", skillXp = 4, skillBoost = true,
		doneMessages = { "Pancit para humaba ang buhay!" } },
	LutoSinigang = { label = "Magluto ng Sinigang", verb = "Nagluluto ng sinigang", bubble = "🍲", duration = 14,
		cost = 80, effects = { Hunger = 75, Fun = 5 }, skill = "Pagluluto", skillXp = 6, skillBoost = true,
		doneMessages = { "Ang asim-asim ng sinigang! Panalo." } },
	Merienda = { label = "Mag-merienda", verb = "Nagme-merienda", bubble = "🍞", duration = 8,
		cost = 20, effects = { Hunger = 25, Social = 5 } },

	-- Banyo
	Maligo = { label = "Maligo (timba at tabo)", verb = "Naliligo", bubble = "🚿", duration = 12,
		effects = { Hygiene = 90, Energy = 5 }, doneMessages = { "Presko ka na ulit!" } },
	MagCR = { label = "Gumamit ng CR", verb = "Nasa CR", bubble = "🚽", duration = 6,
		effects = { Bladder = 100, Hygiene = -3 } },
	Maghilamos = { label = "Maghilamos sa poso", verb = "Naghihilamos", bubble = "💧", duration = 5,
		effects = { Hygiene = 25, Energy = 5 } },

	-- Libangan
	Teleserye = { label = "Manood ng teleserye", verb = "Nanonood ng teleserye", bubble = "📺", duration = 20,
		effects = { Fun = 45, Energy = -3 },
		doneMessages = { "Grabe ang twist sa teleserye ngayong gabi!", "Iyak ka nang iyak sa episode." } },
	Balita = { label = "Manood ng balita", verb = "Nanonood ng balita", bubble = "📰", duration = 10,
		effects = { Fun = 15, Social = 5 } },
	Kumanta = { label = "Kumanta sa videoke", verb = "Bumibirit sa videoke", bubble = "🎤", duration = 15,
		effects = { Fun = 45, Energy = -5 }, socialNearby = 20, skill = "Pagkanta", skillXp = 5, skillBoost = true,
		doneHook = "VideokeScore" },
	Basketball = { label = "Maglaro ng basketball", verb = "Nagbabasketball", bubble = "🏀", duration = 18,
		effects = { Fun = 50, Energy = -15, Hygiene = -15, Hunger = -5 }, socialNearby = 15,
		skill = "Basketball", skillXp = 6,
		doneMessages = { "Swak! Three points!", "Ang galing ng crossover mo!", "Muntik na ang buzzer-beater!" } },
	Magduyan = { label = "Magduyan", verb = "Nagduduyan", bubble = "🌴", duration = 15, pose = "lie",
		effects = { Energy = 25, Fun = 20 } },
	Magpahangin = { label = "Magpahangin", verb = "Nagpapahangin", bubble = "🌀", duration = 8,
		effects = { Energy = 10, Fun = 10 } },
	Magdasal = { label = "Magdasal", verb = "Nagdarasal", bubble = "🙏", duration = 8,
		effects = { Fun = 15, Social = 5 } },
	Diligan = { label = "Diligan ang sampaguita", verb = "Nagdidilig", bubble = "🌼", duration = 5,
		effects = { Fun = 10 } },
	Magbihis = { label = "Magbihis", verb = "Nagbibihis", bubble = "👕", duration = 5,
		effects = { Hygiene = 10, Fun = 5 } },
	Magsimba = { label = "Magsimba", verb = "Nagsisimba", bubble = "⛪", duration = 15, hours = { 6, 19 },
		effects = { Fun = 15, Social = 25 } },

	-- Sari-sari store ni Aling Nena
	BiliPandesal = { label = "Pandesal", verb = "Kumakain ng pandesal", bubble = "🥖", duration = 4,
		cost = 10, effects = { Hunger = 12 } },
	BiliTuron = { label = "Turon", verb = "Kumakain ng turon", bubble = "🍌", duration = 4,
		cost = 15, effects = { Hunger = 15, Fun = 3 } },
	BiliBalut = { label = "Balut", verb = "Humihigop ng balut", bubble = "🥚", duration = 5,
		cost = 20, effects = { Hunger = 18, Fun = 5 } },
	BiliKakanin = { label = "Kakanin (puto at kutsinta)", verb = "Kumakain ng kakanin", bubble = "🍡", duration = 5,
		cost = 25, effects = { Hunger = 22 } },
	BiliPalamig = { label = "Palamig (sago't gulaman)", verb = "Umiinom ng palamig", bubble = "🥤", duration = 4,
		cost = 15, effects = { Hunger = 5, Fun = 8, Energy = 5 } },

	-- Karinderya (turo-turo)
	Tapsilog = { label = "Tapsilog", verb = "Kumakain ng tapsilog", bubble = "🍳", duration = 10,
		cost = 90, effects = { Hunger = 70, Energy = 5 } },
	Lugaw = { label = "Lugaw na may tokwa't baboy", verb = "Humihigop ng lugaw", bubble = "🥣", duration = 8,
		cost = 35, effects = { Hunger = 35, Energy = 10 } },
	HaloHalo = { label = "Halo-halo", verb = "Kumakain ng halo-halo", bubble = "🍧", duration = 8,
		cost = 60, effects = { Hunger = 20, Fun = 20 } },

	-- Trabaho (jobs)
	DriveJeep = { label = "Mamasada ng jeep", verb = "Namamasada", bubble = "🚌", duration = 30, job = true,
		pay = 220, hours = { 5, 22 }, effects = { Energy = -18, Fun = -8, Hunger = -10, Hygiene = -8 },
		skill = "Pagmamaneho", skillXp = 6, payBoost = true, profession = "Drayber",
		doneMessages = { "Bayad po! Ang daming pasahero ngayon.", "Para po! Tapos na ang biyahe mo." } },
	Magtinda = { label = "Magtinda sa palengke", verb = "Nagtitinda", bubble = "🧺", duration = 25, job = true,
		pay = 160, hours = { 4, 18 }, effects = { Energy = -12, Fun = -5, Hunger = -8, Social = 10 },
		skill = "Pagtitinda", skillXp = 6, payBoost = true, profession = "Tindero",
		doneMessages = { "Suki ka na ng mga mamimili!", "Ubos ang paninda mo ngayon!" } },
	Mangisda = { label = "Mangisda sa bangka", verb = "Nangingisda", bubble = "🎣", duration = 28, job = true,
		pay = 190, effects = { Energy = -15, Hygiene = -12, Hunger = -10, Fun = 5 },
		skill = "Pangingisda", skillXp = 6, payBoost = true, doneHook = "Fishing", profession = "Mangingisda" },
	Magsaka = { label = "Magtanim at mag-ani sa palayan", verb = "Nagsasaka", bubble = "🌾", duration = 28, job = true,
		pay = 170, hours = { 5, 18 }, effects = { Energy = -18, Hygiene = -14, Hunger = -10, Fun = -3 },
		skill = "Pagsasaka", skillXp = 6, payBoost = true, profession = "Magsasaka",
		doneMessages = { "Ang ganda ng ani ngayon!", "Nakapagtanim ka ng isang pitak ng palay." } },
	Magkarpintero = { label = "Magtrabaho sa construction", verb = "Nagkakarpintero", bubble = "🔨", duration = 30, job = true,
		pay = 230, hours = { 6, 18 }, effects = { Energy = -22, Hygiene = -15, Hunger = -12, Fun = -5 },
		skill = "Pagkakarpintero", skillXp = 6, payBoost = true, profession = "Karpintero",
		doneMessages = { "Tapos na ang pader na ginagawa n'yo!", "Sabi ni foreman: 'Ayos ang trabaho mo!'" } },
	CallCenter = { label = "Mag-shift sa call center", verb = "Sumasagot ng tawag", bubble = "🎧", duration = 30, job = true,
		pay = 320, hours = { 18, 6 }, effects = { Energy = -20, Fun = -12, Social = -5, Hunger = -8 },
		skill = "Komunikasyon", skillXp = 6, payBoost = true, profession = "CallCenter",
		doneMessages = { "Na-resolve mo ang 40 na tawag! \"Thank you for calling!\"", "Graveyard shift na naman... pero sulit ang sweldo." } },
	Magturo = { label = "Magturo sa klase", verb = "Nagtuturo", bubble = "📚", duration = 28, job = true,
		pay = 260, hours = { 7, 17 }, effects = { Energy = -15, Fun = -5, Social = 10, Hunger = -8 },
		skill = "Komunikasyon", skillXp = 5, payBoost = true, profession = "Guro",
		doneMessages = { "\"Good morning, Ma'am/Sir!\" Ang kukulit ng mga estudyante mo." } },
	MagNars = { label = "Mag-duty bilang nars", verb = "Nagdu-duty", bubble = "🩺", duration = 30, job = true,
		pay = 300, effects = { Energy = -20, Hygiene = -8, Hunger = -10, Social = 5 },
		skill = "Komunikasyon", skillXp = 5, payBoost = true, profession = "Nars",
		doneMessages = { "Salamat sa pag-aalaga, nars!" } },
	Manggamot = { label = "Manggamot ng pasyente", verb = "Nanggagamot", bubble = "🥼", duration = 30, job = true,
		pay = 600, effects = { Energy = -25, Fun = -8, Hunger = -12 },
		skill = "Komunikasyon", skillXp = 5, payBoost = true, profession = "Doktor",
		doneMessages = { "Naligtas mo ang isang pasyente. Proud si Mama!" } },
	Maglayag = { label = "Sumampa sa barko", verb = "Naglalayag", bubble = "⚓", duration = 35, job = true,
		pay = 500, effects = { Energy = -20, Social = -15, Fun = -10, Hunger = -10 },
		skill = "Pangingisda", skillXp = 4, payBoost = true, profession = "Seaman",
		doneMessages = { "Nakauwi ka galing sa biyahe sa dagat." } },

	-- Kapitbahay (NPC)
	Kwentuhan = { label = "Makipagkwentuhan", verb = "Nakikipagkwentuhan", bubble = "💬", duration = 10,
		effects = { Social = 35, Fun = 5 }, relationship = 6 },
	Chismis = { label = "Makichismis", verb = "Nakikichismis", bubble = "🤭", duration = 10,
		effects = { Social = 30, Fun = 12 }, relationship = 4,
		doneMessages = { "Ay, totoo ba 'yan?!", "Huwag mong ipagsasabi ha... sa'yo lang 'to." } },
	Magmano = { label = "Magmano (Mano po!)", verb = "Nagmamano", bubble = "🙏", duration = 4,
		effects = { Social = 15, Fun = 5 }, relationship = 10,
		doneMessages = { "\"Kaawaan ka ng Diyos, apo.\"" } },
}

--------------------------------------------------------------------------
-- STATIONS — anything you can interact with. A model's StationId attribute
-- points here. One action = starts immediately; several = opens a menu.
--------------------------------------------------------------------------
Config.Stations = {
	-- Furniture
	Banig = { title = "Banig", prompt = "Humiga", actions = { "Matulog", "Idlip" } },
	Kama = { title = "Kamang Kawayan", prompt = "Humiga", actions = { "MatulogKama", "Idlip" } },
	Kalan = { title = "Kalan", prompt = "Magluto",
		actions = { "LutoSinangag", "LutoAdobo", "LutoPancit", "LutoSinigang" } },
	Hapag = { title = "Hapag-Kainan", prompt = "Umupo", actions = { "Merienda" } },
	Paliguan = { title = "Timba at Tabo", prompt = "Maligo", actions = { "Maligo" } },
	Inidoro = { title = "Inidoro", prompt = "Gamitin", actions = { "MagCR" } },
	TV = { title = "TV", prompt = "Manood", actions = { "Teleserye", "Balita" } },
	Videoke = { title = "Videoke", prompt = "Kumanta", actions = { "Kumanta" } },
	Duyan = { title = "Duyan", prompt = "Magduyan", actions = { "Magduyan" } },
	Bentilador = { title = "Bentilador", prompt = "Gamitin", actions = { "Magpahangin" } },
	Altar = { title = "Munting Altar", prompt = "Magdasal", actions = { "Magdasal" } },
	Halaman = { title = "Sampaguita", prompt = "Diligan", actions = { "Diligan" } },
	Aparador = { title = "Aparador", prompt = "Magbihis", actions = { "Magbihis" } },
	Parol = { title = "Parol", actions = {} },

	-- Public places
	SariSari = { title = "Sari-Sari Store ni Aling Nena", prompt = "Bumili",
		actions = { "BiliPandesal", "BiliTuron", "BiliBalut", "BiliKakanin", "BiliPalamig" } },
	Karinderya = { title = "Karinderya", prompt = "Kumain", actions = { "Tapsilog", "Lugaw", "HaloHalo" } },
	Basketball = { title = "Basketball Court", prompt = "Maglaro", actions = { "Basketball" } },
	Jeepney = { title = "Jeepney", prompt = "Mamasada", actions = { "DriveJeep" } },
	Palengke = { title = "Puwesto sa Palengke", prompt = "Magtinda", actions = { "Magtinda" } },
	Bangka = { title = "Bangka", prompt = "Mangisda", actions = { "Mangisda" } },
	Simbahan = { title = "Simbahan", prompt = "Magsimba", actions = { "Magsimba" } },
	Poso = { title = "Poso", prompt = "Maghilamos", actions = { "Maghilamos" } },
	Palayan = { title = "Palayan", prompt = "Magsaka", actions = { "Magsaka" } },
	Construction = { title = "Construction Site", prompt = "Magtrabaho", actions = { "Magkarpintero" } },
	BPO = { title = "Call Center", prompt = "Mag-shift", actions = { "CallCenter" } },
	Ospital = { title = "Ospital", prompt = "Mag-duty", actions = { "MagNars", "Manggamot" } },
	RHU = { title = "Rural Health Unit", prompt = "Mag-duty", actions = { "MagNars" } },
	Paaralan = { title = "Paaralan", prompt = "Magturo", actions = { "Magturo" } },
	Pantalan = { title = "Pantalan", prompt = "Sumampa", actions = { "Maglayag" } },
	PESO = { title = "PESO Office", prompt = "Maghanap ng trabaho", actions = {}, special = "Career" },

	-- NPCs
	NPC_Kapitbahay = { title = "Kapitbahay", prompt = "Kausapin", actions = { "Kwentuhan", "Chismis" } },
	NPC_Lola = { title = "Lola", prompt = "Kausapin", actions = { "Magmano", "Kwentuhan" } },
}

--------------------------------------------------------------------------
-- FURNITURE CATALOG (Build mode). `id` is both the Models builder and StationId.
--------------------------------------------------------------------------
Config.Furniture = {
	{ id = "Banig", name = "Banig", icon = "🧺", price = 150, category = "Tulugan",
		desc = "Hinabing banig para sa mahimbing na tulog." },
	{ id = "Kama", name = "Kamang Kawayan", icon = "🛏️", price = 650, category = "Tulugan",
		desc = "Mas masarap matulog, may dagdag na saya." },
	{ id = "Kalan", name = "Kalan", icon = "🔥", price = 400, category = "Kusina",
		desc = "Magluto ng adobo, sinigang, at iba pa." },
	{ id = "Hapag", name = "Hapag-Kainan", icon = "🍽️", price = 350, category = "Kusina",
		desc = "Sabay-sabay kumain ang pamilya." },
	{ id = "Paliguan", name = "Timba at Tabo", icon = "🪣", price = 120, category = "Banyo",
		desc = "Ang tunay na Pinoy shower." },
	{ id = "Inidoro", name = "Inidoro", icon = "🚽", price = 300, category = "Banyo",
		desc = "Para hindi ka na tumakbo sa kapitbahay." },
	{ id = "TV", name = "TV (de-kahon)", icon = "📺", price = 900, category = "Libangan",
		desc = "Teleserye gabi-gabi." },
	{ id = "Videoke", name = "Videoke", icon = "🎤", price = 1500, category = "Libangan",
		desc = "Birit hanggang madaling-araw." },
	{ id = "Duyan", name = "Duyan", icon = "🌴", price = 250, category = "Libangan",
		desc = "Pahinga sa ilalim ng hangin." },
	{ id = "Bentilador", name = "Bentilador", icon = "🌀", price = 280, category = "Gamit",
		desc = "Panlaban sa init ng tag-araw." },
	{ id = "Aparador", name = "Aparador", icon = "🚪", price = 450, category = "Gamit",
		desc = "Lalagyan ng damit, may salamin pa." },
	{ id = "Altar", name = "Munting Altar", icon = "🕯️", price = 200, category = "Dekorasyon",
		desc = "Tahimik na sulok para magdasal." },
	{ id = "Halaman", name = "Paso ng Sampaguita", icon = "🌼", price = 80, category = "Dekorasyon",
		desc = "Ang pambansang bulaklak." },
	{ id = "Parol", name = "Parol", icon = "⭐", price = 120, category = "Dekorasyon",
		desc = "Ilaw ng Paskong Pinoy. Umiilaw sa gabi." },
}

Config.FurnitureById = {}
for _, item in Config.Furniture do
	Config.FurnitureById[item.id] = item
end

-- Starting furniture for a brand-new player, relative to their lot origin. r = rotation in degrees.
-- inHouse = true: y is measured from the house floor (kubo floor is 4 high, bungalow 0.6).
Config.StarterFurniture = {
	{ id = "Banig", x = -10, y = 0, z = -15.5, r = 0, inHouse = true },
	{ id = "Kalan", x = 9, y = 0, z = -18, r = 0, inHouse = true },
	{ id = "Paliguan", x = 11, y = 0, z = -1, r = 180, inHouse = true },
	{ id = "Inidoro", x = 13, y = 0, z = -9, r = 270, inHouse = true },
	{ id = "Halaman", x = -9, y = 0, z = 12, r = 0 },
}

-- House types. Every house shares the same footprint (lot-local), so furniture fits in any of them.
Config.HouseTypes = {
	Kubo = { label = "Bahay Kubo", floorY = 4 },
	Bungalow = { label = "Bungalow", floorY = 0.6 },
}
Config.HouseFootprint = { minX = -15, maxX = 15, minZ = -20, maxZ = 4 }

function Config.insideHouse(x: number, z: number): boolean
	local f = Config.HouseFootprint
	return x >= f.minX and x <= f.maxX and z >= f.minZ and z <= f.maxZ
end

--------------------------------------------------------------------------
-- NPCs (mga kapitbahay)
--------------------------------------------------------------------------
Config.NPCs = {
	{ id = "AlingNena", name = "Aling Nena", station = "NPC_Kapitbahay", home = Vector3.new(-30, 0.3, -24),
		skin = C(198, 140, 104), shirt = C(232, 93, 117), pants = C(70, 60, 100), accessory = "Apron", walkSpeed = 7,
		lines = { "Uy, kumain ka na ba?", "May bagong dating na pandesal!", "Pautang? Lista ko na lang ha." } },
	{ id = "MangTonyo", name = "Mang Tonyo", station = "NPC_Kapitbahay", home = Vector3.new(12, 0.3, 14),
		skin = C(165, 110, 75), shirt = C(240, 240, 230), pants = C(60, 75, 110), accessory = "Salakot", walkSpeed = 8,
		lines = { "Ang init ngayon, 'no?", "Laro tayo mamaya sa court!", "Noong kabataan ko..." } },
	{ id = "LolaRemedios", name = "Lola Remedios", station = "NPC_Lola", home = Vector3.new(-10, 0.3, 20),
		skin = C(205, 155, 120), shirt = C(130, 160, 210), pants = C(90, 80, 120), accessory = "Bun", walkSpeed = 5,
		lines = { "Apo, nagsimba ka na ba?", "Mag-ingat ka sa daan.", "Kumain ka nang marami, ang payat mo!" } },
	{ id = "KuyaJun", name = "Kuya Jun", station = "NPC_Kapitbahay", home = Vector3.new(100, 0.2, 16),
		skin = C(150, 100, 68), shirt = C(240, 200, 60), pants = C(50, 50, 60), accessory = "Towel", walkSpeed = 8,
		lines = { "Bayan! Bayan! Sakay na!", "Barya lang po sa umaga.", "Traffic na naman sa kanto." } },
	{ id = "AteJoy", name = "Ate Joy", station = "NPC_Kapitbahay", home = Vector3.new(3030, 0.3, 26),
		skin = C(200, 145, 110), shirt = C(60, 90, 160), pants = C(40, 40, 50), accessory = "Towel", walkSpeed = 9,
		lines = { "Kakagaling ko lang sa night shift...", "Ang mahal ng upa dito sa Metro!", "Uuwi ako sa probinsya sa Pasko." } },
	{ id = "TatayAmbo", name = "Tatay Ambo", station = "NPC_Lola", home = Vector3.new(5900, 40.3, -28),
		skin = C(150, 98, 64), shirt = C(235, 235, 225), pants = C(70, 60, 50), accessory = "Salakot", walkSpeed = 5,
		lines = { "Sana umulan na para sa palay.", "Ang mga anak ko, nasa Maynila na lahat.", "Masarap ang buhay sa bukid, apo." } },
}

Config.NPCById = {}
for _, npc in Config.NPCs do
	Config.NPCById[npc.id] = npc
end

--------------------------------------------------------------------------
-- IDENTITY — "Ikot ng Kapalaran". Rolled once when a player first joins.
-- Three privilege metrics, each with 3 tiers (1 = low, 2 = middle, 3 = high).
-- None of these are shown to other players. Only AGE is public.
--------------------------------------------------------------------------
Config.StartAge = 18 -- Phase 0. Playable childhood (start at 7) arrives in Phase 1.
Config.DaysPerYear = 3 -- in-game days (while you're online) per year of age

Config.MetricOrder = { "Yaman", "Swerte", "DNA" }
Config.Metrics = {
	Yaman = {
		label = "Yaman", english = "Wealth", icon = "💰",
		tiers = { { label = "Mahirap", weight = 30 }, { label = "Katamtaman", weight = 45 }, { label = "Maykaya", weight = 25 } },
	},
	Swerte = {
		label = "Swerte", english = "Luck", icon = "🍀",
		tiers = { { label = "Malas", weight = 30 }, { label = "Karaniwan", weight = 45 }, { label = "Swerte", weight = 25 } },
	},
	DNA = {
		label = "DNA", english = "Talent", icon = "🧬",
		tiers = { { label = "Karaniwan", weight = 30 }, { label = "Magaling", weight = 45 }, { label = "Henyo", weight = 25 } },
	},
}

-- What each tier does (index = tier).
Config.YamanEffects = {
	startingPesos = { 400, 1000, 3000 },
	dailyAllowance = { 0, 60, 200 }, -- "padala" from your parents every morning
	socialDecayMult = { 0.8, 1, 1 }, -- Mahirap perk: "Matibay ang samahan" — tight community ties
}
Config.SwerteEffects = {
	goodEventMult = { 0.7, 1, 1.4 },
	badEventMult = { 1.6, 1, 0.6 },
	xpMult = { 1.1, 1, 1 }, -- Malas perk: "Natututo sa hirap" — setbacks teach you faster
}
Config.DNAEffects = {
	xpMult = { 1.0, 1.15, 1.3 },
	talentBonus = 0.25, -- extra xp in your one natural talent skill
}

function Config.tierLabel(metric: string, tier: number?): string
	local m = Config.Metrics[metric]
	local t = m and m.tiers[tier or 2]
	return if t then t.label else "?"
end

-- Combined skill xp multiplier for a player (reads replicated attributes).
function Config.xpMultiplier(source: Instance, skill: string?): number
	local mult = Config.DNAEffects.xpMult[source:GetAttribute("DNA") or 2] or 1
	mult *= Config.SwerteEffects.xpMult[source:GetAttribute("Swerte") or 2] or 1
	if skill and source:GetAttribute("Talent") == skill then
		mult *= 1 + Config.DNAEffects.talentBonus
	end
	return mult
end

--------------------------------------------------------------------------
-- CITIES — all three live in ONE shared world, connected by road.
--------------------------------------------------------------------------
Config.CityOrder = { "BaybayAlon", "MetroDakila", "SanBukid" }
Config.Cities = {
	BaybayAlon = {
		name = "Baybay Alon", icon = "🌊", kind = "Bayan sa tabing-dagat", weight = 30,
		costMult = 1.0, payMult = 1.0, house = "Kubo",
		origin = Vector3.new(0, 0, 0), spawn = Vector3.new(-2, 3, -22),
	},
	MetroDakila = {
		name = "Metro Dakila", icon = "🏙️", kind = "Siyudad", weight = 40,
		costMult = 1.4, payMult = 1.35, house = "Bungalow",
		origin = Vector3.new(3000, 0, 0), spawn = Vector3.new(3000, 3, -20),
	},
	SanBukid = {
		name = "San Bukid", icon = "🌾", kind = "Bayan sa bukid", weight = 30,
		costMult = 0.85, payMult = 0.9, house = "Kubo",
		origin = Vector3.new(6000, 40, 0), spawn = Vector3.new(6000, 43, -20),
	},
}

function Config.city(id: string?)
	return Config.Cities[id or ""] or Config.Cities.BaybayAlon
end

-- Price of an action at a station in a given city.
function Config.scaledCost(def, cityId: string?): number
	return math.floor((def.cost or 0) * Config.city(cityId).costMult + 0.5)
end

--------------------------------------------------------------------------
-- EDUCATION & PROFESSIONS (10)
--------------------------------------------------------------------------
Config.Education = {
	none = { label = "Walang natapos", rank = 0 },
	highschool = { label = "High school graduate", rank = 1 },
	vocational = { label = "Vocational / TechVoc", rank = 1 },
	college = { label = "College graduate", rank = 2 },
	maritime = { label = "Maritime graduate", rank = 2 },
	medicine = { label = "Doctor of Medicine", rank = 3 },
}
Config.StartEducation = "highschool"

function Config.meetsEducation(have: string?, need: string?): boolean
	need = need or "none"
	have = have or "none"
	if need == "none" then
		return true
	elseif need == "highschool" then
		return (Config.Education[have] or Config.Education.none).rank >= 1
	elseif need == "college" then
		return have == "college" or have == "medicine"
	end
	return have == need
end

Config.ProfessionOrder = {
	"Mangingisda", "Magsasaka", "Tindero", "Drayber", "Karpintero",
	"Guro", "Nars", "CallCenter", "Seaman", "Doktor",
}
Config.Professions = {
	Mangingisda = { label = "Mangingisda", english = "Fisherfolk", icon = "🎣", education = "none", job = "Mangisda", cities = { "BaybayAlon" } },
	Magsasaka = { label = "Magsasaka", english = "Farmer", icon = "🌾", education = "none", job = "Magsaka", cities = { "BaybayAlon", "SanBukid" } },
	Tindero = { label = "Tindero / Negosyante", english = "Vendor", icon = "🧺", education = "none", job = "Magtinda", cities = { "BaybayAlon", "MetroDakila", "SanBukid" } },
	Drayber = { label = "Drayber", english = "Driver", icon = "🚌", education = "none", job = "DriveJeep", cities = { "BaybayAlon", "MetroDakila", "SanBukid" } },
	Karpintero = { label = "Karpintero / Construction", english = "Construction", icon = "🔨", education = "none", job = "Magkarpintero", cities = { "BaybayAlon", "MetroDakila", "SanBukid" } },
	Guro = { label = "Guro", english = "Teacher", icon = "📚", education = "college", job = "Magturo", cities = { "BaybayAlon", "MetroDakila", "SanBukid" } },
	Nars = { label = "Nars", english = "Nurse", icon = "🩺", education = "college", job = "MagNars", cities = { "BaybayAlon", "MetroDakila", "SanBukid" } },
	CallCenter = { label = "Call Center Agent", english = "BPO", icon = "🎧", education = "highschool", job = "CallCenter", cities = { "MetroDakila" } },
	Seaman = { label = "Seaman", english = "Seafarer", icon = "⚓", education = "maritime", job = "Maglayag", cities = { "BaybayAlon" } },
	Doktor = { label = "Doktor", english = "Doctor", icon = "🥼", education = "medicine", job = "Manggamot", cities = { "MetroDakila" } },
}

-- Parents' jobs, chosen from [hometown][Yaman tier]. Parents are never shown as characters,
-- only through text messages and story notifications.
Config.ParentJobs = {
	BaybayAlon = { { "Mangingisda", "Tindero" }, { "Guro", "Drayber" }, { "Seaman", "Nars" } },
	MetroDakila = { { "Drayber", "Tindero" }, { "CallCenter", "Guro" }, { "Doktor", "Tindero" } },
	SanBukid = { { "Magsasaka", "Tindero" }, { "Guro", "Magsasaka" }, { "Tindero", "Nars" } },
}

Config.ParentIntro = {
	"📱 Mama: Anak, kahit mahirap ang buhay natin, nandito lang kami. Kayod lang!",
	"📱 Papa: Ingat ka palagi, anak. Tumawag ka kung may kailangan ka.",
	"📱 Mama: Anak, huwag mong sasayangin ang mga oportunidad mo, ha?",
}

--------------------------------------------------------------------------
-- TRAVEL — provincial buses between cities, with surprise events on the way.
--------------------------------------------------------------------------
Config.Routes = {
	{ id = "Highway", a = "BaybayAlon", b = "MetroDakila", fare = 60, tripSeconds = 90, dwellSeconds = 40, buses = 2,
		color = C(210, 55, 50) },
	{ id = "Bundok", a = "MetroDakila", b = "SanBukid", fare = 80, tripSeconds = 110, dwellSeconds = 40, buses = 2,
		color = C(40, 130, 80) },
}
Config.TripEventRolls = { 0.35, 0.7 } -- points in the trip where each passenger may get an event
Config.TripEventChance = 0.55

-- good events scale with Swerte; bad events are likelier when Malas.
-- pesos = {min, max}; negative = you lose money. %s in text is replaced by the amount.
Config.TripEvents = {
	{ id = "Barya", good = true, weight = 30, pesos = { 5, 25 }, text = "🪙 May napulot kang barya sa sahig ng bus: %s!" },
	{ id = "Ninong", good = true, weight = 10, pesos = { 100, 300 }, text = "🎁 Nakasabay mo si Ninong Boy! Inabutan ka ng %s. \"Pang-merienda mo, inaanak!\"" },
	{ id = "LostFound", good = true, weight = 12, pesos = { 50, 150 }, text = "👛 May naiwang pitaka sa upuan. Isinauli mo sa konduktor at binigyan ka ng pabuya na %s." },
	{ id = "Katabi", good = true, weight = 20, effects = { Social = 20 }, text = "💬 Nakakuwentuhan mo ang katabi mo. Ang dami n'yong pagkakapareho!" },
	{ id = "Mani", good = true, weight = 15, effects = { Hunger = 12 }, text = "🥜 Sumakay ang tindero ng mani at chicharon. Nilibre ka ng katabi mo!" },
	{ id = "Tanawin", good = true, weight = 15, effects = { Fun = 15 }, text = "🌄 Ang ganda ng tanawin sa bintana..." },
	{ id = "Idlip", good = true, weight = 15, effects = { Energy = 15 }, text = "😴 Nakaidlip ka sa biyahe. Ang sarap!" },
	{ id = "Dukot", good = false, weight = 10, pesos = { -80, -20 }, text = "😱 Nadukutan ka! Nawala ang %s. Ingat sa gamit!" },
	{ id = "Flat", good = false, weight = 12, effects = { Fun = -10 }, text = "🛞 Na-flat ang gulong ng bus. Ang tagal maghintay..." },
	{ id = "Traffic", good = false, weight = 15, effects = { Energy = -10, Fun = -5 }, text = "🚗 Grabe ang traffic sa Dakila Avenue..." },
	{ id = "Hilo", good = false, weight = 10, effects = { Fun = -10, Hunger = -5 }, text = "🤢 Nahilo ka sa biyahe. Sana nagdala ka ng kendi..." },
}

return Config
