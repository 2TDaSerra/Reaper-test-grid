-- @description ACID Pro hybrid grid - toggle full ACID mode (ReaPack v1.3.1)
-- @version 1.3.1
-- @author 2TDaSerra, OpenAI Codex
-- @license MIT
-- @about
--   Recommended no-setup mode. Add this action to a toolbar and click once
--   to enable or disable the complete ACID-calibrated grid and zoom mode.
--
--   When enabled, the script captures the mouse wheel directly over REAPER's
--   arrange view. No Mousewheel shortcut or Mouse Modifier is required.
--   The wheel follows the 24 measured ACID Pro zoom steps and hard limits.
--   Levels 0-20 use REAPER's real native grid. Since REAPER's native arrange
--   grid stops at 1/1024, levels 21-23 draw a uniform set of 1-pixel ACID
--   subdivisions directly into the arrange view with tiny 1x1 bitmaps.
--   No ReaImGui window, floating overlay or replacement ruler is used.
--
--   Requires js_ReaScriptAPI and SWS (available through ReaPack).

local MAX_LEVEL = 23
local ACID_TICKS_PER_QUARTER = 768
local RESYNC_TOLERANCE = 0.12
local EPSILON = 1e-9
local CHECK_INTERVAL = 0.05
local HYBRID_FIRST_LEVEL = 21
local NATIVE_GRID_LIMIT = 1 / 1024
local SIMPLE_CLICK_DISTANCE = 4

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
local CMD_TOGGLE_SNAP = 1157
local CMD_RULER_MBT_AND_SECONDS = 40366
local SWS_SNAP_FOLLOWS_GRID = "_BR_OPTIONS_SNAP_FOLLOW_GRID_VIS"
local ACID_MIN_GRID_SPACING_PX = 1
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
  "JS_Window_GetClientSize",
  "JS_Window_Update",
  "JS_LICE_CreateBitmap",
  "JS_LICE_Clear",
  "JS_LICE_DestroyBitmap",
  "JS_Composite",
  "JS_Composite_Unlink",
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

local required_sws_functions = {
  "SNM_GetIntConfigVar",
  "SNM_SetIntConfigVar",
}

