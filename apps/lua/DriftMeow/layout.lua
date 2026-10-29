local M = {}

local started = false
local placed = false
local lastScreen = ''

local WIN_ID = 'main'
local WIN_TITLE = 'DriftMeow'
local WIN_W, WIN_H = 844, 92
local MARGIN_BOTTOM = 0
local MARGIN_SIDE = 32

local function findWindow()
  local ok, windows = pcall(ac.getAppWindows)
  if not ok or type(windows) ~= 'table' then return nil end
  for _, w in ipairs(windows) do
    if w.title == WIN_TITLE or w.name == WIN_ID then return w end
  end
end

function M.update(prefs)
  -- 1. автоматически открыть окно при запуске
  if not started then
    started = true
    pcall(ac.setWindowOpen, WIN_ID, true)
  end

  if not ac.accessAppWindow then return end

  local sim = ac.getSim()
  local screen = sim.windowSize
  if not screen or screen.x <= 0 or screen.y <= 0 then return end

  -- 2. переразместить только при смене разрешения (или первый раз),
  -- чтобы не мешать, если захочешь потом подвинуть окно вручную
  local key = string.format('%g:%g', screen.x, screen.y)
  if placed and key == lastScreen then return end

  local info = findWindow()
  if not info then return end

  local ok, window = pcall(ac.accessAppWindow, info.name)
  if not ok or not window or not window:valid() then return end

  local factor = math.min(1, (screen.x - MARGIN_SIDE) / WIN_W)
  local w, h = WIN_W * factor, WIN_H * factor

  window:resize(vec2(w, h))
  window:move(vec2((screen.x - w) / 2, screen.y - h - MARGIN_BOTTOM))

  placed = true
  lastScreen = key
end

return M