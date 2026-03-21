local Signal = require(script.Parent.GoodSignal)
local Players = game:GetService("Players")

local Template = require(script.Parent.StateTemplate)
local Schema = require(script.Parent.StateSchema)

local PlayerStateService = {}

PlayerStateService.PlayerState = {}

-- Signals
PlayerStateService.Signals = {
    StateChanged = Signal.new()
}

local function FireStateChanged(player: Player, key: string, value: any)
    PlayerStateService.Signals.StateChanged:Fire(player, key, value)
end

-- Resolves a string path (e.g. "Inventory.Coins") to its corresponding schema definition.
local function ResolveSchema(key)
    local keys = string.split(key, ".")
    local schema = Schema.RegisteredSchemas

	for _, k in ipairs(keys) do
		if type(schema) ~= "table" then
			warn("Cannot access key '" .. k .. "' - parent is not a table")
			return nil
		end

		if schema[k] == nil then
			warn("No key by value of " .. key)
			return nil
		end

		schema = schema[k]
	end
	
	return schema
end

-- Validates whether a given source has permission to modify a specific state key based on its schema.
local function IsValidChange(player: Player, key: string, value: any, source: string)
    local verdict = false

    if not PlayerStateService.PlayerState[player.UserId] then warn(`Player: {player.UserId} not initialized.`) return verdict end

    local path = ResolveSchema(key)

    if not path then warn(`Provided key: {key} wasn't found.`) return verdict end

    local IsValidAuthor = false
    if path.WriteableBy then
        for _, val in ipairs(path.WriteableBy) do
            if source == val then
                IsValidAuthor = true
                break
            end
        end
    end

    if not IsValidAuthor then 
        warn(`Source: {source} doesn't have write access to: {key}`)
        return verdict
    end

    if tostring(typeof(value)) ~= path.Type then
        warn(`Value: {value} isn't equivelent to {path.Type}`)
        return verdict
    end

    verdict = true
    return verdict
end

-- Creates a deep copy of a table to ensure nested tables are isolated from their sources.
local function deepCopy(tbl)
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = (type(v) == "table") and deepCopy(v) or v
	end
	return copy
end

-- Generates a fresh copy of the initial player state template.
local function CopyTemplate()
    local Copy = deepCopy(Template.Template)

    return Copy
end

-- Initializes the state for a newly joined player.
local function InitPlayer(player: Player)
    PlayerStateService.PlayerState[player.UserId] = CopyTemplate()
end

-- Cleans up the state for a player who has left the game.
local function RemovePlayer(player: Player)
    PlayerStateService.PlayerState[player.UserId] = nil
end

-- Initializes the service, connecting to player join/leave events.
function PlayerStateService.Init()
    Players.PlayerAdded:Connect(function(player)
        InitPlayer(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        RemovePlayer(player)
    end)

    for _, playerV in ipairs(Players:GetPlayers()) do
        InitPlayer(playerV)
    end
end

-- Retrieves a specific value from a player's state using a string path.
function PlayerStateService.GetState(player: Player, key: string) 
    if not PlayerStateService.PlayerState[player.UserId] then
        warn("Player not found: " .. player.Name)
        return
    end

    local keys = string.split(key, ".")
	local current = PlayerStateService.PlayerState[player.UserId]

	for _, k in ipairs(keys) do
		if type(current) ~= "table" then
			warn("Cannot access key '" .. k .. "' - parent is not a table")
			return nil
		end

		if current[k] == nil then
			warn("No key by value of " .. key)
			return nil
		end

		current = current[k]
	end
	
	return current
end

--Return's an immutable deep copy of a player's complete state.
function PlayerStateService.GetFullState(player: Player)
    local CopiedTable = deepCopy(PlayerStateService.PlayerState[player.UserId])

    return CopiedTable
end

--Updates a specific value in a player's state if the source has proper write permissions.
function PlayerStateService.SetState(player: Player, key: string, value: any, source: string)
    local verdict = IsValidChange(player, key, value, source)
    if not verdict then return end

    local keys = string.split(key, ".")
	local current = PlayerStateService.PlayerState[player.UserId]

	for i, k in ipairs(keys) do
		if type(current) ~= "table" then
			warn("Cannot access key '" .. k .. "' - parent is not a table")
			return
		end

		if i == #keys then
			-- We reached the end of the path, apply the value
			current[k] = value
		else
			if current[k] == nil then
				warn("No key by value of " .. k)
				return
			end
			current = current[k]
		end
	end

    FireStateChanged(player, key, value)
end

return PlayerStateService