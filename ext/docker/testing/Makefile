TARGETS := \
	openSUSE_Leap_15.2 \
	openSUSE_Tumbleweed

REST_VERSION := $(shell perl ../../version.plx)

.PHONY: all
all: $(TARGETS)

openSUSE_Leap_15.2:
	cp Dockerfile.in Dockerfile
	sed -i 's#BASE_IMAGE#opensuse/leap:15.2#' Dockerfile
	sed -i 's/BUILD_TARGET/openSUSE_Leap_15.2/' Dockerfile
	podman build --no-cache -t dochazka-test-15.2 .

openSUSE_Tumbleweed:
	cp Dockerfile.in Dockerfile
	sed -i 's#BASE_IMAGE#opensuse/tumbleweed:latest#' Dockerfile
	sed -i 's/BUILD_TARGET/openSUSE_Tumbleweed/' Dockerfile
	podman build --no-cache -t dochazka-test-tumbleweed .
