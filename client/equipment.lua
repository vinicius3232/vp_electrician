-- client/equipment.lua :: escada e lift (props sincronizados via server)
-- NOTA: lift aqui e simplificado (prop estatico que posiciona o player no alto).
-- O elevador movel com controle de altura do original e um TODO de fidelidade.

local spawnedEquipment = {} -- [targetId] = { props = { ... } }
local building = false

local function spawnProp(model, coords, heading)
    if not IsModelInCdimage(model) then return end
    lib.requestModel(model)
    local obj = CreateObject(model, coords.x, coords.y, coords.z, false, true, false)
    SetEntityHeading(obj, heading or 0.0)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(model)
    return obj
end

--- Prompt para construir equipamento (chamado pelo loop de mission.lua)
function HandleEquipmentPrompt(target, kind)
    if spawnedEquipment[target.id] then return end -- ja construido localmente
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
-- SINCRONIZACAO
---------------------------------------------------------------------
RegisterNetEvent('vp_electrician:equipmentBuilt', function(targetId, kind, coords)
    if spawnedEquipment[targetId] then return end
    local props = {}
    if kind == 'ladder' then
        local heading = 0.0
        props[#props + 1] = spawnProp(Config.Equipment.ladder.model,
            vec3(coords.x, coords.y, coords.z - 6.0), heading)
        local limit = spawnProp(Config.Equipment.ladder.limit,
            vec3(coords.x, coords.y + 0.5, coords.z + 4.0), heading)
        if limit then SetEntityAlpha(limit, 0); props[#props + 1] = limit end
    elseif kind == 'lift' then
        props[#props + 1] = spawnProp(Config.Equipment.lift.model, coords, 0.0)
        -- TODO: trilhos + movimento de altura (fidelidade total ao original)
    end
    spawnedEquipment[targetId] = { props = props }

    -- marca localmente que o alvo ja pode ser consertado
    if CurrentMission and CurrentMission.targets[targetId] then
        CurrentMission.targets[targetId].equipped = true
    end
end)

RegisterNetEvent('vp_electrician:equipmentRemoved', function(targetId)
    local eq = spawnedEquipment[targetId]
    if not eq then return end
    for _, obj in ipairs(eq.props) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    spawnedEquipment[targetId] = nil
    if CurrentMission and CurrentMission.targets[targetId] then
        CurrentMission.targets[targetId].equipped = false
    end
end)

--- Remove TODOS os props (chamado no fim/reset da missao)
function ClearEquipment()
    for id, eq in pairs(spawnedEquipment) do
        for _, obj in ipairs(eq.props) do
            if DoesEntityExist(obj) then DeleteEntity(obj) end
        end
    end
    spawnedEquipment = {}
end

---------------------------------------------------------------------
-- REMOCAO (tecla G perto do equipamento)
---------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 1000
        if JobActive and next(spawnedEquipment) then
            local pc = GetEntityCoords(cache.ped)
            for id, eq in pairs(spawnedEquipment) do
                local target = CurrentMission and CurrentMission.targets[id]
                if target and not target.fixed then
                    local dist = #(pc - target.coords)
                    if dist < 4.0 then
                        sleep = 0
                        DrawText3D(target.coords, locale('remove_equipment'))
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
