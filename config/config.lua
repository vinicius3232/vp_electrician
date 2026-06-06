Config = {}

Config.Debug = false

---------------------------------------------------------------------
-- INTERACAO / NPC
---------------------------------------------------------------------
Config.Interaction = {
    coords   = vec4(528.77, -1603.26, 29.34, 46.59),
    pedModel = `s_m_y_construct_01`, -- ped do eletricista
    blip     = { enable = true, sprite = 643, color = 3, scale = 0.55, label = 'Eletricista' },
    targetDistance = 2.0,
}

-- Job exigido para abrir o menu. 'all' = qualquer um.
Config.RequiredJob = 'all' -- ex.: { electrician = 0 }  (nome do job = grade minimo)

Config.MaxPlayersPerLobby = 4
Config.InviteMaxDistance  = 8.0   -- distancia maxima (m) para convidar (validada no server)
Config.JobResetCommand    = 'eletricistareset' -- comando p/ resetar o job em andamento

---------------------------------------------------------------------
-- COOLDOWNS / RATE LIMIT (regra nº4 do CLAUDE.md)
---------------------------------------------------------------------
Config.Cooldowns = {
    selectMission  = 1000,  -- ms entre selecoes de missao
    completeTarget = 2000,  -- ms entre consertos (acao de dinheiro/progressao)
    build          = 1500,  -- ms entre construir escada/lift
}

---------------------------------------------------------------------
-- VEICULO DO JOB
---------------------------------------------------------------------
Config.Vehicle = {
    primary   = `utillitruck2`,
    secondary = `utillitruck3`, -- spawnado se lobby tiver > 2 players
    fuel      = 100.0,
}

---------------------------------------------------------------------
-- EQUIPAMENTO (props sincronizados)
---------------------------------------------------------------------
Config.Equipment = {
    ladder = { model = `hw1_06_ldr_02`, limit = `prop_wallbrick_01` }, -- streetLamp
    lift   = { model = `prop_dock_crane_lift`, rail = `prop_conslift_rail` }, -- phonePole
    buildDistance = 8.0,
}

---------------------------------------------------------------------
-- MINIGAMES (hibrido) - dificuldade por tarefa via ox_lib skillCheck.
-- Quando a NUI custom for construida, troca-se 'mode' para 'nui'.
---------------------------------------------------------------------
Config.Minigames = {
    -- Qual minigame cada tarefa usa (hibrido):
    --   'skillcheck' = ox_lib (sem NUI)
    --   'welding'    = NUI custom de solda (html/)
    --   'welding' | 'panel' | 'wiring' = NUI custom (html/) | 'skillcheck' = ox_lib
    byTask = {
        fixTrafo       = 'panel',
        fixHouseBoard  = 'panel',
        fixStreetLamp  = 'welding',
        phonePole      = 'welding',
        fixTrafficLamp = 'wiring',
    },
    -- dificuldades do ox_lib skillCheck (fallback p/ quem usar 'skillcheck')
    skillchecks = {
        default = { 'easy', 'medium' },
    },
    -- 1) solda: arrastar terminal -> oposto, com timer e tentativas
    welding = {
        fixStreetLamp = { wireCount = 4, maxFails = 3, time = 60 },
        phonePole     = { wireCount = 5, maxFails = 3, time = 70 },
        default       = { wireCount = 4, maxFails = 3, time = 60 },
    },
    -- 2) painel/voltimetro: achar painel defeituoso + parafusos + switch
    panel = {
        fixTrafo      = { panels = 12 },
        fixHouseBoard = { panels = 9 },
        default       = { panels = 12 },
    },
    -- 3) fiacao: arrastar fio ao conector da mesma cor
    wiring = {
        fixTrafficLamp = { count = 4 },
        default        = { count = 4 },
    },
    failDamage = { min = 10, max = 25 }, -- dano ao falhar (choque eletrico)
}

---------------------------------------------------------------------
-- PROGRESSAO (XP necessario por nivel)
---------------------------------------------------------------------
Config.MaxLevel = 70
Config.RequiredXP = {} -- preenchido abaixo (1000 -> +500/nivel)
for i = 1, Config.MaxLevel do
    Config.RequiredXP[i] = 1000 + (i - 1) * 500
end

---------------------------------------------------------------------
-- LOG (opcional, SEM token hardcoded - usa convar/secret)
---------------------------------------------------------------------
-- Defina no server.cfg:  set vp_electrician_webhook "https://discord.com/api/webhooks/..."
Config.LogWebhookConvar = 'vp_electrician_webhook'

