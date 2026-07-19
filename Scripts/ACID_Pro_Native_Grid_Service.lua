-- @description ACID Pro native grid - toggle full ACID mode (toolbar)
-- @version 1.2.0
-- @author 2TDaSerra, OpenAI Codex
-- @license MIT
-- @about
--   Recommended no-setup mode. Add this action to a toolbar and click once
--   to enable or disable the complete ACID-calibrated grid and zoom mode.
--
--   When enabled, the script captures the mouse wheel directly over REAPER's
--   arrange view. No Mousewheel shortcut or Mouse Modifier is required.
--   The wheel follows the 24 measured ACID Pro zoom steps and hard limits,
--   while the project uses REAPER's real native grid, snapping and ruler.
--   No overlay, bitmap or custom-drawn grid is used.
--
--   Requires js_ReaScriptAPI (available through ReaPack).

local MAX_LEVEL = 23
local ACID_TICKS_PER_QUARTER = 768
local RESYNC_TOLERANCE = 0.12
local EPSILON = 1e-9
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
local CMD_RULER_MBT_AND_SECONDS = 40366
local SERVICE_EXT_SECTION = "ACIDProNativeGridService"
local SERVICE_RUNNING_KEY = "running"
local SERVICE_HEARTBEAT_KEY = "heartbeat"
local HEARTBEAT_INTERVAL = 0.5
local STALE_INSTANCE_TIME = 1.5

local section_id, command_id = select(3, reaper.get_action_context())
local now = reaper.time_precise()

local required_js_functions = {
  "JS_Window_FindChildByID",
  "JS_Window_IsWindow",
  "JS_WindowMessage_Intercept",
  "JS_WindowMessage_Peek",
  "JS_WindowMessage_Release",
}

for _, function_name in ipairs(required_js_functions) do
  if type(reaper[function_name]) ~= "function" then
    reaper.MB(
      "Este modo precisa da extensão js_ReaScriptAPI.\n\n" ..
      "Instale ou atualize 'js_ReaScriptAPI: API functions for ReaScripts' " ..
      "pelo ReaPack e reinicie o REAPER.",
      "ACID Pro Native Grid", 0
    )
    return
  end
end

local previous_token = reaper.GetExtState(
  SERVICE_EXT_SECTION, SERVICE_RUNNING_KEY
)
local previous_heartbeat = tonumber(reaper.GetExtState(
  SERVICE_EXT_SECTION, SERVICE_HEARTBEAT_KEY
))

-- A second launch is the OFF command for the already-running instance.
if previous_token ~= "" and previous_heartbeat and
    now - previous_heartbeat < STALE_INSTANCE_TIME then
  reaper.SetExtState(
    SERVICE_EXT_SECTION, SERVICE_RUNNING_KEY,
    "stop:" .. previous_token, false
  )
  if command_id and command_id > 0 then
    reaper.SetToggleCommandState(section_id, command_id, 0)
    reaper.RefreshToolbar2(section_id, command_id)
  end
  return
end

local token = string.format("%.9f", now)
reaper.SetExtState(
  SERVICE_EXT_SECTION, SERVICE_RUNNING_KEY, token, false
)
reaper.SetExtState(
  SERVICE_EXT_SECTION, SERVICE_HEARTBEAT_KEY, tostring(now), false
)

if command_id and command_id > 0 then
  reaper.SetToggleCommandState(section_id, command_id, 1)
  reaper.RefreshToolbar2(section_id, command_id)
end

local spans = {}
for level = 0, MAX_LEVEL do
  spans[level] = LEVELS[level].span_ticks / ACID_TICKS_PER_QUARTER
end

local last_check = 0
local last_heartbeat = now
local last_visible_qn
local last_level
local trackview_hwnd
local wheel_intercepted = false
local last_wheel_time = now

local function project_state_key()
  local project = reaper.EnumProjects(-1, "")
  return EXT_KEY_PREFIX .. (project and tostring(project) or "active")
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
  last_level = level
  last_visible_qn = spans[level]
  reaper.UpdateTimeline()
  reaper.UpdateArrange()
end

local function step_zoom(direction)
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

  -- Reapplying a boundary level repairs a view changed by another action,
  -- while repeated wheel input stays visually fixed at the ACID limit.
  apply_level(target_level, start_time, start_qn, end_qn)
end

