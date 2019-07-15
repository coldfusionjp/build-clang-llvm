FROM amazonlinux:2018.03.0.20190514 AS stage1

# lock OS release and library versions to same as base image (2018.03) to ensure binary compatibility
RUN sed -i 's;^releasever.*;releasever=2018.03;;' /etc/yum.conf && \
	yum clean all && \
	yum install -y \
		cmake3 \
		file \
		gcc72-c++ \
		git \
		which

# clone desired LLVM tag from GitHub
WORKDIR /root
ARG LLVM_GIT_TAG="llvmorg-8.0.0"
RUN git clone https://github.com/llvm/llvm-project --branch "${LLVM_GIT_TAG}" --single-branch --depth 1

# stage 1: build initial clang/libc++/lld using gcc/stdlibc++/GNU ld
WORKDIR /root/build
RUN cmake3 -G "Unix Makefiles" \
		-DCMAKE_BUILD_TYPE="MinSizeRel" \
		-DCMAKE_INSTALL_PREFIX="/usr/local/llvm-stage1" \
		-DCLANG_DEFAULT_CXX_STDLIB="libc++" \
		-DCLANG_DEFAULT_LINKER="lld" \
		-DLLVM_ENABLE_PROJECTS="clang;libcxx;libcxxabi;lld" \
		-DLLVM_INSTALL_TOOLCHAIN_ONLY="ON" \
		-DLLVM_INCLUDE_EXAMPLES="OFF" \
		-DLLVM_INCLUDE_TESTS="OFF" \
		-DLLVM_INCLUDE_BENCHMARKS="OFF" \
		-DLLVM_TARGETS_TO_BUILD="X86" \
		-DLLVM_TARGET_ARCH="host" \
		-DBUILD_SHARED_LIBS="OFF" "../llvm-project/llvm"

RUN make -j $(nproc)
RUN make install

#=====================================================================================================

FROM amazonlinux:2018.03.0.20190514 AS stage2

# lock OS release and library versions to same as base image (2018.03) to ensure binary compatibility
RUN sed -i 's;^releasever.*;releasever=2018.03;;' /etc/yum.conf && \
	yum clean all && \
	yum install -y \
		cmake3 \
		file \
		gcc72 \
		which

# copy cloned LLVM GitHub source tree and built binaries from stage1
WORKDIR /root
COPY --from=stage1 /root/llvm-project ./llvm-project
COPY --from=stage1 /usr/local/llvm-stage1 /usr/local/llvm-stage1

# add llvm-stage1 libc++ shared libraries to linker library path
RUN echo "/usr/local/llvm-stage1/lib" > /etc/ld.so.conf.d/llvm-stage1.conf && ldconfig

# stage 2: build fully optimized clang/libc++/lld using initial clang/libc++/lld built in stage1
WORKDIR /root/build
ARG LLVM_CXXFLAGS="-ffunction-sections -fdata-sections"
ARG LLVM_LDFLAGS="-Wl,--plugin-opt=O2 -Wl,--gc-sections -Wl,--as-needed -Wl,--strip-all"
RUN cmake3 -G "Unix Makefiles" \
		-DCMAKE_BUILD_TYPE="MinSizeRel" \
		-DCMAKE_INSTALL_PREFIX="/usr/local/llvm" \
		-DCMAKE_C_COMPILER="/usr/local/llvm-stage1/bin/clang" \
		-DCMAKE_CXX_COMPILER="/usr/local/llvm-stage1/bin/clang++" \
		-DCMAKE_CXX_FLAGS="${LLVM_CXXFLAGS}" \
		-DCMAKE_EXE_LINKER_FLAGS="${LLVM_LDFLAGS}" \
		-DCMAKE_SHARED_LINKER_FLAGS="${LLVM_LDFLAGS}" \
		-DCMAKE_MODULE_LINKER_FLAGS="${LLVM_LDFLAGS}" \
		-DCLANG_DEFAULT_CXX_STDLIB="libc++" \
		-DCLANG_DEFAULT_LINKER="lld" \
		-DLLVM_ENABLE_PROJECTS="clang;libcxx;libcxxabi;lld" \
		-DLLVM_ENABLE_LLD="ON" \
		-DLLVM_ENABLE_LTO="ON" \
		-DLLVM_INSTALL_TOOLCHAIN_ONLY="ON" \
		-DLLVM_INCLUDE_EXAMPLES="OFF" \
		-DLLVM_INCLUDE_TESTS="OFF" \
		-DLLVM_INCLUDE_BENCHMARKS="OFF" \
		-DLLVM_TARGETS_TO_BUILD="X86" \
		-DLLVM_TARGET_ARCH="host" \
		-DBUILD_SHARED_LIBS="OFF" "../llvm-project/llvm"

RUN make -j $(nproc)
RUN make install

#=====================================================================================================

FROM amazonlinux:2018.03.0.20190514

# lock OS release and library versions to same as base image (2018.03) to ensure binary compatibility
# clang/lld still depends on libgcc (/usr/lib/gcc/x86_64-amazon-linux/7), however the package that provides that is gcc72, so we must install it
RUN sed -i 's;^releasever.*;releasever=2018.03;;' /etc/yum.conf && \
	yum clean all && \
	yum install -y \
		gcc72

# copy final clang/libc++/lld from stage2
COPY --from=stage2 /usr/local/llvm /usr/local/llvm

# add llvm libc++ shared libraries to linker library path
RUN echo "/usr/local/llvm/lib" > /etc/ld.so.conf.d/llvm-libcxx.conf && ldconfig

# setup clang/lld as alternatives
RUN update-alternatives --install /usr/bin/clang   clang   /usr/local/llvm/bin/clang   1 && \
	update-alternatives --install /usr/bin/clang++ clang++ /usr/local/llvm/bin/clang++ 1 && \
	update-alternatives --install /usr/bin/ld.lld  ld.lld  /usr/local/llvm/bin/ld.lld  1 && \
	update-alternatives --install /usr/bin/cc      cc      /usr/local/llvm/bin/clang   1 && \
	update-alternatives --install /usr/bin/c++     c++     /usr/local/llvm/bin/clang++ 1 && \
	update-alternatives --install /usr/bin/ld      ld      /usr/local/llvm/bin/ld.lld  1 && \
	update-alternatives --set                      cc      /usr/local/llvm/bin/clang     && \
	update-alternatives --set                      c++     /usr/local/llvm/bin/clang++   && \
	update-alternatives --set                      ld      /usr/local/llvm/bin/ld.lld
