include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=kmod-hello-world
PKG_VERSION:=1.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define KernelPackage/hello-world
  SUBMENU:=Other modules
  TITLE:=Test kernel module to verify build/flash
  FILES:=$(PKG_BUILD_DIR)/hello-world.ko
  AUTOLOAD:=$(call AutoLoad,99,hello-world)
endef

define KernelPackage/hello-world/description
  Simple test module that prints build timestamp on load
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" \
		$(KERNEL_MAKE_FLAGS) \
		M="$(PKG_BUILD_DIR)" \
		modules
endef

$(eval $(call KernelPackage,hello-world))
