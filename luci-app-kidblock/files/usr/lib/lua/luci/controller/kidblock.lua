module("luci.controller.kidblock", package.seeall)

function index()
	entry({"admin", "services", "kidblock", "apply"}, call("action_apply")).leaf = true
end

function action_apply()
	local util = require "luci.util"
	local http = require "luci.http"
	local res = util.ubus("kidblock", "apply", {}) or { error = "ubus call failed" }

	http.prepare_content("application/json")
	http.write_json(res)
end
