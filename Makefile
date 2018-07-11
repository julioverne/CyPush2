include theos/makefiles/common.mk

SUBPROJECTS += cypushhooks
SUBPROJECTS += cypushsettings
SUBPROJECTS += tool

include $(THEOS_MAKE_PATH)/aggregate.mk

all::
	
