--[[

Creates a list of media files in a CSV file (for Excel or other spreadsheet program)
or XSPF (VLC playlist file). When the user presses a key, the 
current media file is added to the list, along with the media's current time and
total length.

See https://forum.videolan.org/viewtopic.php?f=29&t=111880

Installation (VLC-2.0.x, Windows, using preferences):
1. Tick the option Tools > Preferences > ( Show settings = All ) > Interface \ Main interfaces: Lua interpreter
   Enter [luaintf] in the textbox (without the brackets).
2. At Tools > Preferences > ( Show settings = All ) > Interface > Main interfaces > Lua: Lua interface
   enter [media_list] in the textbox (without the brackets).
3. Save the preferences and restart VLC

Usage via command line (batch file or shortcut)x
Or you can use the command line to start VLC using the custom interface.
  vlc.exe --extraintf=luaintf --lua-intf=media_list

]]

require "common"
require "keys"
--require "hotkeys"
--require "remember_position"

_datafile = vlc.config.userdatadir().."/vlc_media_list" -- extension added as appropriate for format
_title = "[media_list]"
_format = "m3u"

Formats = {
  ["csv"] = {
    ["header"] = "name,title,length_seconds,length,time_seconds,time",
    ["format"] = "{name},{title},{length_seconds},{length},{time_seconds},{time}",
    },
  ["m3u"] = {
    ["header"] = "#EXTM3U\n",
    ["format"] = "#EXTINF:{length_seconds}{,title}\n{name}",
    },
}

Fields = { "name", "title", "length", "length_seconds", "time", "time_seconds" }

local Key = Keys.Keys -- bring the keycodes local so we can refer to them like Keys.A
_keys = {
-- keycode, key, function to call
  { Key.I, "i", "ShowMediaInfo" },
  --{ 116, "t", "ShowMediaInfo" },
  { Key.R, "r", "ActivateRememberPositions"},
  --{ Key.X, "x", "CaptureMediaInfo" },
  { Key.X, "x", "Demo2" },
}
function Demo2() { hotkeys.action(demo2) }
function Log(m)
  if m then vlc.msg.info(_title.." "..m) 
  else vlc.msg.dbg(_title.." Nothing to log")
  end
end

--[[
  Returns an info item, which contains:
    info.name
    info.title
    info.length
    info.length_seconds
    info.time
    info.time_seconds
]]
function GetMediaInfo()
	local info ={}
	local result = ""

  --DumpMeta()
  local item = vlc.item or vlc.input.item()
  if item then
    info.name = item:name()
    local meta = item:metas()
    if meta and meta["title"] then
      info.title = meta["title"]
    end
  end

	local input = vlc.object.input()
 	if input then
    info.length_seconds=vlc.var.get(input,"length")
    info.length=common.durationtostring(vlc.var.get(input,"length"))
    info.time_seconds=vlc.var.get(input,"time")
    info.time=common.durationtostring(vlc.var.get(input,"time"))
    --info.position=vlc.var.get(input,"position")
    --info.currentplid=vlc.playlist.current()
    --info.audiodelay=vlc.var.get(input,"audio-delay")
    --info.rate=vlc.var.get(input,"rate")
    --info.subtitledelay=vlc.var.get(input,"spu-delay")
  end
  return info
end

--[[
function DumpMeta()
  local item
  repeat
      item = vlc.input.item()
  until (item and item:is_preparsed())

  -- preparsing doesn't always provide all the information we want (like duration)
  repeat
  until item:stats()["demux_read_bytes"] > 0

  vlc.msg.info("name: "..item:name())
  vlc.msg.info("uri: "..vlc.strings.decode_uri(item:uri()))
  vlc.msg.info("duration: "..tostring(item:duration()))

  vlc.msg.info("meta data:")
  local meta = item:metas()
  if meta then
      for key, value in pairs(meta) do
          vlc.msg.info("  "..key..": "..value)
      end
  else
      vlc.msg.info("  no meta data available")
  end

  vlc.msg.info("info:")
  for cat, data in pairs(item:info()) do
      vlc.msg.info("  "..cat)
      for key, value in pairs(data) do
          vlc.msg.info("    "..key..": "..value)
      end
  end
end
]]
function GetMediaInfoString(info)
  local format = Formats[_format].format
  for k,v in pairs(Fields) do
    format = format:gsub("%".."{"..v.."}", info[v] and info[v] or "")
    format = format:gsub("%".."{,"..v.."}", info[v] and ","..info[v] or "")
  end
  return format
