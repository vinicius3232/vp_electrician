-- server/main.lua :: lobby coop, perfis, start/finish, veiculo
-- Modelo: o servidor e a unica fonte de verdade. Nunca confiamos em
-- owneridentifier/coords vindos do client; derivamos o lobby do proprio src.

Profiles = {}        -- [citizenid] = { xp, level }
Lobbies  = {}        -- [ownerCid]  = { ...estado... }
PlayerLobby = {}     -- [citizenid] = ownerCid  (lookup reverso)
PendingInvites = {}  -- [targetCid] = ownerCid

---------------------------------------------------------------------
-- PERFIL
---------------------------------------------------------------------
local function getProfile(citizenid)
    if not Profiles[citizenid] then
        Profiles[citizenid] = DB.loadProfile(citizenid)
    end
    return Profiles[citizenid]
end
exports('getProfile', getProfile) -- usado por rewards.lua

local function playerName(src)
    local p = exports.qbx_core:GetPlayer(src)
    if not p then return 'Unknown' end
    local ci = p.PlayerData.charinfo
    return ('%s %s'):format(ci.firstname, ci.lastname)
end
_G.vpPlayerName = playerName

---------------------------------------------------------------------
-- HELPERS DE LOBBY
---------------------------------------------------------------------
local function getLobbyBySrc(src)
    local player, cid = Security.getPlayer(src)
    if not cid then return end
    local ownerCid = PlayerLobby[cid]
    if not ownerCid then return end
    return Lobbies[ownerCid], cid
end
_G.vpGetLobbyBySrc = getLobbyBySrc

local function broadcast(lobby, event, ...)
    for cid, pl in pairs(lobby.players) do
        TriggerClientEvent(event, pl.src, ...)
    end
end
_G.vpBroadcast = broadcast

local function createLobby(src, cid)
    local prof = getProfile(cid)
    Lobbies[cid] = {
        owner = cid,
        ownerSrc = src,
        players = { [cid] = { src = src, name = playerName(src), level = prof.level } },
        started = false,
        finished = false,
        region = false,
        mission = nil,
        vehicles = {}, -- netIds
    }
    PlayerLobby[cid] = cid
    return Lobbies[cid]
end

local function destroyLobby(ownerCid)
    local lobby = Lobbies[ownerCid]
    if not lobby then return end
    for _, netId in ipairs(lobby.vehicles) do
        local veh = NetworkGetEntityFromNetworkId(netId)
        if veh and veh ~= 0 and DoesEntityExist(veh) then DeleteEntity(veh) end
    end
    for cid in pairs(lobby.players) do
        PlayerLobby[cid] = nil
    end
    Lobbies[ownerCid] = nil
end
_G.vpDestroyLobby = destroyLobby

---------------------------------------------------------------------
-- CALLBACKS (ox_lib)
---------------------------------------------------------------------
lib.callback.register('vp_electrician:getProfile', function(src)
    local player, cid = Security.getPlayer(src)
    if not cid then return end
    local prof = getProfile(cid)
    prof.source = src
    -- se ja e dono ou convidado de algum lobby, usa esse; senao cria um proprio
    local existingOwner = PlayerLobby[cid]
    local lobby = (existingOwner and Lobbies[existingOwner]) or createLobby(src, cid)
    return {
        name = playerName(src),
        money = player.PlayerData.money.bank,
        level = prof.level,
        xp = prof.xp,
        nextXp = Config.RequiredXP[prof.level] or 0,
        players = lobby.players,
        regions = Config.Regions,
    }
end)

-- trava de concorrencia + proximity ao abrir um alvo
lib.callback.register('vp_electrician:openTarget', function(src, data)
    if type(data) ~= 'table' then return false end
    local lobby, cid = getLobbyBySrc(src)
    if not lobby or not lobby.started or not lobby.mission then return false end
    local target = lobby.mission.targets[data.targetId]
    if not target or target.fixed then return false end
    if not Security.isNear(src, target.coords, Config.TargetRadius[target.type] or 3.0) then
        Security.logSuspicious(src, 'openTarget fora de alcance', data)
        return false
    end
    if target.openBy and target.openBy ~= cid then return false end -- ocupado por outro
    -- exige equipamento?
    local req = Config.RequiresEquipment[target.type]
    if req and not target.equipped then return { needEquipment = req } end
    target.openBy = cid
    target.openAt = GetGameTimer() -- anti-exploit: marca quando abriu
    return { ok = true, type = target.type }
end)

