-- mod-version:2 -- lite-xl 2.0
local subprocess = require "process"

local core = require "core"
local style = require "core.style"
local config = require "core.config"

--[[
  Example config (put it in user module):

  ```
  local fontconfig = require "plugins.fontconfig"
  fontconfig.use {
    font = { name = 'sans', size = 13 * SCALE },
    code_font = { name = 'monospace', size = 13 * SCALE },
  }
  ```

  if you want the fonts to load instantaneously on startup,
  you can try your luck on fontconfig.use_blocking. I won't be responsible for
  the slow startup time.
]]

local function resolve_font(spec)
  local scan_rate = 1 / config.fps
  local proc = subprocess.start({ "fc-match", "-s", "-f", "%{file}\n", spec }, {
    stdin = subprocess.REDIRECT_DISCARD,
    stdout = subprocess.REDIRECT_PIPE,
    stderr = subprocess.REDIRECT_STDOUT
  })
  local prev
  local lines = {}
  while proc:running() do
    coroutine.yield(scan_rate)
    local buf = proc:read_stdout()
    if type(buf) == "string" then
      local last_line_start = 1
      for line, ln in string.gmatch(buf, "([^\n]-)\n()") do
        last_line_start = ln
        if prev then line = prev .. line end
        table.insert(lines, line)
      end
      prev = last_line_start < #buf and string.sub(buf, last_line_start)
    end
  end
  if prev then table.insert(lines, prev) end

  if proc:returncode() ~= 0 or #lines < 1 then
    error(string.format("Cannot find a font matching the given specs: %q", spec), 0)
  end
  return lines[1]
end


local M = {}

function M.load(font_name, font_size, font_opt)
  local font_file = resolve_font(font_name)
  return renderer.font.load(font_file, font_size, font_opt)
end

function M.load_blocking(font_name, font_size, font_opt)
  local co = coroutine.create(function()
    return M.load(font_name, font_size, font_opt)
  end)
  local result
  while coroutine.status(co) ~= "dead" do
    local ok, err = coroutine.resume(co)
    if not ok then error(err) end
    result = err
  end
  return result
end

function M.use(spec)
  core.add_thread(function()
    for key, value in pairs(spec) do
      style[key] = M.load(value.name, value.size, value)
    end
  end)
end

-- there is basically no need for this, but for the sake of completeness
-- I'll leave this here
function M.use_blocking(spec)
  for key, value in pairs(spec) do
    style[key] = M.load_blocking(value.name, value.size, value)
  end
end

return M
