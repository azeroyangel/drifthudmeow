local T = require('telemetry')
local V = {}

local white = rgbm(0.95, 0.9, 1, 1)
local muted = rgbm(0.6, 0.4, 0.8, 1)
local accent = rgbm(0.8, 0.2, 1, 1)

local colors = {
  rgbm(0.75, 0.20, 1.00, 1),
  rgbm(1.00, 0.25, 0.85, 1),
  rgbm(0.45, 0.35, 1.00, 1),
  rgbm(0.85, 0.60, 1.00, 1),
  rgbm(1.00, 0.50, 0.95, 1),
  rgbm(0.55, 0.65, 1.00, 1),
}
local colorsDark = {}
for i, c in ipairs(colors) do
  colorsDark[i] = rgbm(c.r * 0.35, c.g * 0.35, c.b * 0.35, 1)
end
local labels = {'thr', 'brk', 'clu', 'h.b', 'ffb', 'boost'}

local GRID_SPACING_X = 20
local GRID_SPACING_Y = 15
local GRID_SPEED_X = 12
local GRID_SPEED_Y = 8
local GRID_ALPHA = 0.08

local smoothSpeed = 0
local gridPhaseX, gridPhaseY = 0, 0
local lastClock = os.clock()

local BG_FILE = 'meowwww.png'
local BG_ALPHA = 0.6
local bgPath = nil
local function getBackground()
  if bgPath then return bgPath end
  local ok, folder = pcall(ac.getFolder, ac.FolderID.ScriptOrigin)
  bgPath = (ok and folder and folder ~= '') and (folder .. '/' .. BG_FILE) or BG_FILE
  return bgPath
end

local function fmt(v, pattern)
  v = T.number(v, nil)
  return v and string.format(pattern or '%.0f', v) or '--'
end

local function lerpRGB(a, b, t)
  return {a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t}
end

local RPM_PURPLE = {0.8, 0.2, 1}
local RPM_PINK = {1, 0.2, 0.6}
local RPM_RED = {1, 0.15, 0.15}

local modules = {
  {id = 'driving', width = 230},
  {id = 'steering', width = 90},
  {id = 'inputs', width = 260},
  {id = 'drift', width = 240},
}
local total = 0
for _, m in ipairs(modules) do total = total + m.width + 8 end
total = math.max(200, total - 8)

