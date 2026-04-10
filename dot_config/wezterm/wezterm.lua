-- boilerplate setup
local wezterm = require("wezterm")
local action = wezterm.action
local config = wezterm.config_builder()

--- Get the current operating system
--- @return "windows"| "linux" | "darwin"
local function get_os()
	local triple = string.lower(wezterm.target_triple)
	if string.find(triple, "windows") then
		return "windows"
	elseif string.find(triple, "darwin") then
		return "darwin"
	else
		return "linux"
	end
end

--- Helper to perform a deep merge on two tables
--- @param into table The table that the data will be merged into
--- @param from table The table that contains overriding data
--- @return table
local function merge(into, from)
	for k, v in pairs(from) do
		if type(v) == "table" and type(into[k]) == "table" then
			merge(into[k], v)
		else
			into[k] = v
		end
	end
	return into
end

local host_os = get_os()

-- colors and appearance
config.color_scheme = "GruvboxDarkHard"
config.colors = wezterm.color.get_builtin_schemes()[config.color_scheme]
config.colors.background = "#2c2b2c"
config.font_size = 14

-- window
config.status_update_interval = 250
config.window_decorations = "RESIZE"
config.window_close_confirmation = "NeverPrompt"
config.window_background_opacity = 0.98
-- config.kde_window_background_blur = true
config.win32_system_backdrop = "Acrylic"
config.macos_window_background_blur = 15

-- performance
config.front_end = "WebGpu"
config.max_fps = 144
config.animation_fps = 60
config.cursor_blink_rate = 250

-- tabs
config.enable_tab_bar = true
config.show_tab_index_in_tab_bar = true
config.colors.tab_bar = {
	background = "rgba(44, 43, 44, 0.98)",
	new_tab = { fg_color = config.colors.background, bg_color = config.colors.brights[6] },
	new_tab_hover = { fg_color = config.colors.background, bg_color = config.colors.foreground },
}
local bar = wezterm.plugin.require("https://github.com/adriankarlen/bar.wezterm")
bar.apply_to_config(config, {
	modules = {
		workspace = {
			enabled = false,
		},
	},
})
-- keys
config.keys = {
	{ key = "v", mods = "CTRL", action = action.PasteFrom("Clipboard") },
	{ key = "v", mods = "CTRL", action = action.PasteFrom("PrimarySelection") },
}

-- OS-Specific settings
if host_os == "linux" then
	config.window_decorations = "NONE" -- use system decorations
elseif host_os == "darwin" then
	config.window_decorations = "TITLE|RESIZE"
	config.window_background_opacity = 0.90
elseif host_os == "windows" then
	config.default_prog = { "pwsh", "-NoLogo" }
end

-- Dynamic directory overrides
local dd = require("dynamic-overrides")
local function update_dynamic_overrides(window, pane)
	if not window or not pane then
		return
	end

	local cwd_url = pane:get_current_working_dir()
	if not cwd_url then
		wezterm.log_warn("[update_dynamic_overrides] unable to find cwd!")
		return
	end
	local cwd = cwd_url.file_path
	wezterm.log_info("[update_dynamic_overrides]: cwd='" .. cwd .. "'")

	-- start by assuming we want to use the default colors
	local overrides = window:get_config_overrides() or {}
	merge(overrides, config)

	-- Check if in a colored project directory, and update the colors to match
	local dynamic_dirs = dd.get_dynamic_dirs(config)
	wezterm.log_info("[update_dynamic_overrides]: dirs=" .. wezterm.to_string(dynamic_dirs))
	for _, dynamic_dir in ipairs(dynamic_dirs) do
		local prefix_pattern = dynamic_dir.pattern
		local prefix = cwd:match(prefix_pattern)
		wezterm.log_info(
			"[update_dynamic_overrides]: pattern='" .. prefix_pattern .. "'prefix='" .. (prefix or "nil") .. "'"
		)
		if not prefix then
			goto next_dynamic_dir -- continue
		end

		local offset = 1 + prefix:len()
		for _, sub_dir in ipairs(dynamic_dir.sub_dirs) do
			wezterm.log_info(
				"[update_dynamic_overrides]: sub_pat='" .. sub_dir.pattern .. "' in '" .. cwd:sub(offset) .. "'"
			)
			if not cwd:find(sub_dir.pattern, offset) then
				goto next_sub_dir -- continue
			end

			merge(overrides, sub_dir.overrides)
			wezterm.log_info("[update_dynamic_overrides]: " .. wezterm.to_string(sub_dir.overrides))
			goto set_overrides -- break
			::next_sub_dir::
		end
		::next_dynamic_dir::
	end
	::set_overrides::
	window:set_config_overrides(overrides)
end
wezterm.on("update-status", function(window, pane)
	update_dynamic_overrides(window, pane)
end)

--- @diagnostic disable-next-line: unused-local
wezterm.on("user-var-changed", function(window, pane, name, value)
	-- wezterm.log_info("[user-var-changed]: '" .. name .. "'='" .. value .. "'")
	-- This event triggers when shell integration variables change
	if name == "WEZTERM_PROG" or name == "cwd" then
		update_dynamic_overrides(window, pane)
	end
end)

return config
