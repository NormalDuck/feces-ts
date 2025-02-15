--!strict
--!optimize 2
--!native

-- type pair<First, Second> = number & { __relation: First }
-- type entity<T = nil> = number & { __T: T }
-- type component<T = nil> = entity<T> | pair<entity<T>, entity<unknown>>
type targets = { [number]: number }

type NIL_VALUE = "__n"
local NIL_VALUE: NIL_VALUE = "__n"

type DELETE_VALUE = "__d"
local DELETE_VALUE: DELETE_VALUE = "__d"

export type EntityValues = {
	[number]: {
		[number]: any,
	},
}
export type EntityChanges = {
	[number]: DELETE_VALUE | {
		[number]: any,
	},
}
export type Packet = {
	player: Player?,
	entities: EntityChanges,
}

export type PlayerObject = Player | { Player } | nil

local isServer = game:GetService("RunService"):IsServer()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.Jecs)
local equals = require(ReplicatedStorage.Packages.Freeze).Dictionary.equals
local ref = require(ReplicatedStorage.Hooks.ref)
local refs = require(ReplicatedStorage.refs)

local pair = jecs.pair
local onRemove = jecs.OnRemove
local Wildcard = jecs.Wildcard
local previous: EntityValues = {}

local ECS_ENTITY_MASK = bit32.lshift(1, 24)
local ECS_ID_FLAGS_MASK = 0x10

local world: jecs.World, replicated: jecs.Id<PlayerObject>, queries: {jecs.Query<any>} = nil, nil, {}
local feces = {
	replicated = replicated,
}

local function makePacket(plr: Player?): Packet
	return {
		entities = {},
		player = plr,
	}
end

local function getPlayers(info: PlayerObject): { Player }?
	if typeof(info) == "table" then
		return info
	end
	return if info ~= nil then { info } else nil
end

--- Checks if a packet contains any changes to replicate, and appends to list
local function addPacket(collection: { Packet }, packet: Packet)
	--use the standard iterator for maps because the # operator doesn't work
	local containsChange = false
	for _, entity: any in packet.entities do
		if entity == DELETE_VALUE then
			containsChange = true
			break
		end

		for _ in entity do
			containsChange = true
			break
		end
		if containsChange then
			break
		end
	end
	if not containsChange then
		return
	end
	--add the packet to the collection because there was a change
	table.insert(collection, packet)
end

--- If there is a (shallow) difference in the object it will return the current object, else nil
local function componentChanges<T>(prevComponentValue: T | {}, currComponentValue: T | {}): NIL_VALUE | T | {} | nil
	--new value is nil, then change to nil
	if currComponentValue == nil then
		if prevComponentValue == NIL_VALUE then
			return
		end
		if prevComponentValue == nil then
			-- print("tag added, registered as change")
			return NIL_VALUE
		end
	end

	local type1, type2 = typeof(prevComponentValue), typeof(currComponentValue)

	--NO CHANGES
	if type1 ~= "table" and type2 ~= "table" and prevComponentValue == currComponentValue then
		-- if debug_component == 1 then print("no difference because values are equal") end
		return nil
	end

	--new value is nil, then change to nil
	if currComponentValue == nil then
		-- print("component set to nil")
		return NIL_VALUE
	end

	--old value is nil, then change to new value
	if prevComponentValue == nil then
		-- print("previous value == nil so curr value HAS to be changed")
		return currComponentValue
	end

	if type1 ~= type2 or type2 ~= "table" then
		-- print("both values are tables and different tables")
		return currComponentValue
	end

	if type1 == "table" and type2 == "table" then
		if not equals(currComponentValue, prevComponentValue) then
			return currComponentValue
		end
	end

	--no table changes found!
	return nil
end

local function reverseRef(entity: number): number?
	if not entity then
		return nil
	elseif isServer then
		return entity
	end
	for key, value in refs :: { number } do
		if value == entity then
			return key
		end
	end

	return entity
end

local function addChanges(
	entity: number,
	componentId: number,
	componentValue,
	group: { public: Packet } & { [Player]: Packet },
	playerValue: PlayerObject
)
	previous[entity] = if previous[entity] then previous[entity] else {}

	local changes = componentChanges(previous[entity][componentId], componentValue)
	if changes == nil then
		return --NO DIFFERENCE IN VALUE
	end

	local players: { Player }? = getPlayers(playerValue)
	previous[entity][componentId] = changes
	entity = reverseRef(entity)
	-- add to the map of previous entities and constantly check if the world contains them
	--find the right packet to edit and add the component's diff
	if players == nil then
		--add to public packet
		group.public.entities[entity] = group.public.entities[entity] or {}
		group.public.entities[entity][componentId] = changes
	else
		for _, player in players do
			group[player] = group[player] or makePacket(player);
			group[player].entities[entity] = group[player].entities[entity] or {};
			group[player].entities[entity][componentId] = changes;
		end
	end
end


