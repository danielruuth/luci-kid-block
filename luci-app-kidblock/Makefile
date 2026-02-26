include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-kidblock
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

PKGARCH:=all

define Package/luci-app-kidblock
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI interface for kidblock
  DEPENDS:=+luci-base +luci-compat +kidblock +lua +libubus-lua +libuci-lua
endef

define Package/luci-app-kidblock/description
 LuCI app for configuring kidblock devices, schedule and runtime apply/status.
endef

define Build/Compile
endef

define Package/luci-app-kidblock/install
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./files/usr/share/luci/menu.d/luci-app-kidblock.json $(1)/usr/share/luci/menu.d/luci-app-kidblock.json
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/controller/kidblock.lua $(1)/usr/lib/lua/luci/controller/kidblock.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/kidblock
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/model/cbi/kidblock/devices.lua $(1)/usr/lib/lua/luci/model/cbi/kidblock/devices.lua
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/model/cbi/kidblock/schedule.lua $(1)/usr/lib/lua/luci/model/cbi/kidblock/schedule.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/kidblock
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/kidblock/status.htm $(1)/usr/lib/lua/luci/view/kidblock/status.htm
endef

$(eval $(call BuildPackage,luci-app-kidblock))
