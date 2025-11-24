local component = require("component")
local event     = require("event")

local bridge = component.openperipheral_bridge
if not bridge then
  io.stderr:write("[ENERGY] Нет openperipheral_bridge.\n")
  return
end

------------------------------------------------
-- АДРЕСА СЧЁТЧИКОВ
------------------------------------------------
local REACTOR_ADDR = "2618285e-5cdd-4769-8d3a-4973b07eaea8"  -- реакторы
local PANEL_ADDR   = "c7239038-119c-486d-9f7c-9d1b0d498409"  -- панели

------------------------------------------------
-- ЧТЕНИЕ getAverage()
------------------------------------------------
local function readEnergy(addr)
  if not addr then return 0 end
  local ok, val = pcall(component.invoke, addr, "getAverage")
  if not ok then return 0 end
  local n = tonumber(val)
  return n and math.floor(n) or 0
end

------------------------------------------------
-- HUD
------------------------------------------------
local x = 820
local y = 180

local txtReactor = bridge.addText(x, y,   "[EU] Реакторы: ---", 0x00FFFF); y = y + 10
local txtPanels  = bridge.addText(x, y,   "[EU] Панели:   ---", 0x00FFFF); y = y + 10
local txtTotal   = bridge.addText(x, y,   "[EU] Итого:    ---", 0x00FFFF)

bridge.sync()

------------------------------------------------
-- ОБНОВЛЕНИЕ КАЖДУЮ СЕКУНДУ
------------------------------------------------
local function update()
  local reactor = readEnergy(REACTOR_ADDR)
  local panels  = readEnergy(PANEL_ADDR)
  local total   = reactor + panels

  txtReactor.setText(string.format("[EU] Реакторы: %d EU/t", reactor))
  txtPanels.setText (string.format("[EU] Панели:   %d EU/t", panels))
  txtTotal.setText  (string.format("[EU] Итого:    %d EU/t", total))

  bridge.sync()
end

update()
event.timer(1, update, math.huge)

print("[ENERGY] Демон энергии запущен.")
