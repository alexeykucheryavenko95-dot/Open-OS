local component = require("component")
local event     = require("event")
local fs        = require("filesystem")

------------------------------------------------
-- OPENPERIPHERAL BRIDGE
------------------------------------------------
local bridge = component.openperipheral_bridge
if not bridge then
  io.stderr:write("[TPS_DAEMON] Нет openperipheral_bridge.\n")
  return
end

------------------------------------------------
-- ПОЗИЦИЯ (ПОД ЭНЕРГИЕЙ)
------------------------------------------------
local X_LABEL = 820
local Y_LABEL = 210
local X_VALUE = 920
local Y_VALUE = 210

------------------------------------------------
-- НАСТРОЙКИ
------------------------------------------------
local INTERVAL = 2   -- сек между замерами
local FILE = "/tmp/TF"

------------------------------------------------
-- ВРЕМЯ (как в оригинале)
------------------------------------------------
local function time()
  local f = io.open(FILE, "w")
  f:write("t")
  f:close()
  return fs.lastModified(FILE)
end

------------------------------------------------
-- HUD ЭЛЕМЕНТЫ
------------------------------------------------
local label = bridge.addText(X_LABEL, Y_LABEL, "TPS:")
label.setColor(0x9AA3FF)

local value = bridge.addText(X_VALUE, Y_VALUE, "---")
value.setColor(0xFFFFFF)

------------------------------------------------
-- СОСТОЯНИЕ
------------------------------------------------
local lastTime = time()

------------------------------------------------
-- ОСНОВНОЙ ТАЙМЕР
------------------------------------------------
event.timer(INTERVAL, function()
  local now = time()
  local diff = now - lastTime
  lastTime = now

  if diff <= 0 then diff = 1 end

  local tps = 20000 * INTERVAL / diff
  local sTPS = string.sub(tostring(tps), 1, 5)
  local nTPS = tonumber(sTPS) or 0

  -- цвет
  if nTPS <= 10 then
    value.setColor(0xCC4C4C)   -- красный
  elseif nTPS <= 15 then
    value.setColor(0xF2B233)   -- жёлтый
  else
    value.setColor(0x7FCC19)   -- зелёный
  end

  value.setText(sTPS)
end, math.huge)

------------------------------------------------
-- ДЕМОН ЖИВЁТ, ТЕРМИНАЛ СВОБОДЕН
------------------------------------------------
