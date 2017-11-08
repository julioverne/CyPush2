include theos/makefiles/common.mk

TWEAK_NAME = CyPush
CyPush_FILES = /mnt/d/codes/cypush/cypushhooks/CyPush.xm
CyPush_FRAMEWORKS = CydiaSubstrate UIKit SystemConfiguration IOKit
CyPush_PRIVATE_FRAMEWORKS = AppSupport BulletinBoard SpringBoardServices
CyPush_LDFLAGS = -Wl,-segalign,4000
CyPush_CFLAGS = -fobjc-arc

export ARCHS = armv7 arm64
CyPush_ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/tweak.mk
