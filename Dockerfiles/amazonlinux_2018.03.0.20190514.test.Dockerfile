ARG LLVM_TEST_BASE_IMAGE=coldfusionjp/amazonlinux-clang:2018.03.0.20190514-llvmorg-8.0.0
FROM ${LLVM_TEST_BASE_IMAGE}

WORKDIR /root
COPY test.cpp .
RUN clang++ -flto -o test test.cpp
CMD [ "/root/test" ]
