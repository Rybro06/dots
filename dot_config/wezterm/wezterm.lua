-- boilerplate setup
local wezterm = require("wezterm")
local action = wezterm.action
local config = wezterm.config_builder()

--- Get the current operating system
--- @return "windows"| "linux" | "darwin"
local function get_os()
	local bin_format = package.cpath:match("%p[\\|/]?%p(%a+)")
	if bin_format == "dll" then
		return "windows"
	elseif bin_format == "so" then
		return "linux"
	else
		return "darwin"
	end
end

local host_os = get_os()

-- colors
local transparent_bg = "rgba(44, 43, 44, 0.98)"
config.color_scheme = "GruvboxDarkHard"
config.colors = wezterm.color.get_builtin_schemes()[config.color_scheme]
config.colors.background = "#2c2b2c"

-- window
config.window_decorations = "RESIZE"
config.window_close_confirmation = "NeverPrompt"
config.window_background_image = (os.getenv("WEZTERM_CONFIG_FILE") or ""):gsub("wezterm.lua", "bg-blurred.png")
config.window_background_opacity = 0.98
-- config.kde_window_background_blur = true
config.win32_system_backdrop = "Acrylic"
config.macos_window_background_blur = 15

-- performance
config.max_fps = 144
config.animation_fps = 60
config.cursor_blink_rate = 250

-- tabs
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.show_tab_index_in_tab_bar = false
config.use_fancy_tab_bar = false
config.colors.tab_bar = {
	background = config.window_background_image and "rgba(0, 0, 0, 0)" or transparent_bg,
	new_tab = { fg_color = config.colors.background, bg_color = config.colors.brights[6] },
	new_tab_hover = { fg_color = config.colors.background, bg_color = config.colors.foreground },
}

wezterm.on("format-tab-title", function(tab, _, _, _, hover)
	local background = config.colors.background
	local foreground = config.colors.foreground

	if tab.is_active then
		background = config.colors.brights[7]
		foreground = config.colors.background
	elseif hover then
		background = config.colors.brights[8]
		foreground = config.colors.background
	end

	local title = tostring(tab.tab_index + 1)
	return {
		{ Foreground = { Color = background } },
		{ Text = "█" },
		{ Background = { Color = background } },
		{ Foreground = { Color = foreground } },
		{ Text = title },
		{ Foreground = { Color = background } },
		{ Text = "█" },
	}
end)

-- action in certain directories
wezterm.on("user-var-changed", function(window, pane, name, value)
	-- This event triggers when shell integration variables change
	if name == "WEZTERM_PROG" or name == "cwd" then
		local cwd = pane:get_current_working_dir()
		local overrides = window:get_config_overrides() or {}
		if string.find(cwd, "mcs") then
			overrides.colors.background = "#000033"
			overrides.colors.foreground = config.colors.foreground
		elseif string.find(cwd, "resq") then
			overrides.colors.background = "##330000"
			overrides.colors.foreground = config.colors.foreground
		elseif string.find(cwd, "race2") then
			overrides.colors.background = "#003300"
			overrides.colors.foreground = config.colors.foreground
		elseif string.find(cwd, "race") then
			overrides.colors.background = config.colors.foreground
			overrides.colors.foreground = config.colors.background
		end
	end
end)

-- keys
config.keys = {
	{ key = "v", mods = "CTRL", action = action.PasteFrom("Clipboard") },
	{ key = "v", mods = "CTRL", action = action.PasteFrom("PrimarySelection") },
}

config.default_prog = { "bash" }

-- OS-Specific Overrides
if host_os == "linux" then
	config.front_end = "WebGpu"
	config.window_background_image = os.getenv("HOME") .. "/.config/wezterm/bg-blurred.png"
	config.window_decorations = nil -- use system decorations
elseif host_os == "windows" then
	config.default_prog = { "pwsh", "-NoLogo" }
end

return config
