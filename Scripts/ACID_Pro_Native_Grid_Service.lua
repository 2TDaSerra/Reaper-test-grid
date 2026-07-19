-- @description ACID Pro native grid - optional background synchronizer
-- @version 1.0.0
-- @author 2TDaSerra, OpenAI Codex
-- @license MIT
-- @about
--   Keeps REAPER's native project-grid division synchronized when horizontal
--   zoom is changed by something other than the companion mousewheel action.
--   No overlay, bitmap or custom mouse handling is used.
--   Run once to enable and run the same action again to disable.

local MAX_LEVEL = 23
local ACID_TICKS_PER_QUARTER = 768
local CHECK_INTERVAL = 0.05

local LEVELS = {
  [0]  = { span_ticks = 122880, grid_division = 1 },
  [1]  = { span_ticks =  92160, grid_division = 1 },
  [2]  = { span_ticks =  69120, grid_division = 1 / 2 },
  [3]  = { span_ticks =  46080, grid_division = 1 / 4 },
  [4]  = { span_ticks =  34560, grid_division = 1 / 4 },
  [5]  = { span_ticks =  23040, grid_division = 1 / 8 },
  [6]  = { span_ticks =  17280, grid_division = 1 / 8 },
  [7]  = { span_ticks =  11520, grid_division = 1 / 16 },
  [8]  = { span_ticks =   8640, grid_division = 1 / 16 },
  [9]  = { span_ticks =   5760, grid_division = 1 / 32 },
  [10] = { span_ticks =   4320, grid_division = 1 / 32 },
  [11] = { span_ticks =   2880, grid_division = 1 / 64 },
  [12] = { span_ticks =   2160, grid_division = 1 / 64 },
  [13] = { span_ticks =   1440, grid_division = 1 / 128 },
  [14] = { span_ticks =   1080, grid_division = 1 / 128 },
  [15] = { span_ticks =    720, grid_division = 1 / 256 },
  [16] = { span_ticks =    540, grid_division = 1 / 256 },
  [17] = { span_ticks =    360, grid_division = 1 / 512 },
  [18] = { span_ticks =    270, grid_division = 1 / 512 },
  [19] = { span_ticks =    180, grid_division = 1 / 1024 },
  [20] = { span_ticks =    135, grid_division = 1 / 1024 },
  [21] = { span_ticks =     90, grid_division = 1 / 2048 },
  [22] = { span_ticks =   67.5, grid_division = 1 / 2048 },
  [23] = { span_ticks =     45, grid_division = 1 / 4096 },
}

local EXT_SECTION = "ACIDProNativeGrid"
local EXT_KEY_PREFIX = "level:"
local CMD_TOGGLE_GRID_LINES = 40145

local section_id, command_id = select(3, reaper.get_action_context())
if reaper.set_action_options then
  reaper.set_action_options(5)
elseif command_id and command_id > 0 then
  reaper.SetToggleCommandState(section_id, command_id, 1)
  reaper.RefreshToolbar2(section_id, command_id)
end

local spans = {}
for level = 0, MAX_LEVEL do
  spans[level] = LEVELS[level].span_ticks / ACID_TICKS_PER_QUARTER
end

local last_check = 0
local last_visible_qn
local last_level

local function project_state_key()
  local project = reaper.EnumProjects(-1, "")
  return EXT_KEY_PREFIX .. (project and tostring(project) or "active")
end

local function infer_level(visible_qn)
  local closest_level = 0
  local closest_distance = math.huge
  for level = 0, MAX_LEVEL do
    local distance = math.abs(math.log(visible_qn / spans[level]))
    if distance < closest_distance then
      closest_level = level
      closest_distance = distance
    end
  end
  return closest_level
end

local function synchronize()
  local start_time, end_time = reaper.GetSet_ArrangeView2(
    0, false, 0, 0
  )
  if not start_time or not end_time or end_time <= start_time then return end

  local visible_qn = reaper.TimeMap2_timeToQN(0, end_time) -
    reaper.TimeMap2_timeToQN(0, start_time)
  if visible_qn <= 0 then return end

  if last_visible_qn and
      math.abs(visible_qn - last_visible_qn) <= 1e-10 then
    return
  end
  last_visible_qn = visible_qn

  local level = infer_level(visible_qn)
  local _, current_grid = reaper.GetSetProjectGrid(0, false)
  local target_grid = LEVELS[level].grid_division
  local grid_changed = not current_grid or
    math.abs(current_grid - target_grid) > 1e-12

  if level ~= last_level or grid_changed then
    if reaper.GetToggleCommandState(CMD_TOGGLE_GRID_LINES) ~= 1 then
      reaper.Main_OnCommand(CMD_TOGGLE_GRID_LINES, 0)
    end
    reaper.GetSetProjectGrid(0, true, target_grid, 0, 0)
    reaper.SetExtState(
      EXT_SECTION, project_state_key(), tostring(level), false
    )
    reaper.UpdateTimeline()
    reaper.UpdateArrange()
    last_level = level
  end
end

local function cleanup()
  if not reaper.set_action_options and command_id and command_id > 0 then
    reaper.SetToggleCommandState(section_id, command_id, 0)
    reaper.RefreshToolbar2(section_id, command_id)
  end
end

reaper.atexit(cleanup)

local function loop()
  local now = reaper.time_precise()
  if now - last_check >= CHECK_INTERVAL then
    last_check = now
    synchronize()
  end
  reaper.defer(loop)
end

loop()
