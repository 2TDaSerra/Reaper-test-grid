-- @description ACID Pro native grid - 24-step mousewheel zoom
-- @version 1.0.0
-- @author 2TDaSerra, OpenAI Codex
-- @license MIT
-- @about
--   ACID Pro-calibrated horizontal zoom and adaptive project grid.
--   Uses only REAPER's native arrange view, ruler, grid and snapping.
--   Assign Mousewheel to this action and remove Mousewheel from other
--   horizontal-zoom actions.

local MAX_LEVEL = 23
local ACID_TICKS_PER_QUARTER = 768
local RESYNC_TOLERANCE = 0.12
local EPSILON = 1e-9

-- span_ticks is the complete arrange-view width in ACID ruler ticks.
-- grid_division is in whole notes, the unit used by GetSetProjectGrid.
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
local CMD_RULER_MBT_AND_SECONDS = 40366

local _, _, _, _, _, _, wheel_value = reaper.get_action_context()
local direction = tonumber(wheel_value) or 0
if direction == 0 then return end

local spans = {}
for level = 0, MAX_LEVEL do
  spans[level] = LEVELS[level].span_ticks / ACID_TICKS_PER_QUARTER
end

local function project_state_key()
  local project = reaper.EnumProjects(-1, "")
  return EXT_KEY_PREFIX .. (project and tostring(project) or "active")
end

local function get_view()
  local start_time, end_time = reaper.GetSet_ArrangeView2(
    0, false, 0, 0
  )
  if not start_time or not end_time or end_time <= start_time then
    return nil
  end
  return start_time, end_time,
    reaper.TimeMap2_timeToQN(0, start_time),
    reaper.TimeMap2_timeToQN(0, end_time)
end

local function infer_level(visible_qn)
  if visible_qn >= spans[0] * (1 - RESYNC_TOLERANCE) then return 0 end
  if visible_qn <= spans[MAX_LEVEL] * (1 + RESYNC_TOLERANCE) then
    return MAX_LEVEL
  end

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

local function read_level(visible_qn)
  local stored = tonumber(reaper.GetExtState(
    EXT_SECTION, project_state_key()
  ))
  if not stored then return infer_level(visible_qn) end

  stored = math.max(0, math.min(MAX_LEVEL, math.floor(stored + 0.5)))
  local error_ratio = math.abs(visible_qn - spans[stored]) / spans[stored]
  if error_ratio > RESYNC_TOLERANCE then
    return infer_level(visible_qn)
  end
  return stored
end

local function set_exact_span(start_time, start_qn, end_qn, span_qn)
  local center_qn = (start_qn + end_qn) * 0.5
  local new_start_qn
  local new_end_qn

  if start_time <= 0.001 or start_qn <= EPSILON then
    new_start_qn = 0
    new_end_qn = span_qn
  else
    new_start_qn = center_qn - span_qn * 0.5
    new_end_qn = center_qn + span_qn * 0.5
    if new_start_qn < 0 then
      new_start_qn = 0
      new_end_qn = span_qn
    end
  end

  reaper.GetSet_ArrangeView2(
    0, true, 0, 0,
    reaper.TimeMap2_QNToTime(0, new_start_qn),
    reaper.TimeMap2_QNToTime(0, new_end_qn)
  )
end

local function apply_native_grid(level)
  if reaper.GetToggleCommandState(CMD_TOGGLE_GRID_LINES) ~= 1 then
    reaper.Main_OnCommand(CMD_TOGGLE_GRID_LINES, 0)
  end
  reaper.GetSetProjectGrid(
    0, true, LEVELS[level].grid_division, 0, 0
  )
end

local function apply_level(level, start_time, start_qn, end_qn)
  set_exact_span(start_time, start_qn, end_qn, spans[level])
  apply_native_grid(level)

  if reaper.GetToggleCommandState(CMD_RULER_MBT_AND_SECONDS) ~= 1 then
    reaper.Main_OnCommand(CMD_RULER_MBT_AND_SECONDS, 0)
  end

  reaper.SetExtState(
    EXT_SECTION, project_state_key(), tostring(level), false
  )
  reaper.UpdateTimeline()
  reaper.UpdateArrange()
end

local start_time, _, start_qn, end_qn = get_view()
if not start_time then return end

local visible_qn = end_qn - start_qn
local current_level = read_level(visible_qn)
local target_level

if direction > 0 then
  target_level = math.min(current_level + 1, MAX_LEVEL)
else
  target_level = math.max(current_level - 1, 0)
end

-- Reapplying the boundary level repairs any view changed by another action,
-- while repeated wheel input remains visually fixed at the ACID limit.
apply_level(target_level, start_time, start_qn, end_qn)
