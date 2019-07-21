SHELL				:= /bin/bash
BASE_IMAGES			:= alpine:3.10.1 amazonlinux:2018.03.0.20190514
LLVM_VERSIONS		:= llvmorg-8.0.1

# generate a list of output build logs for all combinations of base images and LLVM versions
OUTPUT_TARGETS		:= $(foreach img, $(BASE_IMAGES), $(foreach ver, $(LLVM_VERSIONS), build/$(subst :,+,$(img))+$(ver).log))

# return just the image name of an output target (amazonlinux)
define imageName
$(subst build/,,$(word 1,$(subst +, ,$(1))))
endef

# return the tag of an output target (2018.03.0.20190514)
define imageTag
$(word 2,$(subst +, ,$(1)))
endef

# return the LLVM version of an output target (llvmorg-8.0.1-rc3)
define llvmVersion
$(subst .log,,$(word 3,$(subst +, ,$(1))))
endef

# create the required Dockerfile for a given output target
define dockerfile
Dockerfiles/$(call imageName,$(1))_$(call imageTag,$(1)).Dockerfile
endef

define dockerfileTest
Dockerfiles/$(call imageName,$(1))_$(call imageTag,$(1)).test.Dockerfile
endef

# create a Docker Hub tag for a given output target
define dockerHubTag
coldfusionjp/$(call imageName,$(1))-clang:$(call imageTag,$(1))-$(call llvmVersion,$(1))
endef

# generate a rule to build a given output target from it's Dockerfile
define generateRule
$(target): $(call dockerfile,$(target))
	@mkdir -p $$(dir $$@)
	time docker build --build-arg LLVM_GIT_TAG="$$(call llvmVersion,$$@)" -t $$(call dockerHubTag,$$@) -f $$< . | tee $$@ ; exit "$$$${PIPESTATUS[0]}"
	docker build --build-arg LLVM_TEST_BASE_IMAGE="$$(call dockerHubTag,$$@)" -t $$(call dockerHubTag,$$@).test -f $$(call dockerfileTest,$$@) .
	TEST_OUTPUT=`docker run --rm -t $$(call dockerHubTag,$$@.test) | tr -d '"\r\n'` ; echo "$$$${TEST_OUTPUT}" ; \
	if [ "$$$${TEST_OUTPUT}" != "Hello world!" ] ; then \
		exit 1 ; \
	fi
	docker push $$(call dockerHubTag,$$@)
endef

.DELETE_ON_ERROR:

default: $(OUTPUT_TARGETS)

$(foreach target, $(OUTPUT_TARGETS), $(eval $(generateRule)))

clean:
	rm -rf build