---------------------------------------------------------------------
-- CONVITES
---------------------------------------------------------------------
RegisterNetEvent('vp_electrician:invite', function(targetId)
    local src = source
    if not Security.canAct(src, 'invite', Config.Cooldowns.invite) then return end
    targetId = tonumber(targetId)
    if not targetId then return end
    local lobby, cid = getLobbyBySrc(src)
    if not lobby or lobby.owner ~= cid then return end -- so o dono convida
    if lobby.started then return end
    local tPlayer, tCid = Security.getPlayer(targetId)
    if not tCid or tCid == cid then return end
    if lobby.players[tCid] then
        return exports.qbx_core:Notify(src, locale('already_in_lobby'), 'error')
    end
    -- conta jogadores
    local count = 0; for _ in pairs(lobby.players) do count = count + 1 end
    if count >= Config.MaxPlayersPerLobby then
        return exports.qbx_core:Notify(src, locale('lobby_full'), 'error')
    end
    -- proximity server-side
    if not Security.isNear(src, GetEntityCoords(GetPlayerPed(targetId)), Config.InviteMaxDistance) then
        return exports.qbx_core:Notify(src, locale('player_far'), 'error')
    end
    PendingInvites[tCid] = cid
    TriggerClientEvent('vp_electrician:receiveInvite', targetId, playerName(src), cid)
end)

RegisterNetEvent('vp_electrician:acceptInvite', function()
    local src = source
    if not Security.canAct(src, 'acceptInvite', Config.Cooldowns.acceptInvite) then return end
    local player, cid = Security.getPlayer(src)
    if not cid then return end
    local ownerCid = PendingInvites[cid]
    PendingInvites[cid] = nil
    if not ownerCid then return end
    local lobby = Lobbies[ownerCid]
    if not lobby or lobby.started then return end
    local count = 0; for _ in pairs(lobby.players) do count = count + 1 end
    if count >= Config.MaxPlayersPerLobby then
        return exports.qbx_core:Notify(src, locale('lobby_full'), 'error')
    end
    -- sai do lobby proprio (se tinha um vazio)
    if Lobbies[cid] and not Lobbies[cid].started then destroyLobby(cid) end
    local prof = getProfile(cid)
    lobby.players[cid] = { src = src, name = playerName(src), level = prof.level }
    PlayerLobby[cid] = ownerCid
    broadcast(lobby, 'vp_electrician:refreshLobby', lobby.players, lobby.region)
end)

RegisterNetEvent('vp_electrician:kickPlayer', function(targetCid)
    local src = source
    if not Security.canAct(src, 'kickPlayer', Config.Cooldowns.kickPlayer) then return end
    if type(targetCid) ~= 'string' then return end
    local lobby, cid = getLobbyBySrc(src)
    if not lobby or lobby.owner ~= cid then return end
    if targetCid == cid then return end
    local target = lobby.players[targetCid]
    if not target then return end
    local tSrc = target.src
    lobby.players[targetCid] = nil
    PlayerLobby[targetCid] = nil
    TriggerClientEvent('vp_electrician:leftLobby', tSrc)
    broadcast(lobby, 'vp_electrician:refreshLobby', lobby.players, lobby.region)
end)

---------------------------------------------------------------------
-- SELECIONAR MISSAO
---------------------------------------------------------------------
RegisterNetEvent('vp_electrician:selectMission', function(regionKey)
    local src = source
    if not Security.canAct(src, 'selectMission', Config.Cooldowns.selectMission) then return end
    local lobby, cid = getLobbyBySrc(src)
    if not lobby or lobby.owner ~= cid or lobby.started then return end
    if regionKey == false then
        lobby.region = false
        return broadcast(lobby, 'vp_electrician:refreshLobby', lobby.players, false)
    end
    local region
    for _, r in ipairs(Config.Regions) do
        if r.key == regionKey then region = r break end
    end
    if not region then return end
    -- gate de nivel (validado no SERVIDOR, nao so no menu)
    local prof = getProfile(cid)
    if prof.level < (region.minLevel or 0) then
        return exports.qbx_core:Notify(src, locale('min_level', region.minLevel), 'error')
    end
    lobby.region = region
    broadcast(lobby, 'vp_electrician:refreshLobby', lobby.players, region)
end)

