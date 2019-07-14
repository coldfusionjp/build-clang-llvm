SHELL				:= /bin/bash
DOCKER_HUB_IMAGE	:= coldfusionjp/amazon-linux-clang:2018.03.0.20190514-clang-8.0.1-rc3

default: build/amazon-linux-2018.03.0.20190514.log

# build a Docker image given a Dockerfile
build/%.log: Dockerfiles/%.Dockerfile
	@mkdir -p $(dir $@)
	time docker build -t ${DOCKER_HUB_IMAGE}$(findstring .test,$<) -f $< . | tee $@ ; exit "$${PIPESTATUS[0]}"

test-build: default build/amazon-linux-2018.03.0.20190514.test.log

test: test-build
	if [ "$(shell docker run --rm -t ${DOCKER_HUB_IMAGE}.test)" != "Hello world!" ]; then \
		exit 1; \
	fi

ci-pull:
	docker pull ${DOCKER_HUB_IMAGE} || true

ci-push:
	docker push ${DOCKER_HUB_IMAGE}

ci:
	make ci-pull
	make
	make test
	make ci-push

clean:
	rm -rf build
