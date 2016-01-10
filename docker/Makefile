PROD_TARGETS := \
	prod-openSUSE_13.2 \
	prod-openSUSE_Leap_42.1 \
	prod-openSUSE_Tumbleweed

TEST_TARGETS := \
	test-openSUSE_13.2 \
	test-openSUSE_Leap_42.1 \
	test-openSUSE_Tumbleweed

REST_VERSION := $(shell perl ../version.plx)

.PHONY: all
all: prod test

prod: $(PROD_TARGETS)

test: $(TEST_TARGETS)

.PHONY: prod-openSUSE_13.2
prod-openSUSE_13.2:
	cp Dockerfile-prod.in Dockerfile
	sed -i 's/BASE_IMAGE/opensuse:13.2/' Dockerfile
	sed -i 's/BUILD_TARGET/openSUSE_13.2/' Dockerfile
	docker build --no-cache -t smithfarm/dochazka-13.2:$(REST_VERSION) .

.PHONY: prod-openSUSE_Leap_42.1
prod-openSUSE_Leap_42.1:
	cp Dockerfile-prod.in Dockerfile
	sed -i 's/BASE_IMAGE/opensuse:42.1/' Dockerfile
	sed -i 's/BUILD_TARGET/openSUSE_Leap_42.1/' Dockerfile
	docker build --no-cache -t smithfarm/dochazka-42.1:$(REST_VERSION) .

.PHONY: prod-openSUSE_Tumbleweed
prod-openSUSE_Tumbleweed:
	cp Dockerfile-prod.in Dockerfile
	sed -i 's/BASE_IMAGE/opensuse:tumbleweed/' Dockerfile
	sed -i 's/BUILD_TARGET/openSUSE_Tumbleweed/' Dockerfile
	docker build --no-cache -t smithfarm/dochazka-tumbleweed:$(REST_VERSION) .

test-openSUSE_13.2:
	cp Dockerfile-test.in Dockerfile
	sed -i 's/BASE_IMAGE/opensuse:13.2/' Dockerfile
	sed -i 's/BUILD_TARGET/openSUSE_13.2/' Dockerfile
	docker build --no-cache -t dochazka-test-13.2 .

test-openSUSE_Leap_42.1:
	cp Dockerfile-test.in Dockerfile
	sed -i 's/BASE_IMAGE/opensuse:42.1/' Dockerfile
	sed -i 's/BUILD_TARGET/openSUSE_Leap_42.1/' Dockerfile
	docker build --no-cache -t dochazka-test-42.1 .

test-openSUSE_Tumbleweed:
	cp Dockerfile-test.in Dockerfile
	sed -i 's/BASE_IMAGE/opensuse:tumbleweed/' Dockerfile
	sed -i 's/BUILD_TARGET/openSUSE_Tumbleweed/' Dockerfile
	docker build --no-cache -t dochazka-test-tumbleweed .
