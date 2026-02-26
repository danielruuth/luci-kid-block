local m, s, o

m = Map("kidblock", "KidBlock")

s = m:section(NamedSection, "globals", "kidblock", "Globala inställningar")
s.anonymous = true


o = s:option(Flag, "enabled", "Aktiverad")
o.rmempty = false

o = s:option(Value, "interval", "Intervall (sekunder)")
o.datatype = "uinteger"
o.default = "30"
o.rmempty = false

o = s:option(Flag, "block_wan_only", "Blockera endast mot WAN")
o.default = "1"
o.rmempty = false

o = s:option(Value, "lan_ifname", "LAN-interface")
o.default = "br-lan"
o.rmempty = false

o = s:option(Value, "wan_ifname", "WAN-interface")
o.default = "wan"
o.rmempty = false

s = m:section(TypedSection, "device", "Enheter")
s.template = "cbi/tblsection"
s.anonymous = false
s.addremove = true


o = s:option(Value, "name", "Namn")
o.rmempty = false


o = s:option(Value, "ipv4", "IPv4")
o.datatype = "ip4addr"
o.rmempty = true


o = s:option(DynamicList, "ipv6", "IPv6")
o.datatype = "ip6addr"
o.rmempty = true

return m
