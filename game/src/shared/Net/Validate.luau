--!strict
-- Validate — sprawdzanie argumentów z klienta. Predykaty (is*) i fabryki checkerów do schematów w Shared/Remotes.
-- Klient może wysłać cokolwiek (NaN, inf, fałszywe instancje, ogromne stringi) — wszystko sprawdzamy na serwerze.

export type Checker = (value: unknown) -> boolean

local UUID_PATTERN = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

local Validate = {}

function Validate.isNumberFinite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Validate.isInteger(value: unknown): boolean
	return Validate.isNumberFinite(value) and math.floor(value :: number) == value
end

function Validate.inRange(value: unknown, min: number, max: number): boolean
	return Validate.isNumberFinite(value) and (value :: number) >= min and (value :: number) <= max
end

function Validate.isString(value: unknown, maxLen: number?): boolean
	if type(value) ~= "string" then
		return false
	end
	-- utf8.len zwraca nil dla niepoprawnego UTF-8
	local length = utf8.len(value)
	return length ~= nil and length <= (maxLen or math.huge)
end

function Validate.isBoolean(value: unknown): boolean
	return type(value) == "boolean"
end

function Validate.isUuid(value: unknown): boolean
	return type(value) == "string" and string.match(value, UUID_PATTERN) ~= nil
end

function Validate.isInstanceOf(value: unknown, className: string): boolean
	return typeof(value) == "Instance" and (value :: Instance):IsA(className)
end

function Validate.isOneOf(value: unknown, options: { string }): boolean
	return type(value) == "string" and table.find(options, value) ~= nil
end

-- Fabryki checkerów do schematów argumentów (Shared/Remotes).

Validate.finite = Validate.isNumberFinite :: Checker
Validate.integer = Validate.isInteger :: Checker
Validate.boolean = Validate.isBoolean :: Checker
Validate.uuid = Validate.isUuid :: Checker

function Validate.string(maxLen: number): Checker
	return function(value)
		return Validate.isString(value, maxLen)
	end
end

function Validate.range(min: number, max: number): Checker
	return function(value)
		return Validate.inRange(value, min, max)
	end
end

function Validate.intRange(min: number, max: number): Checker
	return function(value)
		return Validate.isInteger(value) and Validate.inRange(value, min, max)
	end
end

function Validate.instanceOf(className: string): Checker
	return function(value)
		return Validate.isInstanceOf(value, className)
	end
end

function Validate.oneOf(options: { string }): Checker
	return function(value)
		return Validate.isOneOf(value, options)
	end
end

function Validate.optional(checker: Checker): Checker
	return function(value)
		return value == nil or checker(value)
	end
end

-- Tablica-lista liczb skończonych w [min, max], długość 1..maxLen, bez innych kluczy.
function Validate.numberList(maxLen: number, min: number, max: number): Checker
	return function(value)
		if type(value) ~= "table" then
			return false
		end
		local list = value :: { [any]: unknown }
		local count = 0
		for key, item in list do
			count += 1
			if type(key) ~= "number" or count > maxLen or not Validate.inRange(item, min, max) then
				return false
			end
		end
		return count >= 1 and count == #(list :: { unknown })
	end
end

-- Sprawdza listę argumentów względem schematu. Zwraca (ok, numer złego argumentu).
function Validate.args(schema: { Checker }, args: { n: number, [number]: unknown }): (boolean, number?)
	if args.n > #schema then
		return false, #schema + 1
	end
	for i, checker in schema do
		if not checker(args[i]) then
			return false, i
		end
	end
	return true, nil
end

return Validate
