# .ONESHELL:
include dependencies.properties

# --- Log Colors ---
blue   := \033[1;34m
green  := \033[1;92m
yellow := \033[1;33m
reset  := \033[0m
# --- Log helpers ---
# Usage: $(BLUE) <text> $(DONE)
BLUE   := echo -e "$(blue)
GREEN  := echo -e "$(green)
YELLOW := echo -e "$(yellow)
DONE := $(reset)"

MKDIR := mkdir -p
RM  := rm -rf
SEP :=/

ifeq ($(OS),Windows_NT)
    ifeq ($(IS_GITHUB_ACTIONS),)
		# MKDIR := -mkdir
		RM := rmdir /s /q
		# SEP:=\\
	endif
endif


# Define sed command based on the OS
ifeq ($(OS),Windows_NT)
    # Windows (Assume Git Bash or similar sed is available, or standard syntax)
    SED := sed -i
else
	ifeq ($(shell uname),Darwin) # macOS
    	SED :=sed -i ''
	else # Linux
    	SED :=sed -i
	endif
endif


BINDIR=hiddify-core$(SEP)bin
ANDROID_OUT=android$(SEP)app$(SEP)libs
DESKTOP_OUT=hiddify-core$(SEP)bin
GEO_ASSETS_DIR=assets$(SEP)core

CORE_PRODUCT_NAME=hiddify-core
CORE_NAME=hiddify-lib
LIB_NAME=hiddify-core

ifeq ($(CHANNEL),prod)
	CORE_URL=https://github.com/hiddify/hiddify-next-core/releases/download/v$(core.version)
else
	CORE_URL=https://github.com/hiddify/hiddify-next-core/releases/download/draft
endif

ifeq ($(CHANNEL),prod)
	TARGET=lib/main_prod.dart
else
	TARGET=lib/main.dart
endif

BUILD_ARGS=--dart-define sentry_dsn=$(SENTRY_DSN)
DISTRIBUTOR_ARGS=--skip-clean --build-target $(TARGET) --build-dart-define sentry_dsn=$(SENTRY_DSN)



get:	
	flutter pub get

gen:
	dart run build_runner build --delete-conflicting-outputs

translate:
	dart run slang



prepare:
	@echo use the following commands to prepare the library for each platform:
	@echo    make android-prepare
	@echo    make windows-prepare

common-prepare:  get gen translate
windows-prepare: common-prepare windows-libs

android-prepare:common-prepare android-libs	
android-apk-prepare:android-prepare
android-aab-prepare:android-prepare

.PHONY: generate_kotlin_protos
generate_kotlin_protos: 
	# Run protoc to generate Kotlin files
	# protoc \
	# 	--proto_path=hiddify-core/ \
	# 	--java_out=./android/app/src/main/java/ \
	# 	--grpc-java_out=./android/app/src/main/java/ \
	# 	$(shell find hiddify-core/v2 hiddify-core/extension -name "*.proto")
	rsync -av --delete \
		--include='*/' \
		--include='*.proto' \
		--exclude='*' \
		hiddify-core/v2 hiddify-core/extension ./android/app/src/main/protos/
	# # Find .proto files and update package declarations
	# find "./android/app/src/main/java/com/hiddify/hiddify/protos" -type f -name "*.java" | while read -r proto_file; do \
	#     if grep -q "^package " "$$proto_file"; then \
	#         $(SED) 's/^package \([\w\.]*\)/package com.hiddify.hiddify.protos.\1/g' "$$proto_file"; \
	#     fi \
	# done

generate_go_protoc:
	make -C hiddify-core -f Makefile protos
	echo "SED: $(SED)"
generate_dart_protoc:
	mkdir -p lib/hiddifycore/generated
	protoc --dart_out=grpc:lib/hiddifycore/generated --proto_path=hiddify-core/  $(shell find hiddify-core/v2 hiddify-core/extension -name "*.proto") 	google/protobuf/timestamp.proto ; \

.PHONY: protos
protos: generate_go_protoc generate_kotlin_protos generate_dart_protoc
	
	
	

android-install-deps: 
	dart pub global activate fastforge
android-apk-install-deps: android-install-deps
android-aab-install-deps: android-install-deps
# reads the Flutter version from pubspec.yaml
REQUIRED_VER = $(shell sed -n '/environment:/,/flutter:/ s/.*flutter:[[:space:]]*//p' pubspec.yaml | tr -d " '^\"")

windows-install-deps:
	dart pub global activate fastforge
# 	choco install innosetup -y
	
android-release: android-apk-release android-aab-release

android-apk-release:
	fastforge package \
	  --platform android \
	  --targets apk \
	  --skip-clean \
	  --build-target=$(TARGET) \
	  --build-target-platform=android-arm,android-arm64,android-x64 \
	  --build-dart-define=sentry_dsn=$(SENTRY_DSN)
	ls -R build/app/outputs

android-aab-release:
	fastforge package \
	  --platform android \
	  --targets aab \
	  --skip-clean \
	  --build-target=$(TARGET) \
	  --build-dart-define=sentry_dsn=$(SENTRY_DSN) \
	  --build-dart-define=release=google-play

windows-release: windows-zip-release windows-exe-release windows-msix-release

windows-zip-release:
	fastforge package \
	  --platform windows \
	  --targets zip \
	  --skip-clean \
	  --build-target=$(TARGET) \
	  --build-dart-define=sentry_dsn=$(SENTRY_DSN) \
	  --build-dart-define=portable=true
	@FULL_PATH=$$(ls dist/*/*.zip | head -n 1); \
	ZIP_DIR=$$(dirname "$$FULL_PATH"); \
	ZIP_FILE=$$(basename "$$FULL_PATH"); \
	FILE_NAME=$${ZIP_FILE%.*}; \
	$(YELLOW)Post-processing Windows portable$(DONE); \
	cd "$$ZIP_DIR"; \
	$(BLUE)Extracting and Repacking...$(DONE); \
	mkdir -p WEPBOX; \
	unzip -q "$$ZIP_FILE" -d WEPBOX/; \
	rm "$$ZIP_FILE"; \
	tar -a -cf "$$FILE_NAME.zip" WEPBOX; \
	rm -rf WEPBOX; \
	$(GREEN)Successful$(DONE)

windows-exe-release:
	fastforge package \
	  --platform windows \
	  --targets exe \
	  --skip-clean \
	  --build-target=$(TARGET) \
	  --build-dart-define=sentry_dsn=$(SENTRY_DSN)

windows-msix-release:
	fastforge package \
	  --platform windows \
	  --targets msix \
	  --skip-clean \
	  --build-target=$(TARGET) \
	  --build-dart-define=sentry_dsn=$(SENTRY_DSN)

android-libs:
	$(MKDIR) $(ANDROID_OUT) || echo Folder already exists. Skipping...
	curl -L $(CORE_URL)/$(CORE_NAME)-android.tar.gz | tar xz -C $(ANDROID_OUT)/

android-apk-libs: android-libs
android-aab-libs: android-libs

windows-libs:
	$(MKDIR) $(DESKTOP_OUT) || echo Folder already exists. Skipping...
	curl -L $(CORE_URL)/$(CORE_NAME)-windows-amd64.tar.gz | tar xz -C $(DESKTOP_OUT)/
	ls $(DESKTOP_OUT) || dir $(DESKTOP_OUT)/
	

get-geo-assets:
	echo ""
	# curl -L https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db -o $(GEO_ASSETS_DIR)/geoip.db
	# curl -L https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db -o $(GEO_ASSETS_DIR)/geosite.db

build-headers:
	make -C hiddify-core -f Makefile headers && mv $(BINDIR)/$(CORE_NAME)-headers.h $(BINDIR)/hiddify-core.h

build-android-libs:
	make -C hiddify-core -f Makefile android 
	mv $(BINDIR)/$(LIB_NAME).aar $(ANDROID_OUT)/

build-windows-libs:
	make -C hiddify-core -f Makefile windows-amd64

release: # Create a new tag for release.
	@CORE_VERSION=$(core.version) bash -c ".github/change_version.sh "
