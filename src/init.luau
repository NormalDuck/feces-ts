--!strict
--!optimize 2
local Players = game:GetService("Players")
local jecs = require("../roblox_packages/jecs")
local ref = require("../roblox_packages/ref")
local refs = require("../roblox_packages/refs")
local world = require("../roblox_packages/world")

local pair = jecs.pair
local __ = jecs.Wildcard
local onRemove = jecs.OnRemove

type Entity = jecs.Entity & number
type Component<T = any> = jecs.Entity<T> & number

type nilValue = "__n"
local NIL_VALUE: nilValue = "__n"

type deleteValue = "__d"
local DELETE_VALUE: deleteValue = "__d"

type PlayerObject = Player? | { Player } | (Player) -> ()
type changes = {
	[Component]: {
		[Player]: {
			value: { [Entity]: any },
			special: { [Entity]: deleteValue | nilValue }
		}
	}
}

type deleted = {
	[Player]: { Entity }
}

type applyable = {
	[Component]: {
		value: { [Entity]: any },
		special: { [Entity]: deleteValue | nilValue }
	}
} & { __d: { Entity }}

export type feces = {
	apply: (applyable) -> nil, -- applies component changes to world
	delta: () -> (changes, deleted), -- gets the component changes to replicate

	-- gets the entity deletions to replicate
	full: () -> changes, -- gets all currently replicating components
	group: (changes, deleted) -> { [Player]: applyable },
	
	-- hooks into applying replication
	added: ((Entity) -> nil),
	changed: ((Entity, Component) -> nil),
	deleted: ((Entity) -> nil)

}

local replicated = world:component() :: Component<PlayerObject>
local queries = {
	single = world:query(replicated):cached(),
	pair = world:query(pair(replicated, __)):cached(),
}

local added, changed, deleted = nil, nil, nil
local previous: { [Component]: { [Entity]: any | "__n" }} = {}
local feces = {
	replicated = replicated,
	queries = queries
}

-- PRIVATE FUNCTIONS

local function getPlayers(info: PlayerObject): { Player? }
	if typeof(info) == "table" then
		return info
	elseif typeof(info) == "function" then
		local result = {}
		for key, player in Players:GetPlayers() do
			if not info(player) then
				continue
			end
			
			result[key] = player
		end
		return result
	end
	
	return { info }
end