---------------------------------------------------------------------
-- INICIAR JOB
---------------------------------------------------------------------
local function generateMission(region)
    local mission = { targets = {}, progress = {}, remaining = 0 }
    local nextId = 0
    for _, task in ipairs(region.jobTasks) do
        local pool = region.pools[task.name] or {}
        local picked = Utils.pickRandom(pool, task.count)
        mission.progress[task.name] = { count = #picked, made = 0, label = task.label }
        for _, coords in ipairs(picked) do
            nextId = nextId + 1
            mission.targets[nextId] = {
                id = nextId,
                type = task.name,
                coords = coords,
                fixed = false,
                openBy = nil,
                equipped = Config.RequiresEquipment[task.name] == nil, -- ja "ok" se nao exige
            }
            mission.remaining = mission.remaining + 1
        end
    end
    return mission
end

RegisterNetEvent('vp_electrician:startJob', function()
    local src = source
    if not Security.canAct(src, 'startJob', Config.Cooldowns.startJob) then return end
    local lobby, cid = getLobbyBySrc(src)
    if not lobby or lobby.owner ~= cid then return end
    if lobby.started then
        return exports.qbx_core:Notify(src, locale('job_already_started'), 'error')
    end
    if not lobby.region then
        return exports.qbx_core:Notify(src, locale('mission_not_selected'), 'error')
    end
    if getProfile(cid).level < (lobby.region.minLevel or 0) then
        return exports.qbx_core:Notify(src, locale('min_level', lobby.region.minLevel), 'error')
    end

    lobby.started = true
    lobby.finished = false
    lobby.mission = generateMission(lobby.region)

    -- conta players p/ recompensa e 2o veiculo
    local count = 0; for _ in pairs(lobby.players) do count = count + 1 end
    lobby.playerCount = count
    lobby.rewardMoney = Utils.calcReward(lobby.region.awards.money, lobby.region.awards.coopMultiplier, count)
    lobby.rewardXp = lobby.region.awards.xp

    -- spawn de veiculo(s) server-side
    local sp = lobby.region.spawnCoords
    local function spawnVeh(model, c)
        local veh = CreateVehicleServerSetter(model, 'automobile', c.x, c.y, c.z, c.w)
        local t = 0
        while not DoesEntityExist(veh) and t < 100 do Wait(10); t = t + 1 end
        if not DoesEntityExist(veh) then return end
        Entity(veh).state:set('fuel', Config.Vehicle.fuel, true) -- ox_fuel statebag
        lobby.vehicles[#lobby.vehicles + 1] = NetworkGetNetworkIdFromEntity(veh)
        -- da chave a todos do lobby
        for _, pl in pairs(lobby.players) do
            exports.qbx_vehiclekeys:GiveKeys(pl.src, veh, true)
        end
    end
    spawnVeh(Config.Vehicle.primary, sp[1])
    if count > 2 and sp[2] then spawnVeh(Config.Vehicle.secondary, sp[2]) end

    broadcast(lobby, 'vp_electrician:jobStarted', {
        region = lobby.region,
        mission = lobby.mission,
        vehicles = lobby.vehicles,
        progress = lobby.mission.progress,
        players = lobby.players,
    })
end)

RegisterNetEvent('vp_electrician:resetJob', function()
    local src = source
    if not Security.canAct(src, 'resetJob', Config.Cooldowns.resetJob) then return end
    local lobby, cid = getLobbyBySrc(src)
    if not lobby then return end
    if lobby.owner ~= cid then
        return exports.qbx_core:Notify(src, locale('not_owner'), 'error')
    end
    broadcast(lobby, 'vp_electrician:jobReset')
    destroyLobby(cid)
end)

---------------------------------------------------------------------
-- LIMPEZA
---------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    local lobby, cid = getLobbyBySrc(src)
    if not lobby then return end
    if cid == lobby.owner then
        -- dono saiu: encerra missao p/ todos
        for pcid, pl in pairs(lobby.players) do
            if pcid ~= cid then
                TriggerClientEvent('vp_electrician:jobReset', pl.src)
                exports.qbx_core:Notify(pl.src, locale('left_lobby'), 'error')
            end
        end
        destroyLobby(cid)
    else
        lobby.players[cid] = nil
        PlayerLobby[cid] = nil
        if lobby.started then
            broadcast(lobby, 'vp_electrician:refreshLobby', lobby.players, lobby.region)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for ownerCid in pairs(Lobbies) do
        destroyLobby(ownerCid)
    end
end)