for _, function_name in ipairs(required_sws_functions) do
  if type(reaper[function_name]) ~= "function" then
    reaper.MB(
      "Este modo precisa da extensão SWS para mostrar e usar todas " ..
      "as subdivisões pequenas do ACID.\n\n" ..
      "Instale ou atualize SWS e reinicie o REAPER.",
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
local click_down_intercepted = false
local click_up_intercepted = false
local last_wheel_time = now
local last_click_down_time = now
local last_click_up_time = now
local click_down_x
local click_down_y
local click_down_level
local click_down_keys
local original_grid_spacing
local changed_grid_spacing = false
local snap_follows_grid_command = 0
local changed_snap_follows_grid = false
local hybrid_bitmaps = {}
local hybrid_bitmap_color
local hybrid_signature
local pending_cursor_time
local pending_cursor_cycles = 0

local function enable_exact_native_grid_options()
  original_grid_spacing = reaper.SNM_GetIntConfigVar(
    "projgridmin", ACID_MIN_GRID_SPACING_PX
  )
  if original_grid_spacing ~= ACID_MIN_GRID_SPACING_PX then
    reaper.SNM_SetIntConfigVar(
      "projgridmin", ACID_MIN_GRID_SPACING_PX
    )
    changed_grid_spacing = true
  end

  local applied_grid_spacing = reaper.SNM_GetIntConfigVar(
    "projgridmin", -1
  )
  if applied_grid_spacing ~= ACID_MIN_GRID_SPACING_PX then
    reaper.MB(
      "Não foi possível aplicar o espaçamento nativo de 1 px.\n\n" ..
      "Valor retornado pelo REAPER/SWS: " ..
      tostring(applied_grid_spacing) .. "\n\n" ..
      "Atualize SWS e reinicie o REAPER.",
      "ACID Pro Hybrid Grid 1.3.1", 0
    )
    return false
  end

  snap_follows_grid_command = reaper.NamedCommandLookup(
    SWS_SNAP_FOLLOWS_GRID
  )
  if snap_follows_grid_command == 0 then
    reaper.MB(
      "A ação SWS que sincroniza o snap com a grade visível não foi " ..
      "encontrada.\n\nAtualize SWS e ligue novamente o modo ACID.",
      "ACID Pro Native Grid", 0
    )
    return false
  end

  if reaper.GetToggleCommandState(snap_follows_grid_command) ~= 1 then
    reaper.Main_OnCommand(snap_follows_grid_command, 0)
    changed_snap_follows_grid = true
  end
  return true
end

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

local function native_grid_for_level(level)
  if level >= HYBRID_FIRST_LEVEL then return NATIVE_GRID_LIMIT end
  return LEVELS[level].grid_division
end

local function lice_color_from_native(native_color)
  native_color = tonumber(native_color) or 0x505050
  if native_color < 0 then native_color = 0x505050 end
  local red = native_color & 0xFF
  local green = (native_color >> 8) & 0xFF
  local blue = (native_color >> 16) & 0xFF
  return 0xFF000000 | (red << 16) | (green << 8) | blue
end

local function destroy_hybrid_bitmaps()
  if #hybrid_bitmaps == 0 then
    hybrid_bitmap_color = nil
    hybrid_signature = nil
    return
  end
  for index = #hybrid_bitmaps, 1, -1 do
    local bitmap = hybrid_bitmaps[index]
    if trackview_hwnd and reaper.JS_Window_IsWindow(trackview_hwnd) then
      reaper.JS_Composite_Unlink(trackview_hwnd, bitmap, false)
    end
    reaper.JS_LICE_DestroyBitmap(bitmap)
    hybrid_bitmaps[index] = nil
  end
  hybrid_bitmap_color = nil
  hybrid_signature = nil
  if trackview_hwnd and reaper.JS_Window_IsWindow(trackview_hwnd) then
    reaper.JS_Window_Update(trackview_hwnd)
  end
end

local function update_hybrid_grid(
    level, start_time, end_time, start_qn, end_qn)
  if level < HYBRID_FIRST_LEVEL then
    destroy_hybrid_bitmaps()
    return
  end
  if not trackview_hwnd or
      not reaper.JS_Window_IsWindow(trackview_hwnd) then
    return
  end

  local ok, width, height = reaper.JS_Window_GetClientSize(trackview_hwnd)
  width = math.floor(tonumber(width) or 0)
  height = math.floor(tonumber(height) or 0)
  if not ok or width < 2 or height < 2 then return end

  local theme_color = reaper.GetThemeColor("col_gridlines3", 0)
  if not theme_color or theme_color < 0 then
    theme_color = reaper.GetThemeColor("col_gridlines2", 0)
  end
  local line_color = lice_color_from_native(theme_color)
  local signature = string.format(
    "%d|%.12f|%.12f|%d|%d|%s",
    level, start_time, end_time, width, height, tostring(line_color)
  )
  if hybrid_signature == signature then return end

  local desired_qn = LEVELS[level].grid_division * 4
  local first_index = math.ceil((start_qn - EPSILON) / desired_qn)
  local last_index = math.floor((end_qn + EPSILON) / desired_qn)
  local duration = end_time - start_time
  local positions = {}

  for index = first_index, last_index do
    local qn = index * desired_qn
    local line_time = reaper.TimeMap2_QNToTime(0, qn)
    local x = math.floor(
      ((line_time - start_time) / duration) * width + 0.5
    )
    if x >= 0 and x < width then
      positions[#positions + 1] = x
    end
  end

  for index, x in ipairs(positions) do
    local bitmap = hybrid_bitmaps[index]
    local created = false
    if not bitmap then
      bitmap = reaper.JS_LICE_CreateBitmap(true, 1, 1)
      if not bitmap then break end
      hybrid_bitmaps[index] = bitmap
      created = true
    end
    if created or hybrid_bitmap_color ~= line_color then
      reaper.JS_LICE_Clear(bitmap, line_color)
    end
    reaper.JS_Composite(
      trackview_hwnd, x, 0, 1, height,
      bitmap, 0, 0, 1, 1, false
    )
  end

  for index = #hybrid_bitmaps, #positions + 1, -1 do
    local bitmap = hybrid_bitmaps[index]
    reaper.JS_Composite_Unlink(trackview_hwnd, bitmap, false)
    reaper.JS_LICE_DestroyBitmap(bitmap)
    hybrid_bitmaps[index] = nil
  end

  hybrid_bitmap_color = line_color
  hybrid_signature = signature
  reaper.JS_Window_Update(trackview_hwnd)
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
    0, true, native_grid_for_level(level), 0, 0
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

local function process_fine_grid_click()
  if not trackview_hwnd or
      not reaper.JS_Window_IsWindow(trackview_hwnd) then
    return
  end

  if click_down_intercepted then
    local received, _, message_time, keys, _, x, y =
      reaper.JS_WindowMessage_Peek(
        trackview_hwnd, "WM_LBUTTONDOWN"
      )
    message_time = tonumber(message_time) or 0
    if received and message_time > last_click_down_time then
      last_click_down_time = message_time
      click_down_x = signed_word(x)
      click_down_y = signed_word(y)
      click_down_level = last_level
      click_down_keys = tonumber(keys) or 0
    end
  end

  if not click_up_intercepted then return end
  local received, _, message_time, keys, _, x, y =
    reaper.JS_WindowMessage_Peek(trackview_hwnd, "WM_LBUTTONUP")
  message_time = tonumber(message_time) or 0
  if not received or message_time <= last_click_up_time then return end
  last_click_up_time = message_time

  local level = last_level or click_down_level
  local down_x = click_down_x
  local down_y = click_down_y
  x = signed_word(x)
  y = signed_word(y)
  local modifier_keys = (tonumber(keys) or 0) | (click_down_keys or 0)
  click_down_x = nil
  click_down_y = nil
  click_down_level = nil
  click_down_keys = nil

  if not level or level < HYBRID_FIRST_LEVEL or
      not down_x or not down_y then
    return
  end
  local moved = math.abs(x - down_x) > SIMPLE_CLICK_DISTANCE or
    math.abs(y - down_y) > SIMPLE_CLICK_DISTANCE

  -- Leave drags and modified clicks entirely to REAPER. This preserves time
  -- selections, loop-point drags and the user's mouse-modifier setup.
  if moved or (modifier_keys & 0x000C) ~= 0 then return end
  if reaper.GetToggleCommandState(CMD_TOGGLE_SNAP) ~= 1 then return end

  local ok, width = reaper.JS_Window_GetClientSize(trackview_hwnd)
  width = tonumber(width) or 0
  if not ok or width <= 1 then return end
  local start_time, end_time = reaper.GetSet_ArrangeView2(
    0, false, 0, 0
  )
  if not start_time or not end_time or end_time <= start_time then return end
  local ratio = math.max(0, math.min(1, x / width))
  local raw_time = start_time + (end_time - start_time) * ratio

  local grid_qn = LEVELS[level].grid_division * 4
  local raw_qn = reaper.TimeMap2_timeToQN(0, raw_time)
  local snapped_qn = math.floor(raw_qn / grid_qn + 0.5) * grid_qn
  if snapped_qn < 0 then snapped_qn = 0 end
  local target_time = reaper.TimeMap2_QNToTime(0, snapped_qn)
  reaper.SetEditCurPos(target_time, true, false)
  pending_cursor_time = target_time
  pending_cursor_cycles = 1
end

local function apply_pending_cursor()
  if pending_cursor_cycles <= 0 or not pending_cursor_time then return end
  reaper.SetEditCurPos(pending_cursor_time, true, false)
  pending_cursor_cycles = pending_cursor_cycles - 1
  if pending_cursor_cycles <= 0 then pending_cursor_time = nil end
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

  local start_qn = reaper.TimeMap2_timeToQN(0, start_time)
  local end_qn = reaper.TimeMap2_timeToQN(0, end_time)
  local visible_qn = end_qn - start_qn
  if visible_qn <= 0 then return end

  local level = infer_level(visible_qn)
  local _, current_grid = reaper.GetSetProjectGrid(0, false)
  local target_grid = native_grid_for_level(level)
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

  update_hybrid_grid(
    level, start_time, end_time, start_qn, end_qn
  )
end

local function cleanup()
  destroy_hybrid_bitmaps()

  if wheel_intercepted and trackview_hwnd and
      reaper.JS_Window_IsWindow(trackview_hwnd) then
    reaper.JS_WindowMessage_Release(trackview_hwnd, "WM_MOUSEWHEEL")
  end
  wheel_intercepted = false

  if click_down_intercepted and trackview_hwnd and
      reaper.JS_Window_IsWindow(trackview_hwnd) then
    reaper.JS_WindowMessage_Release(trackview_hwnd, "WM_LBUTTONDOWN")
  end
  click_down_intercepted = false

  if click_up_intercepted and trackview_hwnd and
      reaper.JS_Window_IsWindow(trackview_hwnd) then
    reaper.JS_WindowMessage_Release(trackview_hwnd, "WM_LBUTTONUP")
  end
  click_up_intercepted = false

  if changed_snap_follows_grid and snap_follows_grid_command ~= 0 and
      reaper.GetToggleCommandState(snap_follows_grid_command) == 1 then
    reaper.Main_OnCommand(snap_follows_grid_command, 0)
  end
  changed_snap_follows_grid = false

  if changed_grid_spacing and original_grid_spacing then
    local current_spacing = reaper.SNM_GetIntConfigVar(
      "projgridmin", ACID_MIN_GRID_SPACING_PX
    )
    if current_spacing == ACID_MIN_GRID_SPACING_PX then
      reaper.SNM_SetIntConfigVar(
        "projgridmin", original_grid_spacing
      )
    end
  end
  changed_grid_spacing = false

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

if not enable_exact_native_grid_options() then return end

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


local click_down_result = reaper.JS_WindowMessage_Intercept(
  trackview_hwnd, "WM_LBUTTONDOWN", true
)
if click_down_result ~= true and click_down_result ~= 1 then
  reaper.MB(
    "O clique do mouse já está sendo monitorado por outro script.\n\n" ..
    "Desative o outro script e ligue novamente o modo ACID.",
    "ACID Pro Hybrid Grid", 0
  )
  return
end
click_down_intercepted = true

local click_up_result = reaper.JS_WindowMessage_Intercept(
  trackview_hwnd, "WM_LBUTTONUP", true
)
if click_up_result ~= true and click_up_result ~= 1 then
  reaper.MB(
    "Não foi possível monitorar o clique completo do mouse.\n\n" ..
    "Desative outros scripts de mouse e ligue novamente o modo ACID.",
    "ACID Pro Hybrid Grid", 0
  )
  return
end
click_up_intercepted = true

do
  local _, _, down_time = reaper.JS_WindowMessage_Peek(
    trackview_hwnd, "WM_LBUTTONDOWN"
  )
  local _, _, up_time = reaper.JS_WindowMessage_Peek(
    trackview_hwnd, "WM_LBUTTONUP"
  )
  last_click_down_time = tonumber(down_time) or 0
  last_click_up_time = tonumber(up_time) or 0
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

  apply_pending_cursor()
  process_mousewheel()
  process_fine_grid_click()
  if now - last_check >= CHECK_INTERVAL then
    last_check = now
    synchronize()
  end
  reaper.defer(loop)
end

loop()
