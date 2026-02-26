local m, s
local days = { "mon", "tue", "wed", "thu", "fri", "sat", "sun" }

m = Map("kidblock", "KidBlock Schema")

s = m:section(TypedSection, "schedule", "Scheman")
s.template = "cbi/tblsection"
s.anonymous = false
s.addremove = true

local d = s:option(ListValue, "device", "Enhet")
d.rmempty = false
m.uci:foreach("kidblock", "device", function(sec)
	local sid = sec[".name"]
	local label = sec.name or sid
	d:value(sid, label)
end)

for _, day in ipairs(days) do
	local o = s:option(DynamicList, day, string.upper(day))
	o.placeholder = "HH:MM-HH:MM"
	o.rmempty = true
end

return m