function V.draw(car, state, prefs, replay)
  local origin = ui.getCursor()
  local available = ui.availableSpace()
  local scale = math.max(.01, math.min(available.x / total, available.y / 92))
  local offset = 0

  local function point(x, y) return vec2(origin.x + (offset + x) * scale, origin.y + y * scale) end
  local function rect(x, y, w, h, c) ui.drawRectFilled(point(x, y), point(x + w, y + h), c, 0) end
  local function text(s, x, y, size, c) ui.dwriteDrawText(s, size * scale, point(x, y), c or white) end
  local function centeredText(s, center, y, size, c)
    local measured = ui.measureDWriteText(s, size * scale)
    text(s, center - measured.x / (2 * scale), y, size, c)
  end
  local function line(x, y, xx, yy, c, width) ui.drawLine(point(x, y), point(xx, yy), c, (width or 1.5) * scale) end

  if not car then text('waiting for a car', 8, 20, 18); return end

  local bgImg = getBackground()

  local uvX, uvY, uvW, uvH = 0, 0, 1, 1
  local okS, isize = pcall(ui.imageSize, bgImg)
  if okS and isize and isize.x > 0 and isize.y > 0 then
    local hudAspect = total / 92
    local imgAspect = isize.x / isize.y
    if imgAspect < hudAspect then
      uvH = imgAspect / hudAspect
      uvY = (1 - uvH) / 2
    else
      uvW = hudAspect / imgAspect
      uvX = (1 - uvW) / 2
    end
  end

  local clock = os.clock()
  local dt = math.min(clock - lastClock, 0.1)
  lastClock = clock

  local kmh = T.number(car.speedKmh, 0)

  gridPhaseX = gridPhaseX + dt * GRID_SPEED_X
  gridPhaseY = gridPhaseY + dt * GRID_SPEED_Y
  local gridOx = gridPhaseX % GRID_SPACING_X
  local gridOy = gridPhaseY % GRID_SPACING_Y

  smoothSpeed = smoothSpeed + (kmh - smoothSpeed) * math.min(1, dt * 10)

  for _, m in ipairs(modules) do
    local u1 = uvX + (offset / total) * uvW
    local u2 = uvX + ((offset + m.width) / total) * uvW
    ui.drawImage(bgImg, point(0, 0), point(m.width, 92),
      rgbm(1, 1, 1, BG_ALPHA), vec2(u1, uvY), vec2(u2, uvY + uvH))

    local bgColor = rgbm(.08, .02, .12, prefs.backgroundOpacity or .35)
    local isRedline = false

    if m.id == 'driving' then
      local limit = T.number(car.rpmLimiter, 0)
      local rpm = T.number(car.rpm, 0)
      isRedline = limit > 0 and (rpm / limit) > 0.92
      if isRedline then
        local flash = (math.sin(clock * 20) * 0.5 + 0.5)
        bgColor = rgbm(0.5, 0.0, 0.9, 0.2 + flash * 0.4)
      end
    end
    rect(0, 0, m.width, 92, bgColor)

    local gridColor = rgbm(0.6, 0.3, 1, GRID_ALPHA)
    for gx = gridOx - GRID_SPACING_X, m.width + GRID_SPACING_X, GRID_SPACING_X do
      if gx >= 0 and gx <= m.width then line(gx, 0, gx, 92, gridColor) end
    end
    for gy = gridOy - GRID_SPACING_Y, 92 + GRID_SPACING_Y, GRID_SPACING_Y do
      if gy >= 0 and gy <= 92 then line(0, gy, m.width, gy, gridColor) end
    end

    if m.id == 'driving' then
      local rpm, limit = T.number(car.rpm, 0), T.number(car.rpmLimiter, 0)
      local rpmRatio = limit > 0 and T.clamp(rpm / limit, 0, 1) or 0
      local barWidth = 210
      local fillW = barWidth * rpmRatio

      rect(10, 10, barWidth, 4, rgbm(.15, .05, .25, .8))

      if fillW > 0 then
        local c1, c2
        if isRedline then
          c1, c2 = {0.55, 0.0, 1}, {0.9, 0.35, 1}
        else
          c1 = RPM_PURPLE
          if rpmRatio < 0.75 then
            c2 = lerpRGB(RPM_PURPLE, RPM_PINK, rpmRatio / 0.75)
          else
            c2 = lerpRGB(RPM_PINK, RPM_RED, (rpmRatio - 0.75) / 0.25)
          end
        end
        for i = 0, fillW, 2 do
          local t = i / math.max(1, fillW)
          local c = lerpRGB(c1, c2, t)
          rect(10 + i, 10, 2, 4, rgbm(c[1], c[2], c[3], 1))
        end
      end

      local gearText = car.gear == -1 and 'R' or car.gear == 0 and 'N' or fmt(car.gear)
      centeredText(gearText, 35, 22, 48, white)

      local speedVal = fmt(smoothSpeed * (prefs.mph and .621371 or 1))
      local speedColor = isRedline
        and (math.floor(clock * 10) % 2 == 0 and rgbm(1, 0.15, 0.15, 1) or white)
        or white
      local ratio = math.min(1, smoothSpeed / 200)
      local shake = ratio > 0.6 and math.sin(clock * 50) * (ratio - 0.6) * 1.5 or 0
      centeredText(speedVal, 115 + shake, 22, 42, speedColor)
      centeredText(prefs.mph and 'mph' or 'km/h', 115, 70, 10, muted)

      local rpmColor = isRedline and rgbm(1, 0.3, 0.3, 1) or white
      centeredText(fmt(car.rpm), 180, 24, 20, rpmColor)
      centeredText('rpm / ' .. fmt(car.fuel, '%.1f') .. ' l', 180, 52, 10, muted)
      
    elseif m.id == 'steering' then
      local steerDeg = T.number(car.steer, 0)
      local a = math.rad(steerDeg)
      local cx, cy, r = 45, 33, 22

      ui.drawCircle(point(cx, cy), r * scale, muted, 40, 2 * scale)
      line(cx - math.cos(a) * r * 0.85, cy - math.sin(a) * r * 0.85,
           cx + math.cos(a) * r * 0.85, cy + math.sin(a) * r * 0.85, white)

      local bx, by, bw = 10, 68, 70
      rect(bx, by, bw, 1.5, rgbm(.5, .3, 1, .3))

      local mx = bx + bw * (T.clamp(steerDeg, -180, 180) + 180) / 360
      rect(mx - 1, by - 4, 2, 9, white)

      centeredText(fmt(math.abs(steerDeg)) .. '°', 45, 74, 10, white)

    elseif m.id == 'inputs' then
      local values = {car.gas, car.brake, T.clutch(car, prefs.invertClutch), car.handbrake,
        math.abs(T.number(car.ffbFinal, 0)), car.turboBoost}
      for i = 1, 6 do
        local x = 8 + (i - 1) * 40
        local avail = not (i >= 5 and car.physicsAvailable == false)
        local value = T.clamp(values[i], 0, 1)
        centeredText(labels[i], x + 11, 10, 9, muted)
        rect(x + 6, 27, 10, 34, rgbm(.15, .05, .25, .6))
        if avail and value > 0 then
          ui.drawRectFilledMultiColor(point(x + 6, 61 - value * 34), point(x + 16, 61),
            colors[i], colors[i], colorsDark[i], colorsDark[i])
        end
        centeredText(avail and fmt(value * 100) or '--', x + 11, 69, 11, colors[i])
      end

    elseif m.id == 'drift' then
      text(fmt(math.abs(state.angle or 0)) .. '°', 10, 8, 32, white)
      text(replay and 'replay' or state.active and 'drifting' or 'slip angle', 10, 44, 10, muted)

      text(fmt(state.run.seconds, '%.1fs') .. ' / ' .. state.run.transitions .. ' turns', 125, 18, 13)
      text('best ' .. fmt(state.trackBest and state.trackBest.seconds, '%.1fs'), 125, 44, 10, accent)

      local function tw(s, sz) return ui.measureDWriteText(s, sz * scale).x / scale end
      local spaceW = tw('a a', 11) - tw('aa', 11)
      if state.last then
        local x = 10
        text('last', x, 69, 11, muted); x = x + tw('last', 11) + spaceW
        local secStr = fmt(state.last.seconds, '%.1fs')
        text(secStr, x, 69, 11, white); x = x + tw(secStr, 11)
        text('/', x, 69, 11, muted); x = x + tw('/', 11) + spaceW
        local peakStr = fmt(state.last.peak) .. '°'
        text(peakStr, x, 69, 11, white); x = x + tw(peakStr, 11) + spaceW
        text('peak', x, 69, 11, muted)
      else
        text('ready for your next run', 10, 69, 11, muted)
      end
    end

    offset = offset + m.width + 8
  end
  ui.setCursor(origin); ui.dummy(vec2(total * scale, 92 * scale))
end

return V