local function signed_word(value)
  value = tonumber(value) or 0
  if value > 32767 then value = value - 65536 end
  return value
end

local function process_mousewheel()
  if not wheel_intercepted or not trackview_hwnd then return end
  if not reaper.JS_Window_IsWindow(trackview_hwnd) then return end

  local received, _, message_time, _, delta =
    reaper.JS_WindowMessage_Peek(trackview_hwnd, "WM_MOUSEWHEEL")
  message_time = tonumber(message_time) or 0
  if not received or message_time <= last_wheel_time then return end
  last_wheel_time = message_time

  delta = signed_word(delta)
  if delta == 0 then return end

  -- Normal wheels report 120 per notch. High-resolution wheels can report
  -- smaller values, which still count as one deliberate ACID zoom step.
  local step_count = math.max(1, math.floor(math.abs(delta) / 120 + 0.5))
  local direction = delta > 0 and 1 or -1
  for _ = 1, step_count do step_zoom(direction) end
end

local function synchronize()
  local start_time, end_time = reaper.GetSet_ArrangeView2(
    0, false, 0, 0
  )
  if not start_time or not end_time or end_time <= start_time then return end

  local visible_qn = reaper.TimeMap2_timeToQN(0, end_time) -
    reaper.TimeMap2_timeToQN(0, start_time)
  if visible_qn <= 0 then return end

  local level = infer_level(visible_qn)
  local _, current_grid = reaper.GetSetProjectGrid(0, false)
  local target_grid = LEVELS[level].grid_division
  local grid_changed = not current_grid or
    math.abs(current_grid - target_grid) > 1e-12
  local view_changed = not last_visible_qn or
    math.abs(visible_qn - last_visible_qn) > 1e-10
  last_visible_qn = visible_qn

  if view_changed or level ~= last_level or grid_changed then
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
  if wheel_intercepted and trackview_hwnd and
      reaper.JS_Window_IsWindow(trackview_hwnd) then
    reaper.JS_WindowMessage_Release(trackview_hwnd, "WM_MOUSEWHEEL")
  end
  wheel_intercepted = false

  local state = reaper.GetExtState(
    SERVICE_EXT_SECTION, SERVICE_RUNNING_KEY
  )
  if state == token or state == "stop:" .. token then
    reaper.DeleteExtState(
      SERVICE_EXT_SECTION, SERVICE_RUNNING_KEY, false
    )
    reaper.DeleteExtState(
      SERVICE_EXT_SECTION, SERVICE_HEARTBEAT_KEY, false
    )
  end

  if command_id and command_id > 0 then
    reaper.SetToggleCommandState(section_id, command_id, 0)
    reaper.RefreshToolbar2(section_id, command_id)
  end
end

reaper.atexit(cleanup)

trackview_hwnd = reaper.JS_Window_FindChildByID(
  reaper.GetMainHwnd(), 1000
)
if not trackview_hwnd or not reaper.JS_Window_IsWindow(trackview_hwnd) then
  reaper.MB(
    "Não foi possível localizar a área de arranjo do REAPER.",
    "ACID Pro Native Grid", 0
  )
  return
end

local intercept_result = reaper.JS_WindowMessage_Intercept(
  trackview_hwnd, "WM_MOUSEWHEEL", false
)
if intercept_result ~= true and intercept_result ~= 1 then
  reaper.MB(
    "A roda do mouse já está sendo interceptada por outro script.\n\n" ..
    "Desative o outro script e ligue novamente o modo ACID.",
    "ACID Pro Native Grid", 0
  )
  return
end
wheel_intercepted = true
do
  local _, _, initial_message_time = reaper.JS_WindowMessage_Peek(
    trackview_hwnd, "WM_MOUSEWHEEL"
  )
  last_wheel_time = tonumber(initial_message_time) or 0
end

local function loop()
  local now = reaper.time_precise()
  if reaper.GetExtState(
      SERVICE_EXT_SECTION, SERVICE_RUNNING_KEY
    ) ~= token then
    return
  end

  if now - last_heartbeat >= HEARTBEAT_INTERVAL then
    reaper.SetExtState(
      SERVICE_EXT_SECTION, SERVICE_HEARTBEAT_KEY,
      tostring(now), false
    )
    last_heartbeat = now
  end

  process_mousewheel()
  if now - last_check >= CHECK_INTERVAL then
    last_check = now
    synchronize()
  end
  reaper.defer(loop)
end

loop()