local function target(archetype, index): jecs.Id<any>?
	local nth = index or 0
	local idr = world.componentIndex[pair(replicated, Wildcard)]
	if not idr then
		return
	end

	local tr = idr.cache[archetype.id]
	if not tr then
		return
	end

	local count = tr.count
	if nth >= count then
		nth = nth + count + 1
	end

	nth = archetype.types[nth + tr.column]
	if not nth then
		return
	end

	return jecs.entity_index_get_alive(world.entity_index, if nth > ECS_ENTITY_MASK then (nth // ECS_ID_FLAGS_MASK) % ECS_ENTITY_MASK else nth)
end

local function getAllTargets(archetype, index: number, targets: targets): targets
	local componentId = target(archetype, index)
	if not componentId then
		return targets
	end

	table.insert(targets, componentId)
	return getAllTargets(archetype, index + 1, targets)
end


-- PUBLIC API
function feces.init(newWorld: jecs.World)
	print("INITIALIZED!!")
	assert(newWorld, "You must provide a world to feces")
	world = newWorld
	replicated = world:component() :: jecs.Id<PlayerObject>
	feces.replicated = replicated
	queries = {
		[1] = world:query(replicated):cached(),
		[2] = world:query(pair(replicated, Wildcard)):cached(),
	}
end

function feces.getPackets(): () -> (number?, Packet?)
	assert(queries and world, "You must provide a world by calling feces.init before feces.getPackets")
	local packets: { Packet } = {}
	local systemPackets: { public: Packet } & { [Player]: Packet } = {
		public = makePacket(),
	}

	local playerLinks: {[number]: Player} = {}

	for key, query in queries do
		local isPair: boolean = key == 2
		for _, archetype in query:archetypes() do
			local entities: { number } = archetype.entities
			local columns: { any } = archetype.columns

			--go through entities
			for row, entity: number in entities do
				for columnNumber: number, column in columns do
					if isPair then	
						local targets = getAllTargets(archetype, 0, {})
						if not targets then
							continue
						end

						for _, componentId in targets do
							local componentValue = world:get(entity, componentId)
							if type(componentValue) == "function" then
								continue
							end
							local playerValue = world:get(entity, pair(replicated, componentId))
							playerLinks[componentId] = playerValue

							addChanges(
								entity,
								componentId,
								componentValue,
								systemPackets,
								playerValue
							)
						end
					else
						local componentId: number = archetype.types[columnNumber]
						local componentValue = column[row]
						if type(componentValue) == "function" then
							continue
						end

						-- componentValue = if componentValue == nil then NIL_VALUE else componentValue
						local playerValue = world:get(entity, replicated)
						playerLinks[componentId] = playerValue

						addChanges(
							entity,
							componentId,
							componentValue,
							systemPackets,
							playerValue
						)
					end
				end
			end
		end
	end

	for entity, components in previous do
		if not world:contains(entity) then
			systemPackets.public.entities[entity] = DELETE_VALUE
			previous[entity] = nil
			print("REGISTERING DELETE:", entity)
			continue
		end

		if type(components) ~= "table" then
			continue
		end

		for id in components do
			world:set(id, onRemove, function(ent)
				if ent == entity then
					previous[entity][id] = nil
					local playerData = getPlayers(playerLinks[id])
					if playerData then
						for _, player in playerData do
							systemPackets[player].entities[entity][id] = DELETE_VALUE
						end
						return
					end

					systemPackets.public.entities[entity] = systemPackets.public.entities[entity] or {}
					systemPackets.public.entities[entity][id] = DELETE_VALUE
				end
			end)
		end
	end

	--add new packets to collections
	for _, packet in systemPackets :: { [any]: Packet } do
		if next(packet.entities) == nil then
			continue
		end

		addPacket(packets, packet)
	end

	local i = 0
	return function(): (number?, Packet?)
		i += 1
		local this = packets[i]
		if this == nil then
			i = 0
			return
		end
		return i, this
	end
end

local Players = game:GetService("Players")
function feces.applyPackets(entities: EntityChanges)
	assert(world, "You must provide a world by calling feces.init before feces.applyPackets")
	for entity: any, components in entities do
		entity = ref(world, `repl{tonumber(entity)}`)
		if type(components) ~= "table" then 
			entity:delete()
			continue
		end

		for id, component in components do
			id = tonumber(id)
			if component == DELETE_VALUE then
				entity:remove(id)
				continue
			end
			
			entity:set(id, if component == NIL_VALUE then nil else component)
		end
	end
end

function feces.filterPackets(entities: EntityChanges, ...: jecs.Id<any>)
	local componentMap: { [jecs.Id<any>]: true? } = {}
	for _, componentId in { ... } do
		componentMap[componentId] = true
	end

	local filtered = {}
	for entity, components in entities do
		if type(components) ~= "table" then
			continue
		end
		for id, component in components do
			if componentMap[`repl{id}` :: jecs.Id<any>] then
				filtered[entity] = filtered[entity] or {}
				filtered[entity][id] = component
			end
		end
	end

	return filtered
end

local function skimChanges(entity: number, componentId: number, componentValue, packet: EntityValues)
	packet[entity] = packet[entity] or {}
	packet[entity][componentId] = componentValue
end

function feces.getFullPacket(): EntityChanges
	assert(queries and world, "You must provide a world by calling feces.init before feces.getFullPacket")
	local packet = {}

	for key, query in queries do
		local isPair: boolean = key == 2
		for _, archetype in query:archetypes() do
			local entities: { number } = archetype.entities
			local columns: { any } = archetype.columns

			--go through entities
			for row, entity: jecs.Entity in entities do
				for columnNumber: number, column in columns do
					if isPair then	
						local targets = getAllTargets(archetype, 0, {})
						if not targets then
							continue
						end

						for _, componentId in targets do
							local componentValue = world:get(entity, componentId)
							if type(componentValue) == "function" then
								continue
							end
							local playerValue = world:get(entity, pair(replicated, componentId))
							if playerValue then
								continue
							end

							skimChanges(
								entity,
								componentId,
								componentValue,
								packet
							)
						end
					else
						local componentId: number = archetype.types[columnNumber]
						local componentValue = column[row]
						if type(componentValue) == "function" then
							continue
						end

						local playerValue = world:get(entity, replicated)
						if playerValue then
							continue
						end

						skimChanges(
							entity,
							componentId,
							componentValue,
							packet
						)
					end
				end
			end
		end
	end

	return packet
end

return feces
