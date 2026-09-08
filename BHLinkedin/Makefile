INSTALL_TARGET_PROCESSES = BHLinkedin
TWEAK_NAME = BHLinkedin
ARCHS = arm64
TARGET := iphone:clang:latest:14.0
include $(THEOS)/makefiles/common.mk
export SYSROOT = $(THEOS)/sdks/iPhoneOS16.4.sdk

BHLinkedin_FILES = Tweak.x $(wildcard *.m)
BHLinkedin_FRAMEWORKS = UIKit Foundation AVFoundation AVKit CoreMotion GameController VideoToolbox Accelerate CoreMedia CoreImage CoreGraphics ImageIO Photos CoreServices SystemConfiguration SafariServices Security QuartzCore WebKit SceneKit
BHLinkedin_PRIVATE_FRAMEWORKS = Preferences
# BHLinkedin_EXTRA_FRAMEWORKS = Cephei CepheiPrefs CepheiUI
# BHLinkedin_EXTRA_FRAMEWORKS = Cephei CepheiUI
# BHLinkedin_OBJ_FILES = $()
BHLinkedin_LIBRARIES = sqlite3 bz2 c++ iconv z
BHLinkedin_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function -Wno-unused-property-ivar -Wno-error

include $(THEOS_MAKE_PATH)/tweak.mk

ifdef SIDELOADED
SUBPROJECTS += modules/libflex modules/FLEXall
else
SUBPROJECTS += modules/libflex modules/FLEXall
endif

include $(THEOS_MAKE_PATH)/aggregate.mk
