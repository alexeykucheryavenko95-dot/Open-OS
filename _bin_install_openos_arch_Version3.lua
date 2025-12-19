-- install_openos_arch.lua
-- Установщик "архитектуры" OpenOS из raw GitHub
-- Usage:
--   install_openos_arch.lua [--yes|-y] [base_raw_url]
--   install_openos_arch.lua --uninstall [base_raw_url]
-- По умолчанию base_raw_url = "https://raw.githubusercontent.com/alexeykucheryavenko95-dot/Open-OS/master"
local component = require("component")
local fs = require("filesystem")
local io = io
local os = os
local term = require("term")

local DEFAULT_BASE = "https://raw.githubusercontent.com/alexeykucheryavenko95-dot/Open-OS/master"

-- Список файлов в репозитории (относительно base_raw_url)
local files = {
  "/init.lua",
  "/etc/services.lua",
  "/bin/sample_daemon.lua",
  "/bin/modem_server.lua",
  "/bin/sysmon.lua",
  "/bin/menu.lua",
  "/bin/backup.lua",
  "/bin/gpu_progress.lua",
  "/bin/fm.lua",
  "/bin/update.lua",
}

local function ensureDir(path)
  if not path then return end
  if fs.exists(path) then return end
  fs.makeDirectory(path)
end

local function backupIfExists(path)
  if fs.exists(path) then
    local bak = path .. ".bak." .. tostring(os.time())
    local ok, err = fs.rename(path, bak)
    if ok then
      io.write("Backup: " .. path .. " -> " .. bak .. "\n")
    else
      io.write("Backup failed for " .. path .. ": " .. tostring(err) .. "\n")
    end
  end
end

local function writeAtomic(path, content)
  local dir = path:match("(.*/)")
  if dir then ensureDir(dir) end
  local tmp = path .. ".tmp." .. tostring(os.time())
  local f, err = io.open(tmp, "wb")
  if not f then return false, "open tmp failed: "..tostring(err) end
  f:write(content)
  f:close()
  if fs.exists(path) then pcall(fs.remove, path) end
  local ok, rerr = fs.rename(tmp, path)
  if not ok then return false, "rename failed: "..tostring(rerr) end
  return true
end

local function downloadToString(internet, url)
  local ok, handle_or_err = pcall(internet.request, internet, url)
  if not ok or not handle_or_err then
    return nil, tostring(handle_or_err)
  end
  local handle = handle_or_err
  local chunks = {}
  local status, err = pcall(function()
    for chunk in handle do
      if chunk then table.insert(chunks, chunk) end
    end
  end)
  if type(handle) == "table" and handle.close then pcall(handle.close, handle) end
  if not status then return nil, tostring(err) end
  return table.concat(chunks, "")
end

local function normalizeBase(b)
  if not b or b == "" then return DEFAULT_BASE end
  if b:sub(-1) == "/" then return b:sub(1, -2) end
  return b
end

local function installFromBase(base)
  if not component.isAvailable("internet") then
    io.write("Компонент internet недоступен. Установка невозможна.\n")
    return
  end
  local internet = component.internet
  local base_norm = normalizeBase(base)
  io.write("Base URL: " .. base_norm .. "\n")
  ensureDir("/bin"); ensureDir("/etc"); ensureDir("/var/log")

  for _, path in ipairs(files) do
    local rel = path:gsub("^/", "")
    local url = base_norm .. "/" .. rel
    io.write("Скачиваю " .. url .. " ... ")
    local content, err = downloadToString(internet, url)
    if not content then
      io.write("ERROR: " .. tostring(err) .. "\n")
    else
      backupIfExists(path)
      local ok, werr = writeAtomic(path, content)
      if ok then
        io.write("OK (" .. tostring(#content) .. " bytes)\n")
      else
        io.write("WRITE ERROR: " .. tostring(werr) .. "\n")
      end
    end
  end
  io.write("\nУстановка завершена. Рекомендуется перезагрузить OpenComputers-компьютер.\n")
  io.write("Логи загрузки будут в /var/log/boot.log\n")
end

local function uninstallRestore()
  io.write("Режим --uninstall: пытаюсь восстановить бэкапы или удалить установленные файлы.\n")
  for _, path in ipairs(files) do
    local dir = path:match("(.*/)") or ""
    local prefix = path .. ".bak."
    local latest = nil
    -- ищем в каталоге dir файлы с префиксом
    local listIter
    local ok, res = pcall(function() return fs.list(dir == "" and "/" or dir) end)
    if ok then listIter = res end
    if listIter then
      for f in listIter do
        local full = (dir == "" and "" or dir) .. f
        if full:sub(1, #prefix) == prefix then
          if not latest or full > latest then latest = full end
        end
      end
    end
    if latest then
      pcall(fs.remove, path)
      local ok2, err2 = fs.rename(latest, path)
      if ok2 then io.write("Restored: " .. latest .. " -> " .. path .. "\n")
      else io.write("Restore failed: " .. tostring(err2) .. "\n") end
    else
      if fs.exists(path) then
        local ok3, err3 = fs.remove(path)
        if ok3 then io.write("Removed: " .. path .. "\n")
        else io.write("Remove failed: " .. tostring(err3) .. "\n") end
      else
        io.write("Нет файла и бэкапа для: " .. path .. "\n")
      end
    end
  end
  io.write("Uninstall завершён.\n")
end

-- Парсинг аргументов
local args = {...}
local auto = false
local uninstall = false
local base_arg = nil
for i,a in ipairs(args) do
  if a == "--yes" or a == "-y" then auto = true
  elseif a == "--uninstall" then uninstall = true
  else base_arg = a
  end
end

local base = normalizeBase(base_arg or DEFAULT_BASE)

if uninstall then
  if not auto then
    io.write("Подтвердите восстановление/удаление (Enter) или Ctrl+C для отмены: ")
    io.read()
  end
  uninstallRestore()
  return
end

if not component.isAvailable("internet") then
  io.write("Компонент internet недоступен. Убедитесь, что у компьютера есть Internet Card и доступ в сеть.\n")
  return
end

if not auto then
  io.write("Этот скрипт скачает и перезапишет файлы:\n")
  for _,p in ipairs(files) do io.write("  "..p.."\n") end
  io.write("\nSource base: " .. base .. "\n")
  io.write("Установка начнётся через 5 секунд. Нажмите Ctrl+C для отмены.\n")
  for i=5,1,-1 do io.write(i.."... "); os.sleep(1) end
  io.write("\nНачинаю загрузку...\n")
end

installFromBase(base)