SHELL				:= /bin/bash

default: docker-amazon-linux

docker-amazon-linux:
	time docker build -t coldfusionjp/amazon-linux-clang:2018.03.0.20190514-clang-8.0.1-rc3 -f Dockerfiles/amazon-linux-2018.03.0.20190514.Dockerfile .

test-build: docker-amazon-linux
	docker build -t coldfusionjp/amazon-linux-clang:2018.03.0.20190514-clang-8.0.1-rc3.test -f Dockerfiles/amazon-linux-2018.03.0.20190514.test.Dockerfile .

test: test-build
	if [ "$(shell docker run --rm -t coldfusionjp/amazon-linux-clang:2018.03.0.20190514-clang-8.0.1-rc3.test)" != "Hello world!" ]; then \
		exit 1; \
	fi

docker-amazon-linux-push:
	docker push coldfusionjp/amazon-linux-clang:2018.03.0.20190514-clang-8.0.1-rc3
