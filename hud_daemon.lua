local component = require("component")
local event     = require("event")

------------------------------------------------
-- AE2 + HUD
------------------------------------------------

local me = component.me_controller or component.me_interface
if not me then
  io.stderr:write("[HUD] Нет доступа к AE2.\n")
  return
end

local bridge = component.openperipheral_bridge
if not bridge then
  io.stderr:write("[HUD] Нет openperipheral_bridge.\n")
  return
end

------------------------------------------------
-- SENSOR (для списка игроков)
------------------------------------------------

local sensorAddr = nil
for addr, ctype in component.list() do
  if ctype == "openperipheral_sensor" then
    sensorAddr = addr
    break
  end
end

------------------------------------------------
-- НАСТРОЙКИ
------------------------------------------------

local INTERVAL          = 3
local MAX_PLAYERS_LINES = 5

-- лазурит
local LAPIS_BLOCK_NAME = "minecraft:lapis_block"
local LAPIS_ITEM_NAME  = "minecraft:dye"
local LAPIS_ITEM_DMG   = 4

-- хладогенты
local COOLANT1_NAME = "dwcity:Scattering_crystal" -- старый
local COOLANT2_NAME = "dwcity:Dominant_crystal"   -- дракониевый

------------------------------------------------
-- РЕСУРСЫ НА HUD (на русском)
------------------------------------------------

local resources = {
  -- железо
  { label = "Железо",           id = "minecraft:iron_ingot",  dmg = 0, color = 0xAAAAAA },
  { label = "Железные блоки",   id = "minecraft:iron_block",  dmg = 0, color = 0xAAAAAA },

  -- медь (IC2)
  { label = "Медь",             id = "IC2:itemIngot",   dmg = 0, color = 0xFFA500 },
  { label = "Медные блоки",     id = "IC2:blockMetal",  dmg = 0, color = 0xFFA500 },

  -- лазурит
  { label = "Блоки лазурита",   id = "minecraft:lapis_block", dmg = 0, color = 0x3399FF },
  { label = "Лазурит",          id = "minecraft:dye",         dmg = 4, color = 0x3399FF },

  -- уран и материя
  { label = "U-235 (крупицы)",  id = "IC2:itemUran235small",  dmg = 0, color = 0x00FF00 },
  { label = "Материя",          id = "dwcity:Materia",        dmg = 0, color = 0xFF00FF },
}

------------------------------------------------
-- ВСПОМОГАТЕЛЬНЫЕ
------------------------------------------------

local function addIcon(x, y, name, meta)
  return bridge.addIcon(x, y, name, meta or 0)
end

local function getItemCount(name, dmg)
  local filter = { name = name }
  if dmg ~= nil then
    filter.damage = dmg
  end

  local list = me.getItemsInNetwork(filter)
  local total = 0
  if list then
    for _, st in ipairs(list) do
      total = total + (st.size or 0)
    end
  end
  return total
end

local function getPlayerNames()
  if not sensorAddr then return {} end

  local ok, res = pcall(component.invoke, sensorAddr, "getPlayers")
  if not ok or type(res) ~= "table" then return {} end

  local names = {}
  for _, p in pairs(res) do
    if p.name then names[#names+1] = tostring(p.name) end
  end

  local uniq, out = {}, {}
  for _, n in ipairs(names) do
    if n ~= "" and not uniq[n] then
      uniq[n] = true
      out[#out+1] = n
    end
  end

  table.sort(out)
  return out
end

-- считаем оба вида хладогента отдельно одним проходом
local function getCoolantCounts()
  local list = me.getItemsInNetwork()
  local c1, c2 = 0, 0

  if not list then return 0, 0 end

  for _, st in ipairs(list) do
    if st and st.name and st.size then
      if st.name == COOLANT1_NAME then
        c1 = c1 + st.size
      elseif st.name == COOLANT2_NAME then
        c2 = c2 + st.size
      end
    end
  end

  return c1, c2
end

------------------------------------------------
-- HUD ЭЛЕМЕНТЫ
------------------------------------------------

local hud = {
  icons         = {},
  texts         = {},
  lapisIcon     = nil,
  lapisText     = nil,
  coolIcon1     = nil,
  coolText1     = nil,
  coolIcon2     = nil,
  coolText2     = nil,
  playersHeader = nil,
  playersLines  = {},
  inited        = false,
}

------------------------------------------------
-- ИНИЦИАЛИЗАЦИЯ HUD
------------------------------------------------

local function initHUD()
  bridge.clear()

  local xIcon = 5
  local xText = 24
  local y     = 80

  -- ресурсы
  for i, r in ipairs(resources) do
    hud.icons[i] = addIcon(xIcon, y - 2, r.id, r.dmg)
    hud.texts[i] = bridge.addText(xText, y, r.label .. ": ---", r.color)
    y = y + 14
  end

  -- общий лазурит
  hud.lapisIcon = addIcon(xIcon, y - 2, LAPIS_BLOCK_NAME, 0)
  hud.lapisText = bridge.addText(xText, y, "Всего лазурита: ---", 0x3399FF)
  y = y + 14

  -- хладогент 1 (старый)
  hud.coolIcon1 = addIcon(xIcon, y - 2, COOLANT1_NAME, 0)
  hud.coolText1 = bridge.addText(xText, y, "Хладогент: ---", 0x00FFFF)
  y = y + 14

  -- хладогент 2 (дракониевый)
  hud.coolIcon2 = addIcon(xIcon, y - 2, COOLANT2_NAME, 0)
  hud.coolText2 = bridge.addText(xText, y, "Дракониевый хладогент: ---", 0xFF00FF)
  y = y + 18

  -- игроки
  hud.playersHeader = bridge.addText(xIcon, y, "Дома: 0 чел.", 0xFFFF00)
  y = y + 12

  for i = 1, MAX_PLAYERS_LINES do
    hud.playersLines[i] = bridge.addText(xIcon, y, "", 0xFFFFFF)
    y = y + 10
  end

  bridge.sync()
  hud.inited = true
end

------------------------------------------------
-- ОБНОВЛЕНИЕ HUD
------------------------------------------------

local function updateHUD()
  if not hud.inited then return end

  -- ресурсы
  for i, r in ipairs(resources) do
    local count = getItemCount(r.id, r.dmg)
    hud.texts[i].setText(string.format("%s: %d", r.label, count))
  end

  -- перерасчёт лазурита
  local lapisBlocks = getItemCount(LAPIS_BLOCK_NAME, 0)
  local lapisItems  = getItemCount(LAPIS_ITEM_NAME, LAPIS_ITEM_DMG)
  local totalItems  = lapisItems + lapisBlocks * 9
  local totalBlocks = math.floor(totalItems / 9)
  local restItems   = totalItems % 9

  hud.lapisText.setText(string.format("Всего лазурита: %dБ + %d", totalBlocks, restItems))

  -- хладогенты по отдельности
  local c1, c2 = getCoolantCounts()
  hud.coolText1.setText("Хладогент: " .. c1)
  hud.coolText2.setText("Дракониевый хладогент: " .. c2)

  -- игроки
  local names = getPlayerNames()
  hud.playersHeader.setText("Дома: " .. #names .. " чел.")
  for i = 1, MAX_PLAYERS_LINES do
    hud.playersLines[i].setText(names[i] or "")
  end

  bridge.sync()
end

------------------------------------------------
-- ЗАПУСК
------------------------------------------------

initHUD()
updateHUD()
event.timer(INTERVAL, updateHUD, math.huge)

print("[HUD] Демон HUD запущен.")
