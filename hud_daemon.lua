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

local INTERVAL          = 1
local MAX_PLAYERS_LINES = 5

-- константы для лазурита
local LAPIS_BLOCK_NAME = "minecraft:lapis_block"
local LAPIS_ITEM_NAME  = "minecraft:dye"
local LAPIS_ITEM_DMG   = 4  -- лазурит 1.7.10

-- хладогент
local COOLANT_NAME = "dwcity:Scattering_crystal"

------------------------------------------------
-- РЕСУРСЫ НА HUD
------------------------------------------------

local resources = {
  -- железо
  { label = "Iron",       id = "minecraft:iron_ingot",  dmg = 0, color = 0xAAAAAA },
  { label = "IronBlock",  id = "minecraft:iron_block",  dmg = 0, color = 0xAAAAAA },

  -- медь (IC2:blockMetal meta 0 = медный блок)
  { label = "Copper",       id = "IC2:itemIngot",   dmg = 0, color = 0xFFA500 },
  { label = "CopperBlock",  id = "IC2:blockMetal",  dmg = 0, color = 0xFFA500 },

  -- лазурит
  { label = "LapisBlock", id = "minecraft:lapis_block", dmg = 0, color = 0x3399FF },
  { label = "Lapis",      id = "minecraft:dye",         dmg = 4, color = 0x3399FF },

  -- уран и материя
  { label = "U235tiny",   id = "IC2:itemUran235small",  dmg = 0, color = 0x00FF00 },
  { label = "Materia",    id = "dwcity:Materia",        dmg = 0, color = 0xFF00FF },
}

------------------------------------------------
-- ВСПОМОГАТЕЛЬНЫЕ
------------------------------------------------

local function addIcon(x, y, name, meta)
  return bridge.addIcon(x, y, name, meta or 0)
end

local function getItemCount(name, dmg)
  local list = me.getItemsInNetwork({ name = name, damage = dmg })
  local total = 0
  if list then
    for _, st in ipairs(list) do
      total = total + (st.size or 0)
    end
  end
  return total
end

local function getPlayerNames()
  if not sensorAddr then
    return {}
  end

  local ok, res = pcall(component.invoke, sensorAddr, "getPlayers")
  if not ok or type(res) ~= "table" then
    return {}
  end

  local names = {}
  for _, p in pairs(res) do
    if type(p) == "table" and p.name then
      names[#names+1] = tostring(p.name)
    end
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

------------------------------------------------
-- HUD ЭЛЕМЕНТЫ
------------------------------------------------

local hud = {
  icons         = {},
  texts         = {},
  lapisIcon     = nil,
  lapisText     = nil,
  coolIcon      = nil,
  coolText      = nil,
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
    hud.icons[i] = addIcon(xIcon, y - 2, r.id, r.dmg or 0)
    hud.texts[i] = bridge.addText(xText, y, r.label .. ": ---", r.color)
    y = y + 14
  end

  -- общий лазурит (в блоках)
  hud.lapisIcon = addIcon(xIcon, y - 2, LAPIS_BLOCK_NAME, 0)
  hud.lapisText = bridge.addText(xText, y, "LapisBlocksTotal: ---", 0x3399FF)
  y = y + 14

  -- хладогент
  hud.coolIcon  = addIcon(xIcon, y - 2, COOLANT_NAME, 0)
  hud.coolText  = bridge.addText(xText, y, "Хладогент: ---", 0x00FFFF)
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

  -- общий лазурит → в блоки
  local lapisBlocks = getItemCount(LAPIS_BLOCK_NAME, 0)
  local lapisItems  = getItemCount(LAPIS_ITEM_NAME, LAPIS_ITEM_DMG)
  local totalItems  = lapisItems + lapisBlocks * 9
  local totalBlocks = math.floor(totalItems / 9)
  local restItems   = totalItems % 9

  hud.lapisText.setText(string.format("LapisBlocksTotal: %dB + %d", totalBlocks, restItems))

  -- хладогент
  local coolant = getItemCount(COOLANT_NAME, 0)
  hud.coolText.setText("Хладогент: " .. coolant)

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
