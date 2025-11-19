-- combined_daemon.lua
-- Объединённый демон: HUD + Energy, оптимизированный для меньшей нагрузки

local component = require("component")
local event     = require("event")
local unicode   = require("unicode")

-- Настройки (можно править)
local INTERVAL         = 1        -- базовый тик в секундах
local RES_INTERVAL     = 5        -- как часто обновлять ресурсы AE2 (медленнее, т.к. дорогие запросы)
local PLAYERS_INTERVAL = 2        -- как часто опрашивать датчик игроков
local CFG_PATH         = "/home/daemon_cfg.lua"

-- Адреса счётчиков энергии (замените на свои)
local REACTOR_ADDR = "2742795d-8024-4750-af42-02bf180f266c"
local PANEL_ADDR   = "c7239038-119c-486d-9f7c-9d1b0d498409"

-- Ресурсы (AE2)
local resources = {
  { label = "Iron",       name = "minecraft:iron_ingot",  damage = 0, color = 0xAAAAAA },
  { label = "Copper",     name = "IC2:itemIngot",         damage = 0, color = 0xFFA500 },
  { label = "LapisBlock", name = "minecraft:lapis_block", damage = 0, color = 0x3399FF },
  { label = "U235tiny",   name = "IC2:itemUran235small",  damage = 0, color = 0x00FF00 },
  { label = "Materia",    name = "dwcity:Materia",        damage = 0, color = 0xFF00FF },
}

-- Проверка bridge (нужен для HUD/текста)
local bridge = component.openperipheral_bridge
if not bridge then
  io.stderr:write("[COMBINED] Нет openperipheral_bridge. Скрипт не может работать.\n")
  return
end

local HAS_ADD_ITEM = type(bridge.addItem) == "function"

-- Поиск AE2 и sensor (может отсутствовать)
local me = component.me_controller or component.me_interface
local sensorAddr = nil
for addr, ctype in component.list() do
  if ctype == "openperipheral_sensor" then
    sensorAddr = addr
    break
  end
end

-- Лёгкая загрузка конфигурации (редко)
local function loadCfg()
  local ok, cfg = pcall(dofile, CFG_PATH)
  if ok and type(cfg) == "table" then
    if cfg.auto_enabled == nil then cfg.auto_enabled = true end
    if cfg.hud_enabled  == nil then cfg.hud_enabled  = true end
    return cfg
  end
  return { auto_enabled = true, hud_enabled = true }
end

-- Безопасное чтение getAverage
local function readEnergy(addr)
  if not addr then return 0 end
  local ok, val = pcall(component.invoke, addr, "getAverage")
  if not ok then return 0 end
  local n = tonumber(val)
  if not n then return 0 end
  return math.floor(n)
end

-- Получение количества предметов из AE2 (дорогая операция)
local function getItemCount(name, dmg)
  if not me then return 0 end
  local ok, list = pcall(me.getItemsInNetwork, me, { name = name, damage = dmg })
  if not ok or type(list) ~= "table" then return 0 end
  local total = 0
  for _, st in ipairs(list) do
    total = total + (st.size or 0)
  end
  return total
end

-- Получение имён игроков через sensor (с фильтрацией)
local function getPlayerNames()
  if not sensorAddr then return {} end
  local ok, res = pcall(component.invoke, sensorAddr, "getPlayers")
  if not ok or type(res) ~= "table" then
    ok, res = pcall(component.invoke, sensorAddr, "getPlayers", 32)
    if not ok or type(res) ~= "table" then return {} end
  end
  local uniq = {}
  local out = {}
  for _, p in pairs(res) do
    if type(p) == "table" and p.name and p.name ~= "" and not uniq[p.name] then
      uniq[p.name] = true
      out[#out+1] = tostring(p.name)
    end
  end
  table.sort(out)
  return out
end

-- HUD элементы (инициализируются один раз)
local hud = {
  resTexts      = {},
  resIcons      = {},
  playersHeader = nil,
  playersLines  = {},
  autoStatus    = nil,
  txtReactor    = nil,
  txtPanels     = nil,
  txtTotal      = nil,
  inited        = false,
}

local function initHUD()
  bridge.clear()
  local xIcon = 5
  local xText = 14
  local y = 80

  -- ресурсы (иконки + текст)
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

  for i = 1, math.max(3, 5) do  -- гарантируем хотя бы несколько линий
    hud.playersLines[i] = bridge.addText(xIcon, y, "", 0xFFFFFF)
    y = y + 10
  end

  y = y + 4
 

