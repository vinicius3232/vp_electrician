-- client/equipment.lua :: escada (estatica) e LIFT MOVEL (elevador)
-- Referencia: tw-electrician (createLift/moveLift). Reescrito do zero.
-- NOTA: a "pegada" do elevador (carregar o player) e ajustada in-game; aqui
-- o player controlador tem a posicao fixada na plataforma enquanto sobe/desce.

local spawnedEquipment = {} -- [targetId] = { kind, props={}, lift={...} }
local building = false
local LIFT_SPEED = 0.06      -- m por frame ao segurar a tecla
local CTRL_UP, CTRL_DOWN = 172, 173 -- setas cima/baixo

local function spawnProp(model, coords, heading)
    if not IsModelInCdimage(model) then return end
    lib.requestModel(model)
    local obj = CreateObject(model, coords.x, coords.y, coords.z, false, true, false)
    SetEntityHeading(obj, heading or 0.0)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(model)
    return obj
end

local function groundZ(x, y, fallback)
    local found, z = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, (fallback or 0.0) + 0.0, false)
    if found then return z end
    return fallback or 0.0
end

--- Prompt para construir equipamento (chamado pelo loop de mission.lua)
function HandleEquipmentPrompt(target, kind)
    if spawnedEquipment[target.id] then return end
    local key = kind == 'ladder' and 'build_ladder' or 'build_lift'
    DrawText3D(target.coords, locale(key))
    if IsControlJustReleased(0, 38) and not building then -- E
        building = true
        local dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@'
        lib.requestAnimDict(dict)
        TaskPlayAnim(cache.ped, dict, 'machinic_loop_mechandplayer', 8.0, 1.0, 2500, 1, 0, false, false, false)
        Wait(2500)
        ClearPedTasks(cache.ped)
        TriggerServerEvent('vp_electrician:buildEquipment', target.id, kind)
        building = false
    end
end

---------------------------------------------------------------------
-- CONSTRUCAO SINCRONIZADA
---------------------------------------------------------------------
RegisterNetEvent('vp_electrician:equipmentBuilt', function(targetId, kind, coords)
    if spawnedEquipment[targetId] then return end
    if kind == 'ladder' then
        local props = {}
        props[#props + 1] = spawnProp(Config.Equipment.ladder.model,
            vec3(coords.x, coords.y, coords.z - 6.0), 0.0)
        local limit = spawnProp(Config.Equipment.ladder.limit,
            vec3(coords.x, coords.y + 0.5, coords.z + 4.0), 0.0)
        if limit then SetEntityAlpha(limit, 0); props[#props + 1] = limit end
        spawnedEquipment[targetId] = { kind = 'ladder', props = props }
    elseif kind == 'lift' then
        local base = groundZ(coords.x, coords.y, coords.z - 8.0)
        local top  = coords.z - 1.0
        -- trilhos do chao ao topo
        local rails = {}
        local h = base
        while h < top do
            local r = spawnProp(Config.Equipment.lift.rail, vec3(coords.x, coords.y, h), 0.0)
            if r then rails[#rails + 1] = r end
            h = h + 5.0
        end
        -- plataforma comeca no chao
        local platform = spawnProp(Config.Equipment.lift.model, vec3(coords.x, coords.y, base), 0.0)
        spawnedEquipment[targetId] = {
            kind = 'lift', props = rails, platform = platform,
            lift = { x = coords.x, y = coords.y, base = base, top = top, height = base },
        }
    end

    if CurrentMission and CurrentMission.targets[targetId] then
        CurrentMission.targets[targetId].equipped = true
    end
end)

RegisterNetEvent('vp_electrician:equipmentRemoved', function(targetId)
    DestroyEquipment(targetId)
    if CurrentMission and CurrentMission.targets[targetId] then
        CurrentMission.targets[targetId].equipped = false
    end
end)

-- altura do lift sincronizada por OUTROS players
RegisterNetEvent('vp_electrician:liftMoved', function(targetId, height)
    local eq = spawnedEquipment[targetId]
    if not eq or eq.kind ~= 'lift' or not eq.platform then return end
    eq.lift.height = height
    if DoesEntityExist(eq.platform) then
        SetEntityCoords(eq.platform, eq.lift.x, eq.lift.y, height, false, false, false, false)
    end
end)

function DestroyEquipment(targetId)
    local eq = spawnedEquipment[targetId]
    if not eq then return end
    for _, obj in ipairs(eq.props) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    if eq.platform and DoesEntityExist(eq.platform) then DeleteEntity(eq.platform) end
    spawnedEquipment[targetId] = nil
end

function ClearEquipment()
    for id in pairs(spawnedEquipment) do DestroyEquipment(id) end
    spawnedEquipment = {}
end

---------------------------------------------------------------------
-- CONTROLE DO LIFT (subir/descer) + REMOCAO (G)
---------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 1000
        if JobActive and next(spawnedEquipment) then
            local pc = GetEntityCoords(cache.ped)
            for id, eq in pairs(spawnedEquipment) do
                local target = CurrentMission and CurrentMission.targets[id]
                if target and not target.fixed then
                    -- remocao (G) perto da base
                    local distBase = #(pc - vec3(target.coords.x, target.coords.y, pc.z))
                    if distBase < 4.0 then
                        sleep = 0
                        if eq.kind == 'lift' then
                            DrawText3D(vec3(eq.lift.x, eq.lift.y, eq.lift.height + 1.0), '↑/↓ elevador  •  [G] remover')
                            ControlLift(id, eq)
                        else
                            DrawText3D(target.coords, locale('remove_equipment'))
                        end
                        if IsControlJustReleased(0, 47) then -- G
                            TriggerServerEvent('vp_electrician:removeEquipment', id)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

local lastLiftSync = 0
function ControlLift(id, eq)
    local lift = eq.lift
    if not eq.platform or not DoesEntityExist(eq.platform) then return end
    local pc = GetEntityCoords(cache.ped)
    -- jogador precisa estar SOBRE a plataforma (perto no XY e proximo do topo dela)
    local onXY = #(vec2(pc.x, pc.y) - vec2(lift.x, lift.y)) < 1.6
    local onZ  = math.abs(pc.z - (lift.height + 1.0)) < 2.0
    if not (onXY and onZ) then return end

    local moved = false
    if IsControlPressed(0, CTRL_UP) and lift.height < lift.top then
        lift.height = math.min(lift.top, lift.height + LIFT_SPEED); moved = true
    elseif IsControlPressed(0, CTRL_DOWN) and lift.height > lift.base then
        lift.height = math.max(lift.base, lift.height - LIFT_SPEED); moved = true
    end

    if moved then
        SetEntityCoords(eq.platform, lift.x, lift.y, lift.height, false, false, false, false)
        -- carrega o controlador junto
        SetEntityCoords(cache.ped, lift.x, lift.y, lift.height + 1.0, false, false, false, false)
        -- sincroniza p/ os outros (throttle)
        local now = GetGameTimer()
        if now - lastLiftSync > 120 then
            lastLiftSync = now
            TriggerServerEvent('vp_electrician:moveLift', id, lift.height)
        end
    end
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then ClearEquipment() end
end)
