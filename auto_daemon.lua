local component = require("component")
local event     = require("event")

local me = component.me_controller or component.me_interface
if not me then
  io.stderr:write("auto_daemon: ME controller/interface not found\n")
  return
end

-- Список рецептов: tiny → dust (через автокрафт в ME)
local recipes = {
  { tinyLabel = "Tiny Pile of Iron Dust",    dustLabel = "Iron Dust"    },
  { tinyLabel = "Tiny Pile of Copper Dust",  dustLabel = "Copper Dust"  },
  { tinyLabel = "Tiny Pile of Tin Dust",     dustLabel = "Tin Dust"     },
  { tinyLabel = "Tiny Pile of Gold Dust",    dustLabel = "Gold Dust"    },
  { tinyLabel = "Tiny Pile of Lead Dust",    dustLabel = "Lead Dust"    },
  { tinyLabel = "Tiny Pile of Silver Dust",  dustLabel = "Silver Dust"  },
  { tinyLabel = "Tiny Pile of Sulfur Dust",  dustLabel = "Sulfur Dust"  },
}

local function getCountByLabel(label)
  local items = me.getItemsInNetwork({label = label}) or {}
  if #items > 0 and items[1].size then
    return items[1].size
  end
  return 0
end

local function tick()
  for _, r in ipairs(recipes) do
    local tinyCount = getCountByLabel(r.tinyLabel)
    if tinyCount >= 9 then
      local craftAmount = math.floor(tinyCount / 9)
      pcall(function()
        me.requestCrafting({label = r.dustLabel}, craftAmount)
      end)
    end
  end
end

-- каждые 5 секунд, демон не блокирует терминал
event.timer(5, function() pcall(tick) end, math.huge)