local function deepEquals(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end

	for key, value in a do
		if not deepEquals(value, b[key]) then
			return false
		end
	end
	for key, value in b do
		if not deepEquals(value, a[key]) then
			return false
		end
	end
	return true
end

local function diffComponent(previous: any, current: any): nilValue | any | {}?
	if current == nil then
		return if previous == NIL_VALUE then nil else NIL_VALUE
	end
	if previous == nil then
		return current
	end

	if typeof(previous) ~= typeof(current) then
		return if previous == current then nil else current
	end
	return if deepEquals(previous, current) then nil else current
end

local function fill(changes: changes, comp: Component, ent: Entity, value: any,  players: PlayerObject)
	changes[comp] = changes[comp] or {}
	
	for _, player in getPlayers(players) do
		if not player then
			continue
		end

		changes[comp][player] = changes[comp][player] or { value = {}, special = {} }
		if value == DELETE_VALUE or value == NIL_VALUE then
			changes[comp][player].special[ent] = value
		else
			changes[comp][player].value[ent] = value
		end
	end
end

local function reconcile(changes: changes, player: PlayerObject, entity: Entity, component: Component, value: any)
	previous[component] = previous[component] or {}
	local diff = diffComponent(previous[component][entity], value)
	if not diff then
		return
	end

	previous[component][entity] = if diff == DELETE_VALUE then nil else diff
	if player == nil then
		fill(changes, component, entity, diff, Players:GetPlayers())
		return
	end
	
	fill(changes, component, entity, diff, player)
end

local function replicating(callback: (Component, PlayerObject, Entity, any, Component) -> nil)
	local replicated = feces.replicated
	for _, archetype in queries.single:archetypes() do
		local entities = archetype.entities
		local columns = archetype.columns
		local types = archetype.types
		local record = archetype.records[replicated]
		if not record then
			continue
		end
		
		local playerColumn = columns[record]
		for key, id in types do
			if id == replicated :: number then
				continue
			end
			local column = columns[key]
			if not column then
				continue
			end

			for row, entity in entities do
				local player = playerColumn[row]
				callback(
					id :: Component,
					player,
					entity :: Entity,
					column[row],
					replicated
				)
			end
		end
	end

	for _, archetype in queries.pair:archetypes() do
		local entities: { number } = archetype.entities
		local types = archetype.types
		local records = archetype.records

		for _, id in types do
			if not jecs.IS_PAIR(id) then
				continue
			end

			if jecs.pair_first(world, id) ~= replicated :: number then
				continue -- it's a pair but the first component isn't replicated e.g pair(someComponent, someOtherComponent) instead of pair(replicated, someOtherComponent)
			end

			local record = records[id]
			if not record then
				continue
			end

			local playerColumn = archetype.columns[record]
			local component = jecs.pair_second(world, id)
			for row, entity in entities do
				if not world:has(entity :: Entity, component :: Component) then
					continue
				end

				callback(
					component :: Component,
					playerColumn[row],
					entity :: Entity,
					world:get(
						entity :: Entity,
						component :: Component
					),
					id :: Component
				)
			end
		end
	end
end

-- PUBLIC FUNCTIONS

function feces.apply(
	delta: applyable
)
	if not delta then
		warn("NO APPLYABLE DATA RECEIVED")
		return
	end

	for component, entities in delta :: {[any]: any } do
		if not entities then
			continue
		end
		
		if component == DELETE_VALUE then
			for _, entity in entities do
				local id = ref(`repl{entity}`)
				if deleted then
					deleted(id)
				end
				world:delete(id)
			end
			continue
		end
		
		for entity: Entity, value in entities.value do
			if not refs[`repl{entity}`] then
				local id = ref(`repl{entity}`)
				world:set(id, component, value)
				if added then
					added(id)
				end
			else
				local id = ref(`repl{entity}`)
				if changed then
					changed(id, component, value)
				end
				world:set(id, component, value)
			end
		end

		for entity: Entity, value in entities.special do
			local id = ref(`repl{entity}`)
			if changed then -- here to preview any changes
				changed(
					id, component,
					if value == NIL_VALUE or value == DELETE_VALUE
					then nil else value
				)
			end

			if value == DELETE_VALUE then
				world:remove(id, component)
				continue
			end

			--or we could put it here to let them see if it was deleted

			world:set(id, component, 
				if value == NIL_VALUE
					then nil 
					else value
			)

			--here to get the new value and see if deleted, but can't observe old value any more
		end
	end
end

function feces.delta()
	local changes: changes = {}
	local deleted: deleted = {}
	
	replicating(function(component, playerObject, entity: Entity, value, replicatedId)
		reconcile(changes, playerObject, entity, component, value)
		
		world:set(replicatedId, onRemove, function(id: jecs.Entity)
			if id == entity :: jecs.Entity then
				for _, player in getPlayers(playerObject) do
					if not player then
						continue
					end
					
					deleted[player] = id
				end
			end
		end)
		
		if next(deleted) then
			for _, player in getPlayers(playerObject) do
				if not player then
					continue
				end
				
				local id = deleted[player]
				if not id or id ~= entity :: jecs.Entity then
					continue
				end

				previous[component] = previous[component] or {}
				print("DELETING FROM PREVIOUS", entity, component)
				previous[component][entity] = nil
			end
		end
		
		world:set(component, onRemove, function(id)
			if id == entity :: jecs.Entity and not deleted[id :: Entity] then
				print("component removed", id, component)
				reconcile(changes, playerObject, id :: Entity, component, DELETE_VALUE)
			end
		end)
	end)
	
	return changes, deleted
end

function feces.full()
	local changes: changes = {}

	replicating(function(component, player, entity, value)
		fill(changes, component, entity, player, value)
	end)

	return changes
end

function feces.group(changes: changes, deleted: deleted): { [Player]: applyable }
	local packets: { [Player]: applyable } = {}

	for component, players in changes do
		for player, entities in players do
			packets[player] = packets[player] or {__d = {}}
			packets[player][component] = packets[player][component] or { value = {}, special = {} }
			for entity, value in entities.value do
				(packets[player][component] :: any).value[entity] = value
			end
			for entity, value in entities.special do
				(packets[player][component] :: any).special[entity] = value
			end
		end
	end

	for player, entities in deleted do
		packets[player] = packets[player] or {__d = {}}
		packets[player].__d = entities
	end
	
	return packets
end

function feces.added(callback: (Entity) -> nil)
	added = callback
end

function feces.changed(callback: (Entity, Component) -> nil)
	changed = callback
end

function feces.deleted(callback: (Entity) -> nil)
	deleted = callback
end

return feces :: typeof(feces)