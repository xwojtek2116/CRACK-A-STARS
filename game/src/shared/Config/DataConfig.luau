--!strict
-- DataConfig — zapis danych gracza (ProfileStore): nazwa magazynu, wersja schematu, wartości startowe.
-- Zmiana schematu = podbij SCHEMA_VERSION i dopisz krok w server/Data/PlayerSchema (MIGRATIONS).

return {
	STORE_NAME = "CrackAStars_Player_v1",
	KEY_PREFIX = "User_",
	SCHEMA_VERSION = 1,

	STARTING_TOOL = "stone_pickaxe",
	STARTING_JETPACK = 1,

	-- Ustawienia gracza, które klient może zmieniać przez SetSetting.
	SETTING_KEYS = { "music", "sfx", "lowGraphics", "cameraShake" },

	SESSION_LOST_KICK = "Your save was opened on another server. Please rejoin.",
	LOAD_FAILED_KICK = "Could not load your save. Please rejoin.",
}
