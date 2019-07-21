ARG LLVM_TEST_BASE_IMAGE=coldfusionjp/alpine-clang:3.10.1-llvmorg-8.0.1
FROM ${LLVM_TEST_BASE_IMAGE}

WORKDIR /root
COPY test.cpp .
RUN clang++ -flto -o test test.cpp
CMD [ "/root/test" ]
