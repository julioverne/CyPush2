include theos/makefiles/common.mk

TOOL_NAME = cypushchk
cypushchk_FILES = /mnt/d/codes/cypush/tool/main.mm

cypushchk_FRAMEWORKS = UIKit
cypushchk_PRIVATE_FRAMEWORKS = SpringBoardServices
cypushchk_ARCHS = armv7 arm64
export ARCHS = armv7 arm64
cypushchk_CFLAGS = -fobjc-arc
cypushchk_CODESIGN_FLAGS="-Sen.plist"

include $(THEOS_MAKE_PATH)/tool.mk



