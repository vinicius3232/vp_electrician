-- server/missions.lua :: validacao de conserto de alvos + equipamento sincronizado

---------------------------------------------------------------------
-- COMPLETAR UM ALVO
-- O client roda o minigame e ENVIA o resultado, mas o servidor revalida
-- tudo (lobby, alvo aberto por este player, proximity, cooldown) e e quem
-- decide se a missao acabou e libera a recompensa.
---------------------------------------------------------------------
RegisterNetEvent('vp_electrician:completeTarget', function(targetId, success)
    local src = source
    if not Security.canAct(src, 'completeTarget', Config.Cooldowns.completeTarget) then return end
    local lobby, cid = vpGetLobbyBySrc(src)
    if not lobby or not lobby.started or not lobby.mission then return end

    local target = lobby.mission.targets[targetId]
    if not target or target.fixed then return end
    if target.openBy ~= cid then
        Security.logSuspicious(src, 'completeTarget de alvo nao aberto por ele', { targetId = targetId })
        return
    end
    if not Security.isNear(src, target.coords, Config.TargetRadius[target.type] or 3.0) then
        Security.logSuspicious(src, 'completeTarget fora de alcance', { targetId = targetId })
        target.openBy = nil
        return
    end

    target.openBy = nil

    if not success then
        -- falhou: libera o alvo (dano e aplicado no client)
        vpBroadcast(lobby, 'vp_electrician:targetUpdated', target.id, false, false)
        return
    end

    target.fixed = true
    lobby.mission.remaining = lobby.mission.remaining - 1

    local prog = lobby.mission.progress[target.type]
    if prog then prog.made = prog.made + 1 end

    -- credita score do jogador (para o scoreboard)
    lobby.players[cid].score = (lobby.players[cid].score or 0) + 1

    vpBroadcast(lobby, 'vp_electrician:targetUpdated', target.id, true, lobby.mission.progress)
    vpBroadcast(lobby, 'vp_electrician:refreshScore', lobby.players)

    if lobby.mission.remaining <= 0 then
        lobby.finished = true
        vpBroadcast(lobby, 'vp_electrician:jobComplete', lobby.region.deliveryCoords)
    end
end)

-- Liberar alvo sem concluir (jogador fechou/cancelou)
RegisterNetEvent('vp_electrician:closeTarget', function(targetId)
    local src = source
    local lobby, cid = vpGetLobbyBySrc(src)
    if not lobby or not lobby.mission then return end
    local target = lobby.mission.targets[targetId]
    if target and target.openBy == cid then
        target.openBy = nil
    end
end)

---------------------------------------------------------------------
-- EQUIPAMENTO (escada / lift) - props sincronizados
---------------------------------------------------------------------
RegisterNetEvent('vp_electrician:buildEquipment', function(targetId, kind)
    local src = source
    if not Security.canAct(src, 'build', Config.Cooldowns.build) then return end
    local lobby, cid = vpGetLobbyBySrc(src)
    if not lobby or not lobby.started or not lobby.mission then return end
    local target = lobby.mission.targets[targetId]
    if not target or target.fixed then return end
    if Config.RequiresEquipment[target.type] ~= kind then return end
    if not Security.isNear(src, target.coords, Config.Equipment.buildDistance) then
        Security.logSuspicious(src, 'buildEquipment fora de alcance', { targetId = targetId, kind = kind })
        return
    end
    target.equipped = true
    target.equipment = kind
    vpBroadcast(lobby, 'vp_electrician:equipmentBuilt', target.id, kind, target.coords)
end)

RegisterNetEvent('vp_electrician:removeEquipment', function(targetId)
    local src = source
    local lobby, cid = vpGetLobbyBySrc(src)
    if not lobby or not lobby.mission then return end
    local target = lobby.mission.targets[targetId]
    if not target then return end
    target.equipped = (Config.RequiresEquipment[target.type] == nil)
    target.equipment = nil
    vpBroadcast(lobby, 'vp_electrician:equipmentRemoved', target.id)
end)
