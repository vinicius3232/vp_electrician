# vp_electrician — Documentação Técnica

Job cooperativo de eletricista por região para **QBox** (rebuild nativo ox), inspirado na gameplay do `tw-electrician`. Escrito do zero, **sem backdoor** e sem assets/código do produto vazado.

---

## 1. Origem e contexto de segurança

> O `tw-electrician` original é uma **cópia vazada (fivehub-panel.site)** com:
> - **Backdoor de RCE** em `server.lua`: `PerformHttpRequest(author..'/api.php?key=...')` + `load(b)()` executava Lua arbitrário remoto.
> - **Token de bot Discord hardcoded** em `editable.lua`.
> - `escrow_ignore` + arquivos abertos = escrow crackeado.
>
> **Nada disso foi reaproveitado.** Apenas coordenadas de mundo (dados públicos do mapa) foram reutilizadas como referência. Todo o código aqui é original.

---

## 2. Stack (versões confirmadas neste servidor)

| Resource | Versão | Uso |
|----------|--------|-----|
| qbx_core | 1.23.0 | `GetPlayer`, `AddMoney`, `Notify`, `GetPlayerData` |
| ox_lib | 3.32.2 | callbacks, context menu, dialogs, skillCheck, notify, cache, points |
| ox_inventory | 2.44.8 | (hook pronto p/ itens; não exige itens hoje) |
| ox_target | — | interação no NPC |
| ox_fuel | — | combustível via statebag `Entity(veh).state:set('fuel', x, true)` |
| qbx_vehiclekeys | — | `GiveKeys(src, veh, skipNotif)` |
| oxmysql | — | persistência (`?` sempre) |

OneSync `on`, Entity Lockdown `relaxed` (compatível com `CreateVehicleServerSetter`).

---

## 3. Instalação

1. Importe `sql/migration.sql`.
2. O grupo `[standalone]` já é `ensure`d no `server.cfg` — **não duplique**. Para forçar: `ensure vp_electrician`.
3. (Opcional) log Discord sem token hardcoded:
   ```cfg
   set vp_electrician_webhook "https://discord.com/api/webhooks/..."
   ```
4. (Opcional) locale pt-BR: `setr ox:locale pt-br`.

---

## 4. Gameplay (fluxo completo)

```
NPC (ox_target) → menu → cria lobby → [convida ≤4] → escolhe região →
INICIAR → caminhão spawna (chave+fuel) → blips dos alvos →
dirige até cada alvo → minigame (3 tipos) →
  · poste de luz / poste telefônico exigem ESCADA / LIFT antes →
todos OK → blip de entrega + waypoint → devolve veículo →
recompensa ($ dividido + XP, persiste) → fim
```

**5 tipos de tarefa:**

| Tarefa | Local | Equipamento | Minigame |
|--------|-------|-------------|----------|
| `fixTrafo` | transformador de rua | — | Painel/voltímetro |
| `fixHouseBoard` | quadro de luz | — | Painel/voltímetro |
| `fixStreetLamp` | poste de luz (alto) | **escada** | Solda |
| `phonePole` | poste telefônico (alto) | **lift** | Solda |
| `fixTrafficLamp` | semáforo (pisca cor) | — | Fiação |

**Coop:** recompensa `base × coopMultiplier × nº players`, dividida no fim. Trava de concorrência por alvo (um por vez). Dono cai → missão encerra para todos.

---

## 5. Os 3 minigames (NUI custom — `html/`)

Todos reescritos do zero. Visual em CSS, **áudio sintetizado via WebAudio** (sem arquivos de som proprietários). Resultado unificado: `POST minigameResult { success }`.

### 5.1 Solda (`welding`) — poste de luz / telefônico
- Arrastar a "solda" de um terminal ao **terminal oposto** do mesmo fio.
- Timer regressivo + limite de tentativas (`maxFails`); sair da trilha = falha.
- Vitória: todos os fios soldados. Derrota: tempo ou tentativas esgotadas.

