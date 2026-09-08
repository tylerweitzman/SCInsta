INSTALL_TARGET_PROCESSES = Hinge
TWEAK_NAME = Hinge
ARCHS = arm64
TARGET := iphone:clang:latest:16.0
include $(THEOS)/makefiles/common.mk
export SYSROOT = $(THEOS)/sdks/iPhoneOS16.5.sdk

Hinge_FILES = $(wildcard *.x) $(wildcard *.m)
Hinge_FRAMEWORKS = UIKit Foundation DeviceCheck Security QuartzCore
Hinge_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function -Wno-unused-property-ivar -Wno-error

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += libflex
include $(THEOS_MAKE_PATH)/aggregate.mk
