local c, fs = require("component"), require("filesystem")
local gpu = c.gpu
local TC, RO, RN, RD, TPS = 2, 0, 0, 0

gpu.setForeground(0x99b2f2)
gpu.set(1, 2, "TPS Сервера:")
local function time()
    local f = io.open("/tmp/TF", "w")
    f:write("test")
    f:close()
    return(fs.lastModified("/tmp/TF"))
end

while true do
    RO = time()
    os.sleep(TC) 
    RN = time()
    RD = RN - RO
    TPS = 20000 * TC / RD
    TPS = string.sub(TPS, 1, 5)
    nTPS = tonumber(TPS)
    gpu.set(13, 2, "     ")
    if nTPS <= 10 then
        gpu.setForeground(0xcc4c4c)
    elseif nTPS <= 15 then
        gpu.setForeground(0xf2b233)
    elseif nTPS > 15 then 
        gpu.setForeground(0x7fcc19)
    end
    gpu.set(13, 2, TPS)
end