### 5.2 Painel/Voltímetro (`panel`) — transformador / quadro
- Passar o voltímetro sobre N painéis → o defeituoso lê voltagem **baixa**; os demais ~220 V.
- Clicar no defeituoso → remover 4 parafusos → trocar switch → reapertar 4 → sucesso.
- Clicar no painel **errado** = falha (choque).

### 5.3 Fiação (`wiring`) — semáforo
- Arrastar cada fio ao conector da **mesma cor** (embaralhados); linhas SVG ao vivo.
- Todos conectados = sucesso.

**Seleção por tarefa:** `Config.Minigames.byTask`. Fallback `skillcheck` (ox_lib) disponível.
**Falha** dispara `ApplyShockDamage()` (anim `electrocute` + `-10..25 HP`).

---

## 6. Arquitetura (server-authoritative)

O servidor é a única fonte de verdade. **Nunca confia** em `owneridentifier`/`coords` do client.

- `Lobbies[ownerCid]` = estado completo (players, região, missão, veículos).
- `PlayerLobby[citizenid]` = lookup reverso → o lobby é **derivado do `src`**, não enviado pelo client.
- Cada conserto revalida: lobby existe? job começou? alvo aberto **por este player**? **proximity server-side**? cooldown?
- Recompensa só é paga após o servidor confirmar veículo no ponto de entrega (anti pagamento-duplo via `lobby.paid`).

### Contrato de eventos/callbacks (nossos)

**Callbacks (ox_lib):**
| Nome | Função |
|------|--------|
| `vp_electrician:getProfile` | perfil + lobby + regiões |
| `vp_electrician:openTarget` | trava de concorrência + proximity + checa equipamento |

**Eventos servidor:**
`invite`, `acceptInvite`, `kickPlayer`, `selectMission`, `startJob`, `resetJob`, `completeTarget`, `closeTarget`, `buildEquipment`, `removeEquipment`, `deliverVehicle`.

**Eventos cliente:**
`receiveInvite`, `refreshLobby`, `leftLobby`, `jobStarted`, `targetUpdated`, `refreshScore`, `jobComplete`, `jobReset`, `rewardScreen`, `equipmentBuilt`, `equipmentRemoved`.

**NUI:** actions `START_WELD` / `START_PANEL` / `START_WIRING` / `CLOSE`; callback `minigameResult`.

---

## 7. Referência de configuração (`config/config.lua`)

| Chave | Descrição |
|-------|-----------|
| `Interaction` | coords, ped, blip, distância do target |
| `RequiredJob` | `'all'` ou `{ job = gradeMin }` |
| `MaxPlayersPerLobby` / `InviteMaxDistance` | limites de coop |
| `Cooldowns` | `selectMission`, `completeTarget` (≥2s), `build` |
| `Vehicle` | modelos primário/secundário, fuel |
| `Equipment` | modelos de escada/lift, distância de construção |
| `Minigames.byTask` | qual minigame cada tarefa usa |
| `Minigames.welding/panel/wiring` | parâmetros por tarefa |
| `Minigames.failDamage` | dano ao falhar |
| `MaxLevel` / `RequiredXP` | progressão (auto 1000 +500/nível) |
| `LogWebhookConvar` | nome da convar do webhook (sem token no código) |
| `Regions` | regiões (key, título, awards, spawn, delivery, jobTasks, pools) |
| `TargetRadius` / `RequiresEquipment` / `TrafficLightModels` | tabelas auxiliares |

---

## 8. Mapa de arquivos

