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

local HAS_ADD_ITEM = type(bridge.addItem) == "function"

------------------------------------------------
-- SENSOR
------------------------------------------------

local sensorAddr = nil
for addr, ctype in component.list() do
  if ctype == "openperipheral_sensor" then
    sensorAddr = addr
    break
  end
end

------------------------------------------------
-- КОНФИГ
------------------------------------------------

local CFG_PATH = "/home/daemon_cfg.lua"

local function loadCfg()
  local ok, cfg = pcall(dofile, CFG_PATH)
  if ok and type(cfg) == "table" then
    if cfg.auto_enabled == nil then cfg.auto_enabled = true end
    if cfg.hud_enabled  == nil then cfg.hud_enabled  = true end
    return cfg
  end
  return { auto_enabled = true, hud_enabled = true }
end

------------------------------------------------
-- НАСТРОЙКИ
------------------------------------------------

local INTERVAL          = 1
local MAX_PLAYERS_LINES = 5

local resources = {
  { label = "Iron",       name = "minecraft:iron_ingot",  damage = 0, color = 0xAAAAAA },
  { label = "Copper",     name = "IC2:itemIngot",         damage = 0, color = 0xFFA500 },
  { label = "LapisBlock", name = "minecraft:lapis_block", damage = 0, color = 0x3399FF },
  { label = "U235tiny",   name = "IC2:itemUran235small",  damage = 0, color = 0x00FF00 },
  { label = "Materia",    name = "dwcity:Materia",        damage = 0, color = 0xFF00FF },
}

------------------------------------------------
-- ВСПОМОГАТЕЛЬНЫЕ
------------------------------------------------

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
    ok, res = pcall(component.invoke, sensorAddr, "getPlayers", 32)
    if not ok or type(res) ~= "table" then
      return {}
    end
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
  resTexts      = {},
  resIcons      = {},
  playersHeader = nil,
  playersLines  = {},
  autoStatus    = nil,
  inited        = false,
}

local function initHUD()
  bridge.clear()

  local xIcon = 5
  local xText = 14
  local y     = 80

  -- ресурсы
  for i, r in ipairs(resources) do
    if HAS_ADD_ITEM then
      hud.resIcons[i] = bridge.addItem(xIcon, y - 2, r.name, r.damage or 0)
    end
    hud.resTexts[i] = bridge.addText(xText, y, r.label .. ": ---", r.color)
    y = y + 14
  end

  y = y + 6
  hud.playersHeader = bridge.addText(xIcon, y, "Дома: 0 чел.", 0xFFFF00)
  y = y + 10

  for i = 1, MAX_PLAYERS_LINES do
    hud.playersLines[i] = bridge.addText(xIcon, y, "", 0xFFFFFF)
    y = y + 10
  end

  y = y + 4
  hud.autoStatus = bridge.addText(xIcon, y, "[AUTO] ?", 0x00FF00)

  bridge.sync()
  hud.inited = true
end

------------------------------------------------
-- ОБНОВЛЕНИЕ
------------------------------------------------

local function updateHUD()
  if not hud.inited then return end

  local cfg = loadCfg()

  -- ресурсы
  for i, r in ipairs(resources) do
    local count = getItemCount(r.name, r.damage)
    hud.resTexts[i].setText(string.format("%s: %d", r.label, count or 0))
  end

  -- игроки
  local names = getPlayerNames()
  hud.playersHeader.setText(string.format("Дома: %d чел.", #names))

  for i = 1, MAX_PLAYERS_LINES do
    if i <= #names then
      hud.playersLines[i].setText(names[i])
    else
      hud.playersLines[i].setText("")
    end
  end

  -- статус AUTO
  if cfg.auto_enabled then
    hud.autoStatus.setText("[AUTO] ВКЛ")
  else
    hud.autoStatus.setText("[AUTO] ВЫКЛ")
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
