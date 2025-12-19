local c  = require("component")
local fs = require("filesystem")
local keyboard = require("keyboard")

local bridge = c.openperipheral_bridge
if not bridge then
  io.stderr:write("[TPS_HUD] Нет openperipheral_bridge.\n")
  return
end

-- === ПОЗИЦИЯ ПОД ЭНЕРГИЕЙ ===
local X_LABEL = 820
local Y_LABEL = 210
local X_VALUE = 920
local Y_VALUE = 210

local TC, RO, RN, RD = 2, 0, 0, 0
local TPS = 0

local function time()
  local f = io.open("/tmp/TF", "w")
  f:write("t")
  f:close()
  return fs.lastModified("/tmp/TF")
end

-- HUD строки
local label = bridge.addText(X_LABEL, Y_LABEL, "TPS:")
label.setColor(0x9AA3FF)

local value = bridge.addText(X_VALUE, Y_VALUE, "---")
value.setColor(0xFFFFFF)

while true do
  RO = time()
  os.sleep(TC)
  RN = time()

  RD = RN - RO
  if RD <= 0 then RD = 1 end

  TPS = 20000 * TC / RD
  local sTPS = string.sub(tostring(TPS), 1, 5)
  local nTPS = tonumber(sTPS) or 0

  if nTPS <= 10 then
    value.setColor(0xCC4C4C)   -- красный
  elseif nTPS <= 15 then
    value.setColor(0xF2B233)   -- жёлтый
  else
    value.setColor(0x7FCC19)   -- зелёный
  end

  value.setText(sTPS)

  if keyboard.isControlDown() and keyboard.isKeyDown(keyboard.keys.w) then
    value.setText("exit")
    value.setColor(0xFFFFFF)
    break
  end
end
