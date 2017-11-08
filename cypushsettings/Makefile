include theos/makefiles/common.mk

BUNDLE_NAME = CyPushSettings
CyPushSettings_FILES = /mnt/d/codes/cypush/cypushsettings/CyPushSettingsController.mm
CyPushSettings_INSTALL_PATH = /Library/PreferenceBundles
CyPushSettings_FRAMEWORKS = UIKit QuartzCore CoreGraphics MessageUI Social Twitter
CyPushSettings_PRIVATE_FRAMEWORKS = Preferences
CyPushSettings_CFLAGS = -fobjc-arc
CyPushSettings_LDFLAGS = -Wl,-segalign,4000
CyPushSettings_ARCHS = armv7 arm64
export ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/bundle.mk

