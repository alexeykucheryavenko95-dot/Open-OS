local component = require("component")
local event     = require("event")

local glasses = component.glasses
if not glasses then
  io.stderr:write("energy_daemon: glasses not found\n")
  return
end

-- ВПИШИ адреса адаптеров, стоящих на IC2 energy counter:
-- reactorAdapter  — счётчик от реакторов
-- solarAdapter    — счётчик от панелей
local cfg = {
  reactorAdapter = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  solarAdapter   = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy",
}

local reactor, solar

if component.type(cfg.reactorAdapter) == "adapter" then
  reactor = component.proxy(cfg.reactorAdapter)
end
if component.type(cfg.solarAdapter) == "adapter" then
  solar = component.proxy(cfg.solarAdapter)
end

if not reactor or not solar then
  io.stderr:write("energy_daemon: check adapter addresses in cfg\n")
  return
end

-- Пытаемся угадать метод счётчика
local function readCounter(proxy)
  if proxy.getEnergy then
    return proxy.getEnergy()
  elseif proxy.getEU then
    return proxy.getEU()
  elseif proxy.getOutput then
    return proxy.getOutput()
  elseif proxy.getValue then
    return proxy.getValue()
  end
  return 0
end

-- Три строки в очках
local lineReactor = glasses.addTextLabel()
lineReactor.setPosition(2, 60)
lineReactor.setScale(1)

local lineSolar = glasses.addTextLabel()
lineSolar.setPosition(2, 70)
lineSolar.setScale(1)

local lineTotal = glasses.addTextLabel()
lineTotal.setPosition(2, 80)
lineTotal.setScale(1)

local function updateEnergy()
  local r = 0
  local s = 0

  pcall(function() r = readCounter(reactor) or 0 end)
  pcall(function() s = readCounter(solar)   or 0 end)

  local total = r + s

  lineReactor.setText(string.format("Reactors: %.0f EU/t", r))
  lineSolar.setText(string.format("Solars:   %.0f EU/t", s))
  lineTotal.setText(string.format("Total:    %.0f EU/t", total))
end

event.timer(1, function() pcall(updateEnergy) end, math.huge)
