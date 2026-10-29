local T = require('telemetry')
local Layout = require('layout')
local View = require('view')
local History = require('history')
local historyStore = ac.storage({json = ''}, 'DriftMeow.history.')
local history = History.new(historyStore.json)
local context, onlyCar = nil, true
local state = T.new()

local prefs = {
  mph = false, invertClutch = true, backgroundOpacity = 0.35,
  driving = true, steering = true, inputs = true, drift = true
}

local car, identity, replayFrame, replayMode

local function reset() state = T.new(); identity, replayFrame, replayMode = nil, nil, nil end
ac.onSessionStart(reset)
ac.onCarJumped(-1, function(index) if car and car.index == index then reset() end end)

function script.update(dt)
  local sim = ac.getSim()
  Layout.update(prefs)
  car = sim.focusedCar >= 0 and ac.getCar(sim.focusedCar) or nil
  if not car or car.isConnected == false then reset(); car = nil; return end
  local id = car.index
  local isReplay = sim.isReplayActive
  if identity ~= id or replayMode ~= isReplay
      or (isReplay and replayFrame and math.abs(sim.replayCurrentFrame - replayFrame) > 5) then
    reset()
  end
  if not identity then
    context = {track = ac.getTrackID(), layout = ac.getTrackLayout() or '', car = ac.getCarID(id)}
    state.trackBest = History.bestFor(history, context)
  end
  identity, replayMode, replayFrame = id, isReplay, sim.replayCurrentFrame
  local previous = state.last
  T.update(state, car, dt, sim.isPaused or sim.isInMainMenu, isReplay, prefs.invertClutch)

  if state.last and state.last ~= previous and not isReplay and id == 0 then
    if History.add(history, context, state.last, os.time()) then
      historyStore.json = History.encode(history)
      state.trackBest = History.bestFor(history, context)
    end
  end
end

function script.windowMain()
  View.draw(car, state, prefs, ui.windowWidth(), ac.getSim().isReplayActive)
end

function script.windowHistory()
  ui.text('Practice history')
  if history.error then ui.textWrapped(history.error); return end
  if not context then ui.text('Load a track to compare runs.'); return end
  ui.text(context.track .. (context.layout ~= '' and ' / ' .. context.layout or ''))
  if ui.checkbox('Only this car', onlyCar) then onlyCar = not onlyCar end
  ui.textWrapped('Best means longest recorded drift time. Conditions and assists can differ. This is a practice log, not a competitive score.')
  ui.separator()
  for _, best in ipairs(history.best) do
    if History.same(best, context, onlyCar) then
      ui.text(string.format('Best / %s / %.1fs / %d transitions / %.0f° peak', best.car, best.seconds, best.transitions, best.peak))
    end
  end
  ui.separator()
  local count = 0
  for _, run in ipairs(history.recent) do
    if History.same(run, context, onlyCar) then
      local best = History.bestFor(history, run)
      ui.text(string.format('%s / %s / %.1fs / %s / %d turns / %.0f°',
        os.date('%d %b %H:%M', run.when), run.car, run.seconds,
        best and string.format('%+.1fs to best', run.seconds - best.seconds) or 'best unavailable', run.transitions, run.peak))
      count = count + 1
      if count >= 30 then break end
    end
  end
  if count == 0 then ui.text('No completed runs recorded here yet.'); end
  ui.textWrapped('Keeps the latest 500 runs and bests for up to 500 track/layout/car combinations. Runs shorter than one second are omitted.')
end