-- client/main.lua :: interacao, menu (ox_lib context - parte do hibrido), lobby
-- NUI custom entra depois; por ora a UI de lobby/regiao usa ox_lib menus.

local pedSpawned = false
local lobbyPlayers = {}
local selectedRegion = false

---------------------------------------------------------------------
-- PED + BLIP + TARGET
---------------------------------------------------------------------
CreateThread(function()
    -- blip
    if Config.Interaction.blip.enable then
        local b = Config.Interaction.blip
        local blip = AddBlipForCoord(Config.Interaction.coords.x, Config.Interaction.coords.y, Config.Interaction.coords.z)
        SetBlipSprite(blip, b.sprite)
        SetBlipColour(blip, b.color)
        SetBlipScale(blip, b.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(b.label)
        EndTextCommandSetBlipName(blip)
    end

    -- ped
    lib.requestModel(Config.Interaction.pedModel)
    local c = Config.Interaction.coords
    local ped = CreatePed(0, Config.Interaction.pedModel, c.x, c.y, c.z - 1.0, c.w, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(Config.Interaction.pedModel)
    pedSpawned = true

    -- ox_target
    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'vp_electrician_open',
            icon = 'fas fa-bolt',
            label = locale('open_menu'),
            distance = Config.Interaction.targetDistance,
            onSelect = function() OpenMenu() end,
        },
    })
end)

---------------------------------------------------------------------
-- CHECK DE JOB
---------------------------------------------------------------------
local function canOpen()
    if Config.RequiredJob == 'all' then return true end
    local pdata = exports.qbx_core:GetPlayerData()
    if not pdata or not pdata.job then return false end
    for jobName, minGrade in pairs(Config.RequiredJob) do
        if pdata.job.name == jobName and pdata.job.grade.level >= minGrade then
            return true
        end
    end
    lib.notify({ description = locale('wrong_job'), type = 'error' })
    return false
end

---------------------------------------------------------------------
-- MENU (ox_lib context)
---------------------------------------------------------------------
function OpenMenu()
    if not canOpen() then return end
    if JobActive then
        lib.notify({ description = locale('job_already_started'), type = 'inform' })
        return
    end
    local data = lib.callback.await('vp_electrician:getProfile', false)
    if not data then return end
    lobbyPlayers = data.players or {}

    local options = {
        {
            title = ('%s — Nivel %s'):format(data.name, data.level),
            description = ('XP: %s / %s  |  Banco: $%s'):format(data.xp, data.nextXp, data.money),
            icon = 'user',
            disabled = true,
        },
    }

    -- regioes
    for _, region in ipairs(data.regions) do
        local locked = data.level < region.minLevel
        local sel = selectedRegion and selectedRegion.key == region.key
        options[#options + 1] = {
            title = (sel and '✓ ' or '') .. region.title,
            description = ('Recompensa: $%s + %s XP  |  Nivel min: %s')
                :format(region.awards.money, region.awards.xp, region.minLevel),
            icon = 'location-dot',
            disabled = locked,
            onSelect = function()
                TriggerServerEvent('vp_electrician:selectMission', region.key)
                Wait(150)
                OpenMenu()
            end,
        }
    end

    -- convidar
    options[#options + 1] = {
        title = 'Convidar jogador',
        icon = 'user-plus',
        onSelect = function()
            local input = lib.inputDialog('Convidar', { { type = 'number', label = 'ID do jogador', required = true } })
            if input and input[1] then
                TriggerServerEvent('vp_electrician:invite', input[1])
            end
        end,
    }

    -- iniciar / resetar
    options[#options + 1] = {
        title = selectedRegion and 'INICIAR TRABALHO' or 'Selecione uma regiao',
        icon = 'play',
        disabled = not selectedRegion,
        onSelect = function() StartJobCheck() end,
    }

    lib.registerContext({ id = 'vp_electrician_menu', title = 'Eletricista', options = options })
    lib.showContext('vp_electrician_menu')
end

function StartJobCheck()
    if not selectedRegion then return end
    -- check client-side: zona de spawn livre (server revalida via spawn setter)
    TriggerServerEvent('vp_electrician:startJob')
end

---------------------------------------------------------------------
-- EVENTOS DE LOBBY
---------------------------------------------------------------------
RegisterNetEvent('vp_electrician:refreshLobby', function(players, region)
    lobbyPlayers = players or {}
    selectedRegion = region or false
end)

RegisterNetEvent('vp_electrician:receiveInvite', function(hostName, hostCid)
    local accept = lib.alertDialog({
        header = 'Convite de Eletricista',
        content = ('%s convidou voce para um trabalho. Aceitar?'):format(hostName),
        centered = true,
        cancel = true,
    })
    if accept == 'confirm' then
        TriggerServerEvent('vp_electrician:acceptInvite')
    end
end)

RegisterNetEvent('vp_electrician:leftLobby', function()
    selectedRegion = false
    lobbyPlayers = {}
end)

RegisterNetEvent('vp_electrician:rewardScreen', function(info)
    lib.notify({
        title = 'Missao concluida',
        description = ('%s recebeu $%s e %s XP (%s reparos)'):format(info.name, info.money, info.xp, info.score),
        type = 'success',
        duration = 8000,
    })
end)
