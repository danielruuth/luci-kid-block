#!/usr/bin/lua

local ubus = require("ubus")
local uci = require("uci")

local DAYS = { "sun", "mon", "tue", "wed", "thu", "fri", "sat" }
local STATE = {
	enabled = false,
	dow = "sun",
	minute_of_day = 0,
	blocked4 = {},
	blocked6 = {},
	wan_ifnames = {},
	devices = {},
}

local prev4 = {}
local prev6 = {}

local function shquote(s)
	return "'" .. tostring(s):gsub("'", [['"'"']]) .. "'"
end

local function run(cmd)
	os.execute(cmd .. " >/dev/null 2>&1")
end

local function sorted_keys(set)
	local out = {}
	for k in pairs(set) do
		out[#out + 1] = k
	end
	table.sort(out)
	return out
end

local function parse_time(hhmm)
	local h, m = hhmm:match("^(%d%d):(%d%d)$")
	if not h or not m then
		return nil
	end
	h, m = tonumber(h), tonumber(m)
	if not h or not m or h > 23 or m > 59 then
		return nil
	end
	return h * 60 + m
end

local function parse_range(s)
	if type(s) ~= "string" then
		return nil
	end
	local a, b = s:match("^%s*(%d%d:%d%d)%s*%-%s*(%d%d:%d%d)%s*$")
	if not a or not b then
		return nil
	end
	local ma, mb = parse_time(a), parse_time(b)
	if not ma or not mb then
		return nil
	end
	return ma, mb
end

local function in_range(now_minute, from_minute, to_minute)
	if from_minute == to_minute then
		return true
	end
	if from_minute < to_minute then
		return now_minute >= from_minute and now_minute < to_minute
	end
	return now_minute >= from_minute or now_minute < to_minute
end

local function is_ipv4(s)
	return type(s) == "string" and s:match("^%d+%.%d+%.%d+%.%d+$") ~= nil
end

local function is_ipv6(s)
	return type(s) == "string" and s:find(":", 1, true) ~= nil
end

local function listify(v)
	if v == nil then
		return {}
	end
	if type(v) == "table" then
		return v
	end
	return { v }
end

local function is_ifname(s)
	if type(s) ~= "string" then
		return false
	end
	if s == "" or #s > 15 then
		return false
	end
	return s:match("^[A-Za-z0-9_.:-]+$") ~= nil
end

local function nft_elem_quote(s)
	return '"' .. tostring(s):gsub('"', '\\"') .. '"'
end

local function ensure_nft_objects(lan_if, block_wan_only)
	run("nft add table inet kidblock")
	run("nft add set inet kidblock blocked4 '{ type ipv4_addr; }'")
	run("nft add set inet kidblock blocked6 '{ type ipv6_addr; }'")
	run("nft add set inet kidblock wan_ifnames '{ type ifname; }'")
	run("nft add chain inet kidblock forward_kidblock '{ type filter hook forward priority -150; policy accept; }'")
	run("nft flush chain inet kidblock forward_kidblock")
	if block_wan_only then
		run("nft add rule inet kidblock forward_kidblock iifname " .. shquote(lan_if) .. " oifname @wan_ifnames ip saddr @blocked4 drop")
		run("nft add rule inet kidblock forward_kidblock iifname " .. shquote(lan_if) .. " oifname @wan_ifnames ip6 saddr @blocked6 drop")
	else
		run("nft add rule inet kidblock forward_kidblock iifname " .. shquote(lan_if) .. " ip saddr @blocked4 drop")
		run("nft add rule inet kidblock forward_kidblock iifname " .. shquote(lan_if) .. " ip6 saddr @blocked6 drop")
	end
end

local function set_nft_elements(family, setname, elems, formatter)
	run("nft flush set " .. family .. " kidblock " .. setname)
	if #elems == 0 then
		return
	end
	local parts = {}
	for i = 1, #elems do
		parts[i] = formatter and formatter(elems[i]) or elems[i]
	end
	run("nft add element " .. family .. " kidblock " .. setname .. " { " .. table.concat(parts, ", ") .. " }")
end

local function read_config()
	local c = uci.cursor()
	local globals = c:get_all("kidblock", "globals") or {}
	local cfg = {
		enabled = tostring(globals.enabled or "0") == "1",
		interval = tonumber(globals.interval) or 30,
		block_wan_only = tostring(globals.block_wan_only or "1") ~= "0",
		lan_if = globals.lan_ifname or "br-lan",
		wan_ifs = {},
		devices = {},
		schedules = {},
	}

	if cfg.interval < 5 then
		cfg.interval = 5
	end

	local wan_ifnames = listify(globals.wan_ifname)
	local wan_set = {}
	for _, ifn in ipairs(wan_ifnames) do
		if is_ifname(ifn) then
			wan_set[ifn] = true
		end
	end
	if next(wan_set) == nil then
		wan_set["wan"] = true
	end
	cfg.wan_ifs = sorted_keys(wan_set)

	local now = os.time()
	local dirty = false
	c:foreach("kidblock", "device", function(s)
		local sid = s[".name"]
		local override = tostring(s.override or "0") == "1"
		local override_until = tonumber(s.override_until) or 0
		if override and override_until <= now then
			override = false
			override_until = 0
			c:set("kidblock", sid, "override", "0")
			c:set("kidblock", sid, "override_until", "0")
			dirty = true
		end
		cfg.devices[sid] = {
			name = s.name or sid,
			ipv4 = s.ipv4,
			ipv6 = listify(s.ipv6),
			override = override,
			override_until = override_until,
		}
	end)
	if dirty then
		c:commit("kidblock")
	end

	c:foreach("kidblock", "schedule", function(s)
		cfg.schedules[#cfg.schedules + 1] = s
	end)

	return cfg
end

local function compute_blocked(cfg)
	local now = os.date("*t")
	local epoch_now = os.time(now)
	local dow = DAYS[now.wday] or "sun"
	local mod = now.hour * 60 + now.min
	local block_device = {}

	for _, s in ipairs(cfg.schedules) do
		local dev = s.device
		if dev and cfg.devices[dev] then
			local ranges = listify(s[dow])
			for _, r in ipairs(ranges) do
				local f, t = parse_range(r)
				if f and t and in_range(mod, f, t) then
					block_device[dev] = true
					break
				end
			end
		end
	end

	for sid, d in pairs(cfg.devices) do
		if d.override and d.override_until > epoch_now then
			block_device[sid] = true
		end
	end

	local b4, b6 = {}, {}
	local states = {}
	for sid, d in pairs(cfg.devices) do
		local blocked = block_device[sid] == true
		states[#states + 1] = {
			id = sid,
			name = d.name,
			blocked = blocked and 1 or 0,
			override = d.override and 1 or 0,
			override_until = d.override_until,
		}
		if blocked then
			if is_ipv4(d.ipv4) then
				b4[d.ipv4] = true
			end
			for _, ip6 in ipairs(d.ipv6) do
				if is_ipv6(ip6) then
					b6[ip6] = true
				end
			end
		end
	end
	table.sort(states, function(a, b)
		return a.id < b.id
	end)

	return dow, mod, b4, b6, states
end

local function flush_new_conntrack(curr4, curr6)
	for ip, _ in pairs(curr4) do
		if not prev4[ip] then
			run("conntrack -D -s " .. shquote(ip))
			run("conntrack -D -d " .. shquote(ip))
		end
	end
	for ip, _ in pairs(curr6) do
		if not prev6[ip] then
			run("conntrack -f ipv6 -D -s " .. shquote(ip))
			run("conntrack -f ipv6 -D -d " .. shquote(ip))
		end
	end
end

local function apply_state(cfg, dow, mod, b4, b6, devices)
	ensure_nft_objects(cfg.lan_if, cfg.block_wan_only)
	local list4 = sorted_keys(b4)
	local list6 = sorted_keys(b6)
	set_nft_elements("inet", "blocked4", list4)
	set_nft_elements("inet", "blocked6", list6)
	set_nft_elements("inet", "wan_ifnames", cfg.wan_ifs, nft_elem_quote)

	STATE.enabled = cfg.enabled
	STATE.dow = dow
	STATE.minute_of_day = mod
	STATE.blocked4 = list4
	STATE.blocked6 = list6
	STATE.wan_ifnames = cfg.wan_ifs
	STATE.devices = devices

	prev4 = b4
	prev6 = b6
end

local function disable_all(cfg)
	ensure_nft_objects(cfg.lan_if, cfg.block_wan_only)
	set_nft_elements("inet", "blocked4", {})
	set_nft_elements("inet", "blocked6", {})
	set_nft_elements("inet", "wan_ifnames", cfg.wan_ifs, nft_elem_quote)
	prev4 = {}
	prev6 = {}
	local now = os.date("*t")
	STATE.enabled = false
	STATE.dow = DAYS[now.wday] or "sun"
	STATE.minute_of_day = (now.hour * 60) + now.min
	STATE.blocked4 = {}
	STATE.blocked6 = {}
	STATE.wan_ifnames = cfg.wan_ifs
	STATE.devices = {}
	for sid, d in pairs(cfg.devices) do
		STATE.devices[#STATE.devices + 1] = {
			id = sid,
			name = d.name,
			blocked = 0,
			override = d.override and 1 or 0,
			override_until = d.override_until,
		}
	end
	table.sort(STATE.devices, function(a, b)
		return a.id < b.id
	end)
end

local function compute_and_apply()
	local cfg = read_config()
	if not cfg.enabled then
		disable_all(cfg)
		return STATE, cfg.interval
	end

	local dow, mod, b4, b6, devices = compute_blocked(cfg)
	flush_new_conntrack(b4, b6)
	apply_state(cfg, dow, mod, b4, b6, devices)
	return STATE, cfg.interval
end

local function copy_status()
	return {
		enabled = STATE.enabled and 1 or 0,
		dow = STATE.dow,
		minute_of_day = STATE.minute_of_day,
		blocked4 = STATE.blocked4,
		blocked6 = STATE.blocked6,
		wan_ifnames = STATE.wan_ifnames,
		devices = STATE.devices,
	}
end

local function set_override(device, minutes)
	if type(device) ~= "string" or device == "" then
		return { error = "missing device" }
	end
	minutes = tonumber(minutes)
	if not minutes or minutes <= 0 then
		return { error = "minutes must be > 0" }
	end
	local c = uci.cursor()
	if not c:get("kidblock", device) then
		return { error = "unknown device" }
	end
	local until_ts = os.time() + (math.floor(minutes) * 60)
	c:set("kidblock", device, "override", "1")
	c:set("kidblock", device, "override_until", tostring(until_ts))
	c:commit("kidblock")
	compute_and_apply()
	return copy_status()
end

local function clear_override(device)
	if type(device) ~= "string" or device == "" then
		return { error = "missing device" }
	end
	local c = uci.cursor()
	if not c:get("kidblock", device) then
		return { error = "unknown device" }
	end
	c:set("kidblock", device, "override", "0")
	c:set("kidblock", device, "override_until", "0")
	c:commit("kidblock")
	compute_and_apply()
	return copy_status()
end

local conn = ubus.connect()
if not conn then
	io.stderr:write("failed to connect ubus\n")
	os.exit(1)
end

local obj_id = conn:add({
	kidblock = {
		status = {
			function()
				return copy_status()
			end, {}
		},
		apply = {
			function()
				compute_and_apply()
				return copy_status()
			end, {}
		},
		override = {
			function(req)
				return set_override(req and req.device, req and req.minutes)
			end, { device = "String", minutes = "Integer" }
		},
		clear_override = {
			function(req)
				return clear_override(req and req.device)
			end, { device = "String" }
		}
	}
})

compute_and_apply()

while true do
	local _, interval = compute_and_apply()
	conn:process(interval * 1000)
end

conn:remove(obj_id)
conn:close()