end

-- Append the name, length and time of the current media file to the CSV file.
_headerPresent = false
function CaptureMediaInfo()
	--add extension according to format
	datafile = _datafile..".".._format
  local infos = GetMediaInfoString(GetMediaInfo())

  if _headerPresent == false then CheckTitles(datafile) end
  Log("writing info")
  file = assert(io.open(datafile, "a+"))
  if file then
    file:write(infos.."\n")
    file:close()
    ShowOSD("Captured", 3)
    ShowOSD(infos, 3)
  else
    ShowOSD("Failed to capture")
  end
end

function ShowMediaInfo()
  local item = vlc.item or vlc.input.item()
  local name = ""
  local length = ""
  local time = ""
  if item then name = item:name() end
  local input = vlc.object.input()
 	if input then 
    length=common.durationtostring(vlc.var.get(input,"length")) end
    time=common.durationtostring(vlc.var.get(input,"time"))
 	local output = name.."\n"
 	output = output..time.." / "..length
 	--output = output.."Length:"..length
  ShowOSD(output, 5)
  vlc.osd.slider( 10, "horizontal", channel2 )
end

function trim(s)
  return s:match "^%s*(.-)%s*$"
end

-- Check whether the file's top row is a title row (includes 'name')
-- If not, create/overwrite the file with the title row
function CheckTitles(datafile)
  header = Formats[_format].header
  file = io.open(datafile, "r")
  if file then
    local line = file:read()
    file:close()
    if line and string.find(trim(line), trim(header)) then
      _headerPresent = true
      return
    end
  end
  file = io.open(datafile, "w")
  if file then
    file:write(header.."\n")
    file:close()
    _headerPresent = true
    ShowOSD("Created media file list")
  end
end

-- Display a message on the On-Screen Display.
-- Optionally, set the time to show the message (in seconds).
t = 3    -- default time to show messages
t0 = -t
osd = nil
function ShowOSD(msg, time)
  -- clear any old message
  vlc.osd.message("",channel1)
  t1 = os.clock()
  if t1 > (t0 + t) then
    -- old message is expired.. don't want to show it again
    osd = nil
  else
    -- if we're already displaying a message, prepend the new message to the existing one
    if osd and not osd == msg then msg = msg.."\n"..osd end
  end
  
  if time then t = time end
  -- start showing the message
  Log("OSD: "..msg)
  osd = msg
  t0 = t1
  channel1 = vlc.osd.channel_register()
  vlc.osd.message(msg, channel1, "top-left", t * 1000000)
end

-- Handle key presses.
_showUnknownKeypresses = true
function KeyPressed(var, old, key, data)
  local found = false
  for k,v in pairs(_keys) do
    if key == v[1] then
      if v[3] then
        Log(v[2].."="..v[3])
        _G[v[3]]()  -- call the function using its name as a string
      else
        Log("Function not found: "..v[3])
      end
      found = true
    end
  end
  -- if it's a key we don't know, display it in a readable format
  if found == false and _showUnknownKeypresses then 
    code = string.format("%08X (%i)", key, key)
    code = string.format("0x %s %s", string.sub(code, 1, 4), string.sub(code, 5))
    local name = Keys.GetKeyName(key)
    if name == nil then name = "" end
    ShowOSD(code.." "..name, 3) 
  end
end

vlc.var.add_callback(vlc.object.libvlc(), "key-pressed", KeyPressed)

