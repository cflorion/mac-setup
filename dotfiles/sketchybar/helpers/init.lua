local home = os.getenv("HOME")
local config_dir = os.getenv("CONFIG_DIR") or (home and (home .. "/.config/sketchybar")) or "."

if home then
	package.cpath = package.cpath .. ";" .. home .. "/.local/share/sketchybar_lua/?.so"
end

os.execute("(cd \"" .. config_dir .. "/helpers\" && make)")
