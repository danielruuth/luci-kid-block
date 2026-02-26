include $(TOPDIR)/rules.mk

PKG_NAME:=kidblock
PKG_RELEASE:=1
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/kidblock
  SECTION:=net
  CATEGORY:=Network
  TITLE:=KidBlock backend for fw4/nftables
  DEPENDS:=+lua +libubus-lua +libuci-lua +nftables +conntrack
endef

define Package/kidblock/description
 KidBlock backend daemon with UCI/ubus driven nftables sets for parental control.
endef

define Build/Compile
endef

define Package/kidblock/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/kidblock $(1)/etc/config/kidblock
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/kidblock $(1)/etc/init.d/kidblock
	$(INSTALL_DIR) $(1)/etc/nftables.d
	$(INSTALL_DATA) ./files/etc/nftables.d/90-kidblock.nft $(1)/etc/nftables.d/90-kidblock.nft
	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) ./files/usr/libexec/kidblockd.lua $(1)/usr/libexec/kidblockd.lua
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./files/usr/share/rpcd/acl.d/kidblock.json $(1)/usr/share/rpcd/acl.d/kidblock.json
endef

$(eval $(call BuildPackage,kidblock))
