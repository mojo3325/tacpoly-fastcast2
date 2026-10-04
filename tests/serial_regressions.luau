--!strict
-- Call the returned function with the FastCast2 ModuleScript in isolated Studio Play.
return function(fastcastModule: ModuleScript)
local FastCast = require(fastcastModule)
local ObjectCache = require(fastcastModule.ObjectCache)

local template = Instance.new("Part")
local holder = Instance.new("Folder")
holder.Parent = workspace
local cache = ObjectCache.new(template, 0, holder)
local okCache, cacheError = pcall(function()
	cache:ExpandCache(0)
	assert(#cache._FreeObjects == 0, "FastCast lifecycle check 1 failed")
	cache:ExpandCache(3)
	assert(#cache._FreeObjects == 3, "FastCast lifecycle check 2 failed")
	local parts = { cache:GetPart(), cache:GetPart(), cache:GetPart() }
	assert(
		#cache._FreeObjects == 0 and parts[1] ~= parts[2] and parts[2] ~= parts[3],
		"FastCast lifecycle check 3 failed"
	)
	for _, part in parts do
		cache:ReturnPart(part)
	end
	assert(#cache._FreeObjects == 3, "FastCast lifecycle check 4 failed")
	task.wait()
end)
cache:Destroy()
holder:Destroy()
template:Destroy()
assert(okCache, cacheError)

local function withCasters(test)
	local a, b = FastCast.new(), FastCast.new()
	local ok, err = xpcall(function()
		a:Init("BulkMoveTo", false, nil, nil, nil)
		b:Init("BulkMoveTo", false, nil, nil, nil)
		a.BaseCast.SerialSimulation:Stop()
		b.BaseCast.SerialSimulation:Stop()
		local function fire(caster, maxDistance)
			local cast
			caster.CastFire = function(value)
				cast = value
			end
			local behavior = FastCast.newBehavior()
			behavior.Acceleration = Vector3.zero
			behavior.MaxDistance = maxDistance or 100
			behavior.HighFidelitySegmentSize = 1
			behavior.FastCastEventsConfig.UseCastFire = true
			behavior.FastCastEventsConfig.UseCastTerminating = true
			caster:RaycastFire(Vector3.new(0, 10000, 0), Vector3.xAxis, 10, behavior)
			return assert(cast, "FastCast lifecycle check 5 failed")
		end
		test(a, b, fire)
	end, debug.traceback)
	pcall(function()
		a:Destroy()
	end)
	pcall(function()
		b:Destroy()
	end)
	assert(ok, err)
end
withCasters(function(a, b, fire)
	local terminal = 0
	b.CastTerminating = function()
		terminal += 1
	end
	local cast = fire(b)
	local id = cast.ID
	FastCast:TerminateCast(cast)
	a.BaseCast.SerialSimulation:UpdateCasts(1 / 60)
	b.BaseCast.SerialSimulation:UpdateCasts(1 / 60)
	assert(
		terminal == 1 and b.BaseCast.Actives[id] == nil and #b.BaseCast.SerialSimulation.casts_ID == 0,
		"FastCast lifecycle check 6 failed"
	)
end)
withCasters(function(a, b, fire)
	local terminal = 0
	a.CastTerminating = function()
		terminal += 1
	end
	local cast = fire(a)
	local id = cast.ID
	FastCast:TerminateCast(cast)
	b.BaseCast.SerialSimulation:UpdateCasts(1 / 60)
	a.BaseCast.SerialSimulation:UpdateCasts(1 / 60)
	assert(
		terminal == 1 and a.BaseCast.Actives[id] == nil and #a.BaseCast.SerialSimulation.casts_ID == 0,
		"FastCast lifecycle check 7 failed"
	)
end)
withCasters(function(a, b, fire)
	local cast = fire(a, 0.1)
	local id = cast.ID
	a.BaseCast.SerialSimulation:UpdateCasts(1)
	assert(
		a.BaseCast.Actives[id] == nil and #a.BaseCast.SerialSimulation.casts_ID == 0,
		"FastCast lifecycle check 8 failed"
	)
	local other = fire(b)
	local otherId = other.ID
	a:Destroy()
	a:Destroy()
	assert(
		#a.BaseCast.SerialSimulation.casts_ID == 0 and b.BaseCast.Actives[otherId] ~= nil,
		"FastCast lifecycle check 9 failed"
	)
end)
for _, external in { false, true } do
	withCasters(function(a, b, fire)
		local terminal = 0
		a.CastTerminating = function()
			terminal += 1
		end
		local cast, other = fire(a), fire(b)
		local id, otherId = cast.ID, other.ID
		if external then
			FastCast:TerminateCast(cast)
		end
		a:Destroy()
		a:Destroy()
		assert(
			#a.BaseCast.SerialSimulation.casts_ID == 0 and a.BaseCast.Actives[id] == nil,
			"FastCast lifecycle check 10 failed"
		)
		assert(terminal == (if external then 1 else 0), "FastCast lifecycle check 11 failed")
		assert(
			b.BaseCast.Actives[otherId] ~= nil and #b.BaseCast.SerialSimulation.casts_ID == 1,
			"FastCast lifecycle check 12 failed"
		)
		FastCast:TerminateCast(other)
		b.BaseCast.SerialSimulation:UpdateCasts(1 / 60)
		assert(#b.BaseCast.SerialSimulation.casts_ID == 0, "FastCast lifecycle check 13 failed")
	end)
end
-- Real ActiveCast/BaseCast/SerialSimulation lifecycle; only the collision oracle is detached.
local Protocol = require(game:GetService("ReplicatedStorage").Shared.Util.ProjectileProtocol)
local boundaryChecks, hitChecks = 0, 0
for _, fidelity in { FastCast.HighFidelityBehavior.Default, FastCast.HighFidelityBehavior.Always } do
	for _, launch in
		{
			{ velocity = Vector3.xAxis * 100, gravity = Vector3.zero, endAge = 1 },
			{
				velocity = Vector3.yAxis * 100,
				gravity = -Vector3.yAxis * 200,
				endAge = Protocol.ballisticRangeAge(Vector3.yAxis * 100, -Vector3.yAxis * 200, 100),
			},
		}
	do
		for _, deltas in { { 5 }, { launch.endAge * 0.4, launch.endAge * 0.6 }, { launch.endAge - 0.001, 5 } } do
			local caster = FastCast.new()
			local cast, terminalAge, terminalReason
			local hits, terminals, rays = 0, 0, 0
			local simulateTerminal = false
			caster.CastFire = function(value)
				cast = value
			end
			caster.Hit = function()
				hits += 1
			end
			caster.CastTerminating = function(value)
				terminals += 1
				terminalAge, terminalReason = value.StateInfo.TotalRuntime, value.StateInfo.TerminationReason
			end
			caster:Init("BulkMoveTo", false, nil, nil, nil)
			local serial = caster.BaseCast.SerialSimulation
			serial:Stop()
			serial.MovementEnabled = false
			local behavior = FastCast.newBehavior()
			behavior.Acceleration, behavior.MaxDistance, behavior.EndAge = launch.gravity, 0.01, launch.endAge
			behavior.HighFidelityBehavior, behavior.HighFidelitySegmentSize = fidelity, 10
			behavior.FastCastEventsConfig.UseCastFire = true
			behavior.FastCastEventsConfig.UseHit = true
			behavior.FastCastEventsConfig.UseCastTerminating = true
			caster:RaycastFire(Vector3.zero, launch.velocity.Unit, launch.velocity, behavior)
			local id = assert(cast).ID
			cast.RayInfo.WorldRoot = {
				Raycast = function(_, origin, direction)
					rays += 1
					local endpoint = origin + direction
					assert(origin.X <= 100 and endpoint.X <= 100, "final/preliminary ray crossed T")
					assert(origin.Y >= -50.001 and endpoint.Y >= -50.001, "curved final/preliminary ray crossed T")
					assert(not simulateTerminal, "substep ran after terminal")
					return nil -- even the tiny MaxDistance cannot preempt the opted-in age
				end,
			}
			local queue = serial.QueueEvent
			serial.QueueEvent = function(self, castId, event, ...)
				queue(self, castId, event, ...)
				if event == "CastTerminating" then
					simulateTerminal = true
				end
			end
			for _, delta in deltas do
				serial:UpdateCasts(delta)
			end
			assert(
				terminalAge == launch.endAge and terminalReason == "Range" and terminals == 1 and hits == 0,
				"range reason/age mismatch"
			)
			assert(caster.BaseCast.Actives[id] == nil and #serial.casts_ID == 0, "range removal failed")
			-- Replay an already detached terminal queue: neither terminal nor damage is delivered twice.
			serial:FireQueuedEvents({
				[id] = { { eventType = "CastTerminating", args = {} }, { eventType = "Hit", args = {} } },
			})
			assert(terminals == 1 and hits == 0 and rays > 0, "queued post-terminal callback escaped")
			caster:Destroy()
			boundaryChecks += 1
		end
	end
	-- A physical hit wins over Range, including exactly at T; Always runs no later substeps.
	for _, hitAt in { 20, 100 } do
		local caster = FastCast.new()
		local cast, reason
		local hits, terminals = 0, 0
		caster.CastFire = function(value)
			cast = value
		end
		caster.Hit = function()
			hits += 1
		end
		caster.CastTerminating = function(value)
			terminals += 1
			reason = value.StateInfo.TerminationReason
		end
		caster:Init("BulkMoveTo", false, nil, nil, nil)
		local serial = caster.BaseCast.SerialSimulation
		serial:Stop()
		serial.MovementEnabled = false
		local behavior = FastCast.newBehavior()
		behavior.Acceleration, behavior.MaxDistance, behavior.EndAge = Vector3.zero, 100, 1
		behavior.HighFidelityBehavior, behavior.HighFidelitySegmentSize = fidelity, 10
		behavior.FastCastEventsConfig.UseCastFire, behavior.FastCastEventsConfig.UseHit, behavior.FastCastEventsConfig.UseCastTerminating =
			true, true, true
		caster:RaycastFire(Vector3.zero, Vector3.xAxis, 100, behavior)
		local part = Instance.new("Part")
		local hitQueued = false
		cast.RayInfo.WorldRoot = {
			Raycast = function(_, origin, direction)
				assert(not hitQueued, "query after blocking terminal")
				if origin.X <= hitAt and (origin + direction).X >= hitAt then
					return {
						Instance = part,
						Position = Vector3.xAxis * hitAt,
						Normal = -Vector3.xAxis,
						Material = part.Material,
						Distance = hitAt - origin.X,
					}
				end
				return nil
			end,
		}
		local queue = serial.QueueEvent
		serial.QueueEvent = function(self, id, event, ...)
			queue(self, id, event, ...)
			if event == "CastTerminating" then
				hitQueued = true
			end
		end
		serial:UpdateCasts(5)
		assert(hits == 1 and terminals == 1 and reason == "Hit", "hit became range or repeated")
		part:Destroy()
		caster:Destroy()
		hitChecks += 1
	end
end
assert(boundaryChecks == 12 and hitChecks == 4, "native cutoff fixtures did not execute")

return "dependency package regression PASS"

end
