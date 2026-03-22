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
			warn(string.format("[PlayerStateService] Cannot access '%s' in path '%s': parent is not a table.", k, key))
			return nil
		end

		if schema[k] == nil then
			warn(string.format("[PlayerStateService] Schema path '%s' is invalid: key '%s' does not exist.", key, k))
			return nil
		end

		schema = schema[k]
	end
	
	return schema
end

-- Validates whether a given source has permission to modify a specific state key based on its schema.
local function IsValidChange(player: Player, key: string, value: any, source: string)
    local verdict = false

    if not PlayerStateService.PlayerState[player.UserId] then 
        warn(string.format("[PlayerStateService] Cannot validate change for %s (%d): Player state not initialized.", player.Name, player.UserId))
        return verdict 
    end

    local path = ResolveSchema(key)

    if not path then 
        warn(string.format("[PlayerStateService] Cannot validate change for %s (%d): Schema path '%s' not found.", player.Name, player.UserId, key))
        return verdict 
    end

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
        warn(string.format("[PlayerStateService] Permission denied for %s (%d): Source '%s' cannot write to '%s'.", player.Name, player.UserId, source, key))
        return verdict
    end

    if tostring(typeof(value)) ~= path.Type then
        warn(string.format("[PlayerStateService] Type mismatch for %s (%d) at '%s': Expected %s, got %s.", player.Name, player.UserId, key, path.Type, tostring(typeof(value))))
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
        warn(string.format("[PlayerStateService] GetState failed: Player %s (%d) state not initialized.", player.Name, player.UserId))
        return nil
    end

    local keys = string.split(key, ".")
	local current = PlayerStateService.PlayerState[player.UserId]

	for _, k in ipairs(keys) do
		if type(current) ~= "table" then
			warn(string.format("[PlayerStateService] GetState failed for %s (%d): Cannot access '%s' in path '%s' because its parent is not a table.", player.Name, player.UserId, k, key))
			return nil
		end

		if current[k] == nil then
			warn(string.format("[PlayerStateService] GetState failed for %s (%d): Invalid path '%s' - key '%s' does not exist.", player.Name, player.UserId, key, k))
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
			warn(string.format("[PlayerStateService] SetState failed for %s (%d): Cannot access '%s' in path '%s' because its parent is not a table.", player.Name, player.UserId, k, key))
			return
		end

		if i == #keys then
			-- We reached the end of the path, apply the value
			current[k] = value
		else
			if current[k] == nil then
				warn(string.format("[PlayerStateService] SetState failed for %s (%d): Invalid path '%s' - key '%s' does not exist.", player.Name, player.UserId, key, k))
				return
			end
			current = current[k]
		end
	end

    FireStateChanged(player, key, value)
end

function PlayerStateService.ModifyState(player: Player, key: string, delta: number, source: string)
    if type(delta) ~= "number" then
        warn(string.format("[PlayerStateService] ModifyState failed for %s (%d): Delta must be a number, got %s.", player.Name, player.UserId, typeof(delta)))
        return
    end

    local schema = ResolveSchema(key)
    if not schema then 
        warn(string.format("[PlayerStateService] ModifyState failed for %s (%d): Schema path '%s' not found.", player.Name, player.UserId, key))
        return
    end

    if schema.Type ~= "number" then
        warn(string.format("[PlayerStateService] ModifyState failed for %s (%d): Cannot modify non-number type '%s' at path '%s'.", player.Name, player.UserId, schema.Type, key))
        return
    end

    local currentValue = PlayerStateService.GetState(player, key)
    if currentValue == nil then
        return
    end

    local newValue = currentValue + delta
    PlayerStateService.SetState(player, key, newValue, source)
end

return PlayerStateService