TARGETS := \
	openSUSE_13.2 \
	openSUSE_Leap_42.1 \
	openSUSE_Tumbleweed

REST_VERSION := $(shell perl ../../version.plx)

.PHONY: all
all: $(TARGETS)

openSUSE_13.2:
	cp Dockerfile.in Dockerfile
	sed -i 's/BASE_IMAGE/opensuse:13.2/' Dockerfile
	sed -i 's/BUILD_TARGET/openSUSE_13.2/' Dockerfile
	docker build --no-cache -t dochazka-test-13.2 .

openSUSE_Leap_42.1:
	cp Dockerfile.in Dockerfile
	sed -i 's/BASE_IMAGE/opensuse:42.1/' Dockerfile
	sed -i 's/BUILD_TARGET/openSUSE_Leap_42.1/' Dockerfile
	docker build --no-cache -t dochazka-test-42.1 .

openSUSE_Tumbleweed:
	cp Dockerfile.in Dockerfile
	sed -i 's/BASE_IMAGE/opensuse:tumbleweed/' Dockerfile
	sed -i 's/BUILD_TARGET/openSUSE_Tumbleweed/' Dockerfile
	docker build --no-cache -t dochazka-test-tumbleweed .
