local colors = require("colors")
local settings = require("settings")

-- The native helper publishes the total CPU load every two seconds.
sbar.exec("pgrep -x cpu_load >/dev/null && killall cpu_load; sleep 0.1; nohup $CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0 >/dev/null 2>&1 &")

local compact_label = {
  font = {
    family = settings.font.numbers,
    style = settings.font.style_map["Semibold"],
    size = 11.0,
  },
  color = colors.inactive,
}

local cpu = sbar.add("item", "widgets.cpu", {
  position = "right",
  width = 66,
  icon = { drawing = false },
  label = {
    string = "CPU --%",
    align = "right",
    font = compact_label.font,
    color = compact_label.color,
    padding_left = settings.paddings,
    padding_right = 4,
  },
})

local memory = sbar.add("item", "widgets.memory", {
  position = "right",
  width = 66,
  icon = { drawing = false },
  label = {
    string = "MEM --%",
    align = "right",
    font = compact_label.font,
    color = compact_label.color,
    padding_left = 4,
    padding_right = settings.paddings,
  },
  update_freq = 10,
})

cpu:subscribe("cpu_update", function(env)
  local load = tonumber(env.total_load)
  if load then
    cpu:set({ label = "CPU " .. load .. "%" })
  end
end)

memory:subscribe({ "routine", "system_woke" }, function()
  sbar.exec("sysctl -n hw.memsize; vm_stat", function(stats)
    local total = tonumber(stats:match("^(%d+)"))
    local page_size = tonumber(stats:match("page size of (%d+) bytes"))
    local active = tonumber(stats:match("Pages active:%s+(%d+)%."))
    local wired = tonumber(stats:match("Pages wired down:%s+(%d+)%."))
    local compressed = tonumber(stats:match("Pages occupied by compressor:%s+(%d+)%."))

    if total and page_size and active and wired and compressed then
      local used = math.floor(100 * (active + wired + compressed) * page_size / total + 0.5)
      memory:set({ label = "MEM " .. used .. "%" })
    end
  end)
end)

local function open_activity_monitor()
  sbar.exec("open -a 'Activity Monitor'")
end

cpu:subscribe("mouse.clicked", open_activity_monitor)
memory:subscribe("mouse.clicked", open_activity_monitor)

sbar.add("item", "widgets.system.padding", {
  position = "right",
  width = settings.group_paddings,
})