---------------------------------------------------------------------
-- REGIOES
-- Adicione mais regioes seguindo este formato (coords de mundo).
---------------------------------------------------------------------
Config.Regions = {
    {
        key          = 1,
        title        = 'Los Santos - Mission Row',
        minLevel     = 0,
        maxPlayers   = 4,
        awards       = { money = 5000, xp = 1000, coopMultiplier = 1.5 },
        spawnCoords  = {
            vec4(533.26, -1595.88, 28.52, 136.32),
            vec4(522.83, -1606.42, 28.64, 320.61),
        },
        deliveryCoords = vec3(533.26, -1595.88, 28.52),
        -- jobTasks: quantos de cada tipo o jogador conserta (sorteados do pool)
        jobTasks = {
            { name = 'fixTrafo',       count = 1, label = 'Reparar Transformador' },
            { name = 'fixHouseBoard',  count = 1, label = 'Reparar Quadro de Luz' },
            { name = 'fixStreetLamp',  count = 1, label = 'Reparar Poste de Luz' },
            { name = 'fixTrafficLamp', count = 1, label = 'Reparar Semaforo' },
            { name = 'phonePole',      count = 2, label = 'Reparar Poste Telefonico' },
        },
        -- pools de coords por tipo de alvo
        pools = {
            fixTrafo = {
                vec3(-36.78, -1577.22, 29.52),
                vec3(-93.2, -1530.56, 34.0),
                vec3(-115.57, -1553.29, 34.33),
            },
            fixHouseBoard = {
                vec3(215.55, -143.54, 58.55),
                vec3(229.16, -112.05, 69.73),
                vec3(151.14, -90.72, 64.27),
                vec3(57.32, -77.21, 62.26),
            },
            fixStreetLamp = {
                vec3(296.49, -348.94, 49.62),
                vec3(300.07, -339.12, 50.92),
                vec3(303.89, -329.46, 51.08),
                vec3(268.28, -316.47, 51.2),
            },
            phonePole = {
                vec3(-40.54, -1379.22, 40.37),
                vec3(0.73, -1378.96, 38.61),
                vec3(-5.01, -1355.6, 39.46),
                vec3(-45.92, -1355.53, 38.78),
            },
            fixTrafficLamp = {
                vec3(202.47, -325.59, 42.97),
                vec3(179.57, -323.06, 42.97),
                vec3(165.74, -349.88, 43.03),
                vec3(202.9, -358.29, 43.01),
            },
        },
    },
    {
        key          = 2,
        title        = 'Los Santos - Vespucci',
        minLevel     = 0,
        maxPlayers   = 4,
        awards       = { money = 7500, xp = 1250, coopMultiplier = 1.5 },
        spawnCoords  = {
            vec4(533.26, -1595.88, 28.52, 136.32),
            vec4(522.83, -1606.42, 28.64, 320.61),
        },
        deliveryCoords = vec3(533.26, -1595.88, 28.52),
        jobTasks = {
            { name = 'fixTrafo',       count = 2, label = 'Reparar Transformador' },
            { name = 'fixHouseBoard',  count = 2, label = 'Reparar Quadro de Luz' },
            { name = 'fixStreetLamp',  count = 2, label = 'Reparar Poste de Luz' },
            { name = 'fixTrafficLamp', count = 2, label = 'Reparar Semaforo' },
            { name = 'phonePole',      count = 2, label = 'Reparar Poste Telefonico' },
        },
        pools = {
            fixTrafo = {
                vec3(971.73, -1810.68, 31.03),
                vec3(963.1, -1828.73, 30.96),
                vec3(961.2, -1808.28, 30.99),
            },
            fixHouseBoard = {
                vec3(709.88, -2139.19, 29.07),
                vec3(709.05, -2149.26, 28.96),
                vec3(708.18, -2158.47, 29.45),
                vec3(707.28, -2168.47, 28.75),
            },
            fixStreetLamp = {
                vec3(825.12, -2247.5, 36.11),
                vec3(859.92, -2250.55, 36.17),
                vec3(910.08, -2236.19, 36.55),
                vec3(923.31, -2257.48, 36.27),
            },
            phonePole = {
                vec3(830.6, -2248.05, 40.53),
                vec3(894.94, -2253.68, 40.58),
                vec3(776.15, -2284.71, 38.18),
            },
            fixTrafficLamp = {
                vec3(850.0, -1766.74, 29.17),
                vec3(847.65, -1728.46, 30.06),
                vec3(806.26, -1766.21, 29.67),
                vec3(802.22, -1732.87, 29.37),
            },
        },
    },
    {
        key          = 3,
        title        = 'Los Santos - Del Perro',
        minLevel     = 0,
        maxPlayers   = 4,
        awards       = { money = 10000, xp = 1500, coopMultiplier = 1.5 },
        spawnCoords  = {
            vec4(533.26, -1595.88, 28.52, 136.32),
            vec4(522.83, -1606.42, 28.64, 320.61),
        },
        deliveryCoords = vec3(533.26, -1595.88, 28.52),
        jobTasks = {
            { name = 'fixTrafo',       count = 2, label = 'Reparar Transformador' },
            { name = 'fixHouseBoard',  count = 2, label = 'Reparar Quadro de Luz' },
            { name = 'fixStreetLamp',  count = 2, label = 'Reparar Poste de Luz' },
            { name = 'fixTrafficLamp', count = 2, label = 'Reparar Semaforo' },
            { name = 'phonePole',      count = 2, label = 'Reparar Poste Telefonico' },
        },
        pools = {
            fixTrafo = {
                vec3(-1266.89, -1120.51, 7.17),
                vec3(-1255.37, -1153.72, 7.9),
                vec3(-1248.24, -1193.38, 8.43),
            },
            fixHouseBoard = {
                vec3(-1114.89, -1218.55, 2.82),
                vec3(-1108.51, -1223.37, 2.73),
                vec3(-1114.95, -1260.07, 7.12),
            },
            fixStreetLamp = {
                vec3(-1136.04, -1317.53, 10.8),
                vec3(-1098.24, -1324.26, 11.02),
                vec3(-1077.21, -1333.9, 11.91),
            },
            phonePole = {
                vec3(-1268.56, -1034.12, 19.06),
                vec3(-1281.57, -1070.53, 16.77),
                vec3(-1295.11, -1077.0, 17.07),
            },
            fixTrafficLamp = {
                vec3(-1292.26, -1177.19, 4.65),
                vec3(-1280.68, -1192.81, 4.73),
                vec3(-1296.91, -1207.0, 4.68),
                vec3(-1312.14, -1192.63, 4.79),
            },
        },
    },
    {
        key          = 4,
        title        = 'Los Santos - Rockford',
        minLevel     = 0,
        maxPlayers   = 4,
        awards       = { money = 15000, xp = 2000, coopMultiplier = 1.5 },
        spawnCoords  = {
            vec4(533.26, -1595.88, 28.52, 136.32),
            vec4(522.83, -1606.42, 28.64, 320.61),
        },
        deliveryCoords = vec3(533.26, -1595.88, 28.52),
        jobTasks = {
            { name = 'fixTrafo',       count = 3, label = 'Reparar Transformador' },
            { name = 'fixHouseBoard',  count = 3, label = 'Reparar Quadro de Luz' },
            { name = 'fixStreetLamp',  count = 3, label = 'Reparar Poste de Luz' },
            { name = 'fixTrafficLamp', count = 2, label = 'Reparar Semaforo' },
            { name = 'phonePole',      count = 3, label = 'Reparar Poste Telefonico' },
        },
        pools = {
            fixTrafo = {
                vec3(-1311.33, -162.08, 45.38),
                vec3(-1310.36, -177.1, 43.78),
                vec3(-1350.07, -207.32, 43.82),
            },
            fixHouseBoard = {
                vec3(-1160.88, -214.45, 37.63),
                vec3(-1146.97, -361.66, 38.08),
                vec3(-678.76, -176.53, 37.67),
            },
            fixStreetLamp = {
                vec3(-288.16, -340.08, 35.44),
                vec3(-307.27, -320.6, 36.54),
                vec3(-326.56, -292.77, 37.17),
            },
            phonePole = {
                vec3(-1650.41, -354.58, 60.19),
                vec3(-1669.68, -368.92, 60.02),
                vec3(-1702.68, -406.54, 57.31),
            },
            fixTrafficLamp = {
                vec3(-679.53, -220.59, 37.06),
                vec3(-695.05, -205.35, 37.41),
                vec3(-723.64, -228.71, 37.38),
                vec3(-704.67, -246.78, 37.21),
            },
        },
    },
}

-- Distancias de interacao por tipo de alvo
Config.TargetRadius = {
    fixTrafo       = 2.5,
    fixHouseBoard  = 2.5,
    fixStreetLamp  = 3.0,
    phonePole      = 3.0,
    fixTrafficLamp = 2.5,
    delivery       = 10.0,
}

-- Tarefas que exigem equipamento antes do minigame
Config.RequiresEquipment = {
    fixStreetLamp = 'ladder',
    phonePole     = 'lift',
}

Config.TrafficLightModels = {
    `prop_traffic_03a`, `prop_traffic_02a`, `prop_traffic_01a`,
    `prop_traffic_01d`, `prop_traffic_lightset_01`, `prop_traffic_01b`, `prop_traffic_03b`,
}