```
config/config.lua      regiões, cooldowns, minigames, XP
shared/utils.lua       recompensa coop, sorteio, XP, comparação de coords
server/database.lua    queries oxmysql (?)
server/security.lua    getPlayer, rate limit, proximity, log
server/main.lua        lobby, convites, start, veículo
server/missions.lua    validação de conserto + equipamento
server/rewards.lua     entrega, pagamento, XP, persistência
client/main.lua        ped, ox_target, menu (ox_lib), lobby
client/mission.lua     blips, markers, fumaça, alvos, entrega, semáforo
client/equipment.lua   escada + lift (props sincronizados)
client/minigames.lua   roteador híbrido (NUI / skillcheck) + dano
html/                  index.html · style.css · app.js (3 minigames)
sql/migration.sql      tabela com PRIMARY KEY
```

---

## 9. Análise profunda do script base — paridade e roadmap

Resultado da varredura completa do `tw-electrician` (todos os eventos, NUI actions, natives e knobs), mapeando o que já temos e o que falta para fidelidade total.

### 9.1 Já implementado (paridade ✅)
- Lobby coop (criar, convidar por ID c/ proximidade, aceitar, expulsar, encerrar ao sair).
- Seleção de região + gate de nível mínimo.
- Spawn de veículo(s), chaves, combustível; 2º veículo se >2 players.
- 5 tipos de alvo com blips, marcadores e fumaça elétrica.
- Trava de concorrência por alvo (`open`/`openBy`).
- **3 minigames** (solda, painel/voltímetro, fiação) — equivalentes aos originais.
- Escada (prop sincronizado) para poste de luz.
- Semáforo piscando cor aleatória quando defeituoso.
- Dano de choque ao falhar minigame.
- Conclusão → entrega do veículo → recompensa dividida + XP/level + persistência.
- Multiplicador coop; reset de job; limpeza em `playerDropped`/`onResourceStop`.

### 9.2 Roadmap (atualizado)
| # | Item | Original | Estado | Obs |
|---|------|----------|--------|-----|
| 1 | **Lift móvel** (plataforma sobe/desce ↑↓, trilhos, sync) | sim | ✅ lógica do base | usa `SlideObject` em prop congelado + colisão (player sobe junto, SEM teleporte do ped), igual ao original |
| 2 | **HUD/Scoreboard ao vivo** (progresso `x/N` + score por player) | NUI | ✅ feito | verificado no preview |
| 3 | **Tela de recompensa** (earnings: $ + XP + reparos) | NUI `finishBox` | ✅ feito | verificado no preview |
| 4 | **Comando** de reset (`Config.JobResetCommand`) | sim | ✅ feito | `/eletricistareset` |
| 5 | **Blip do veículo** seguindo o caminhão | sim | ✅ feito | thread atualiza a cada 1.5s |
| 6 | **4 regiões** | 4 | ✅ feito | coords reais do original |
| 7 | Extras do veículo (`SetVehicleExtra`) | cosmético | ❌ opcional | trivial |
| 8 | `FindZForCoords` p/ marcador no chão de postes | sim | ⚠️ usa `GetGroundZ` no lift | baixo |
| 9 | Menu de lobby em **NUI custom** (hoje ox_lib context) | NUI Vue | ⚠️ funcional via ox_lib | opcional |

### 9.3 Intencionalmente NÃO portado (por design/limpeza)
- Backdoor RCE, token hardcoded, `PerformHttpRequest+load()` — **removidos por segurança**.
- Multi-framework (ESX/QB antigo) — só QBox/ox.
- `ExecuteSql` busy-wait — substituído por `MySQL.await`.
- Avatar do Discord no perfil — opcional, fora do escopo.
- `SetPlayerRoutingBucket` (no original era no-op/leftover).

---

## 10. Troubleshooting

| Sintoma | Causa provável |
|---------|----------------|
| Menu não abre | job exigido (`RequiredJob`) ou ox_target ausente |
| Veículo não spawna | Entity Lockdown muito restrito / modelo inválido |
| Sem combustível | ox_fuel espera statebag `fuel` (já setado no spawn) |
| Minigame não aparece | `ui_page`/`files` no manifest; cache NUI (restart) |
| Não paga recompensa | veículo precisa estar no ponto de entrega (validado server-side) |
| Texto em inglês | `setr ox:locale pt-br` |
