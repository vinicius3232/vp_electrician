# vp_electrician

Job cooperativo de eletricista por região — **rebuild nativo QBox/ox** inspirado na gameplay do `tw-electrician`, escrito do zero, **sem backdoor** e sem código/assets do produto original vazado.

> ⚠️ O `tw-electrician` original continha um backdoor de execução remota (`PerformHttpRequest` + `load()` para `fivehub-panel.site`) e um token de bot Discord hardcoded. **Nada disso foi reaproveitado aqui.** Apenas coordenadas de mundo (dados públicos do mapa) foram reutilizadas.

## Stack (versões deste servidor)
- qbx_core 1.23.0 · ox_lib 3.32.2 · ox_inventory 2.44.8 · ox_target · ox_fuel · qbx_vehiclekeys · oxmysql

## Instalação
1. Importe o SQL:
   ```sql
   -- sql/migration.sql
   ```
2. `server.cfg` (dentro do grupo `[standalone]` já é `ensure`d automaticamente; **não** duplique):
   ```
   ensure vp_electrician
   ```
3. (Opcional) log via Discord, sem token hardcoded:
   ```
   set vp_electrician_webhook "https://discord.com/api/webhooks/..."
   ```

## Gameplay (resumo)
Pega ordem de serviço num NPC → cria lobby (até 4) → escolhe região → caminhão spawna → conserta alvos (transformador, quadro, poste de luz, semáforo, poste telefônico) via minigame → poste de luz/telefônico exigem **escada/lift** → todos OK → entrega o caminhão → recompensa (dinheiro dividido + XP, recompensa multiplica em coop).

## Arquitetura
- **Server-authoritative**: o servidor mantém `Lobbies[ownerCid]` e revalida lobby, proximity, cooldown e trava de concorrência em cada conserto. O client nunca decide recompensa.
- **Minigames** (seletor por tarefa em `Config.Minigames.byTask`) — **3 NUI custom** (`html/`), resultado unificado em `POST minigameResult`:
  - `welding` (solda, arrastar terminal→oposto) → `fixStreetLamp`, `phonePole`
  - `panel` (voltímetro: achar painel defeituoso + parafusos + switch) → `fixTrafo`, `fixHouseBoard`
  - `wiring` (arrastar fio ao conector da mesma cor) → `fixTrafficLamp`
  - `skillcheck` (ox_lib) fica como fallback.
- **Segurança** (`server/security.lua`): `getPlayer`, rate limit, proximity server-side, log opcional.

## Status por fase
| Fase | Item | Estado |
|------|------|--------|
| 1 | Fundação (manifest, config, SQL, ox_target, ped) | ✅ |
| 2 | Lobby coop (convite/aceite/kick/região/scoreboard) | ✅ (scoreboard = notify; NUI futura) |
| 3 | Missão (spawn veículo+keys+fuel, blips, fumaça, alvos) | ✅ |
| 4 | Minigames + 5 tarefas | ✅ **3 minigames NUI custom** (solda, painel/voltímetro, fiação) |
| 5 | Escada + Lift | ✅ escada + **lift móvel** (sobe/desce, sync) — ride a ajustar in-game |
| 6 | Recompensa + XP/level + persistência + hardening | ✅ |
| + | HUD ao vivo + tela de recompensa + 4 regiões + comando reset + blip do veículo | ✅ |

## TODO de fidelidade (restante, opcional)
- Ajuste fino da "pegada" do lift (carregar o player) — precisa de teste no jogo.
- Extras cosméticos do veículo; menu de lobby em NUI custom (hoje ox_lib).
- Elevador (lift) móvel com controle de altura.
- Scoreboard/HUD visual ao vivo.
- Mais regiões em `config/config.lua` (formato pronto, 2 incluídas).
