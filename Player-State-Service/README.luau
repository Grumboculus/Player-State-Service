--[[
Thank you for using PlayerStateService by Grumbo!
Reach out for any inquiries or feature requests: Ender_tech82 (or Grumbo) on Roblox.

Credit with to stravant for the Goodsignal.
You can use your own signal but it must be hooked up manually.

## SETUP

1. Place PlayerStateService, StateSchema, StateTemplate, and GoodSignal
   in the correct locations matching the require() paths.
2. Call PlayerStateService.Init() once at the start of your server script.

## DEFINIING A TEMPLATE

The template defines the default state every player starts with.
Every key here should have a matching entry in the schema.

Example:[
    StateTemplate.Template = {
        Health = 100,
        Gold = 0,
        IsAlive = true,
    }

## DEFINING A SCHEMA

The schema defines the rules for each key in the template.
Each entry requires:

    SchemaName  - string  - the name of the key
    Type        - string  - "number", "string", "boolean", or "table"
    WriteableBy - table   - list of sources allowed to write to this key

Example:

    StateSchema.RegisteredSchemas = {
        Health = RegisterSchema("Health", "number", { "CombatService" }),
        Gold = RegisterSchema("Gold", "number", { "EconomyService", "QuestService" }),
        IsAlive = RegisterSchema("IsAlive", "boolean", { "CombatService" }),
    }

## USAGE

Initialize (call once in your server script)

PlayerStateService.Init()


Get a single value

local health = PlayerStateService.GetState(player, "Health")


Get the full state (returns a deep copy, safe to read freely)

local state = PlayerStateService.GetFullState(player)


Set a value (source must match WriteableBy in schema)

PlayerStateService.SetState(player, "Health", 80, "CombatService")


Nested keys use dot notation

PlayerStateService.SetState(player, "Stats.Speed", 20, "MovementService")


Listen for any state change

PlayerStateService.Signals.StateChanged:Connect(function(player, key, newValue)
    print(player.Name, "changed", key, "to", newValue)
end)

## NOTES

- Sources not listed in WriteableBy will be rejected with a warning.
- Values that don't match the schema type will be rejected with a warning.
- GetFullState returns a deep copy so changing it will not affect the real state.
- Players who are already in the server when Init() is called are handled automatically.


]]--