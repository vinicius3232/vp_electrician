-- server/rewards.lua :: entrega do veiculo, pagamento, XP/level e persistencia

---------------------------------------------------------------------
-- ENTREGAR VEICULO -> paga recompensa
---------------------------------------------------------------------
RegisterNetEvent('vp_electrician:deliverVehicle', function()
    local src = source
    local lobby, cid = vpGetLobbyBySrc(src)
    if not lobby or not lobby.finished then
        return exports.qbx_core:Notify(src, locale('job_not_started'), 'error')
    end

    -- valida que ha um veiculo do job perto do ponto de entrega (server-side)
    local delivery = lobby.region.deliveryCoords
    local anyNear = false
    for _, netId in ipairs(lobby.vehicles) do
        local veh = NetworkGetEntityFromNetworkId(netId)
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            if #(GetEntityCoords(veh) - delivery) <= Config.TargetRadius.delivery then
                anyNear = true
            end
        end
    end
    if not anyNear then
        Security.logSuspicious(src, 'deliverVehicle sem veiculo no ponto', nil)
        return
    end

    -- evita pagamento duplo
    if lobby.paid then return end
    lobby.paid = true

    local perPlayer = math.ceil(lobby.rewardMoney / math.max(1, lobby.playerCount))
    local xp = lobby.rewardXp

    -- deleta veiculos
    for _, netId in ipairs(lobby.vehicles) do
        local veh = NetworkGetEntityFromNetworkId(netId)
        if veh and veh ~= 0 and DoesEntityExist(veh) then DeleteEntity(veh) end
    end

    -- paga cada player
    for pcid, pl in pairs(lobby.players) do
        local player = exports.qbx_core:GetPlayer(pl.src)
        if player then
            player.Functions.AddMoney('bank', perPlayer, 'vp_electrician-reward')
            local prof = exports[GetCurrentResourceName()]:getProfile(pcid)
            local newLevel, newXp, leveledUp = Utils.applyXP(prof.level, prof.xp, xp, Config.RequiredXP, Config.MaxLevel)
            prof.level, prof.xp = newLevel, newXp
            DB.saveProfile(pcid, newXp, newLevel)
            exports.qbx_core:Notify(pl.src, locale('reward_received', perPlayer, xp), 'success')
            if leveledUp then
                exports.qbx_core:Notify(pl.src, locale('level_up', newLevel), 'success')
            end
            TriggerClientEvent('vp_electrician:rewardScreen', pl.src, {
                name = pl.name,
                money = perPlayer,
                xp = xp,
                score = pl.score or 0,
            })
        end
    end

    sendRewardLog(lobby, perPlayer)
    vpDestroyLobby(cid)
end)

---------------------------------------------------------------------
-- LOG (opcional - webhook por convar, sem token hardcoded)
---------------------------------------------------------------------
function sendRewardLog(lobby, perPlayer)
    local url = GetConvar(Config.LogWebhookConvar, '')
    if url == '' then return end
    local names = {}
    for _, pl in pairs(lobby.players) do names[#names + 1] = pl.name end
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = 'vp_electrician',
        embeds = { {
            title = 'Job de Eletricista concluido',
            color = 5763719,
            fields = {
                { name = 'Regiao', value = lobby.region.title, inline = true },
                { name = 'Jogadores', value = table.concat(names, ', '), inline = false },
                { name = 'Pagamento (cada)', value = ('$%s'):format(perPlayer), inline = true },
            },
            footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
        } },
    }), { ['Content-Type'] = 'application/json' })
end
