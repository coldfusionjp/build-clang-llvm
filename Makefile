SHELL				:= /bin/bash

default: build/amazon-linux-2018.03.0.20190514.log

# build a Docker image given a Dockerfile
build/%.log: Dockerfiles/%.Dockerfile
	@mkdir -p $(dir $@)
	time docker build -t coldfusionjp/amazon-linux-clang:2018.03.0.20190514-clang-8.0.1-rc3$(findstring .test,$<) -f $< . | tee $@ ; exit "$${PIPESTATUS[0]}"

test-build: default build/amazon-linux-2018.03.0.20190514.test.log

test: test-build
	if [ "$(shell docker run --rm -t coldfusionjp/amazon-linux-clang:2018.03.0.20190514-clang-8.0.1-rc3.test)" != "Hello world!" ]; then \
		exit 1; \
	fi

clean:
	rm -rf build
