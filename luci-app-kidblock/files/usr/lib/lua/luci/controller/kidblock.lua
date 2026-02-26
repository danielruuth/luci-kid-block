module("luci.controller.kidblock", package.seeall)

function index()
	entry({"admin", "services", "kidblock", "apply"}, call("action_apply")).leaf = true
	entry({"admin", "services", "kidblock", "status_json"}, call("action_status")).leaf = true
	entry({"admin", "services", "kidblock", "override"}, call("action_override")).leaf = true
	entry({"admin", "services", "kidblock", "clear_override"}, call("action_clear_override")).leaf = true
end

local function write_json(payload)
	local http = require "luci.http"
	http.prepare_content("application/json")
	http.write_json(payload or {})
end

function action_status()
	local util = require "luci.util"
	local res = util.ubus("kidblock", "status", {}) or { error = "ubus call failed" }
	write_json(res)
end

function action_apply()
	local util = require "luci.util"
	local res = util.ubus("kidblock", "apply", {}) or { error = "ubus call failed" }
	write_json(res)
end

function action_override()
	local util = require "luci.util"
	local http = require "luci.http"
	local device = http.formvalue("device")
	local minutes = tonumber(http.formvalue("minutes"))
	local res = util.ubus("kidblock", "override", {
		device = device,
		minutes = minutes,
	}) or { error = "ubus call failed" }
	write_json(res)
end

function action_clear_override()
	local util = require "luci.util"
	local http = require "luci.http"
	local device = http.formvalue("device")
	local res = util.ubus("kidblock", "clear_override", {
		device = device,
	}) or { error = "ubus call failed" }
	write_json(res)
end
