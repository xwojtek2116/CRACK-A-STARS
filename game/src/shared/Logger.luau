--!strict
-- Logger — logi z poziomami i prefiksem modułu.
-- Poziom minimalny: w Studio "Debug", na serwerach "Info"; zmiana przez Logger.setLevel.

local RunService = game:GetService("RunService")

export type Level = "Debug" | "Info" | "Warn" | "Error"

export type Logger = {
	debug: (self: Logger, ...any) -> (),
	info: (self: Logger, ...any) -> (),
	warn: (self: Logger, ...any) -> (),
	error: (self: Logger, ...any) -> (),
}

local LEVEL_ORDER: { [Level]: number } = {
	Debug = 1,
	Info = 2,
	Warn = 3,
	Error = 4,
}

local SIDE = if RunService:IsServer() then "S" else "C"

local minLevel: Level = if RunService:IsStudio() then "Debug" else "Info"

local function emit(level: Level, prefix: string, ...: any)
	if LEVEL_ORDER[level] < LEVEL_ORDER[minLevel] then
		return
	end
	local parts = table.pack(...)
	for i = 1, parts.n do
		parts[i] = tostring(parts[i])
	end
	local message = `[CIE/{SIDE}][{prefix}] {table.concat(parts, " ", 1, parts.n)}`
	if level == "Warn" or level == "Error" then
		warn(`{level:upper()} {message}`)
	else
		print(message)
	end
end

local Logger = {}

function Logger.setLevel(level: Level)
	minLevel = level
end

function Logger.new(prefix: string): Logger
	local self = {}
	function self.debug(_: Logger, ...: any)
		emit("Debug", prefix, ...)
	end
	function self.info(_: Logger, ...: any)
		emit("Info", prefix, ...)
	end
	function self.warn(_: Logger, ...: any)
		emit("Warn", prefix, ...)
	end
	function self.error(_: Logger, ...: any)
		emit("Error", prefix, ...)
	end
	return self :: Logger
end

return Logger
