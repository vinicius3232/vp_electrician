-- shared/utils.lua :: funcoes puras reutilizaveis (client + server)
Utils = {}

--- Recompensa final considerando coop.
--- @param base number dinheiro base da regiao
--- @param multiplier number multiplicador coop (ex.: 1.5)
--- @param playerCount number jogadores no lobby
--- @return number total
function Utils.calcReward(base, multiplier, playerCount)
    if playerCount <= 1 then return math.ceil(base) end
    return math.ceil(base * multiplier * playerCount)
end

--- Sorteia N coords distintas de um pool (sem mutar o original).
--- @param pool table lista de vec3
--- @param count number quantos sortear
--- @return table coords selecionadas
function Utils.pickRandom(pool, count)
    local copy = {}
    for i = 1, #pool do copy[i] = pool[i] end
    local selected = {}
    count = math.min(count, #copy)
    for _ = 1, count do
        local idx = math.random(1, #copy)
        selected[#selected + 1] = table.remove(copy, idx)
    end
    return selected
end

--- Compara duas coords com tolerancia (evita comparacao de float exata).
function Utils.sameCoords(a, b, tol)
    tol = tol or 0.5
    return math.abs(a.x - b.x) < tol
        and math.abs(a.y - b.y) < tol
        and math.abs(a.z - b.z) < tol
end

--- Calcula nivel/xp apos ganho (retorna novos valores).
--- @return number newLevel, number newXp, boolean leveledUp
function Utils.applyXP(level, xp, gained, requiredTable, maxLevel)
    xp = xp + gained
    local leveledUp = false
    while level < maxLevel and xp >= (requiredTable[level] or math.huge) do
        xp = xp - requiredTable[level]
        level = level + 1
        leveledUp = true
    end
    if level >= maxLevel then xp = 0 end
    return level, xp, leveledUp
end
