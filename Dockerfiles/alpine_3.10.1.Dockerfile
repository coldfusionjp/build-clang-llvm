FROM alpine:3.10.1 AS stage1

RUN apk add --no-cache \
		cmake \
		git \
		g++ \
		linux-headers \
		make \
		python3 \
		zlib-dev

# clone desired LLVM tag from GitHub
WORKDIR /root
ARG LLVM_GIT_TAG="llvmorg-8.0.0"
RUN git clone https://github.com/llvm/llvm-project --branch "${LLVM_GIT_TAG}" --single-branch --depth 1

# stage 1: build initial clang/libc++/lld using g++/musl libc/libstdc++/GNU ld
WORKDIR /root/build
RUN cmake -G "Unix Makefiles" -Wno-dev \
		-DCMAKE_BUILD_TYPE="MinSizeRel" \
		-DCMAKE_INSTALL_PREFIX="/usr/local/llvm-stage1" \
		-DCLANG_DEFAULT_CXX_STDLIB="libc++" \
		-DCLANG_DEFAULT_LINKER="lld" \
		-DLIBCXX_HAS_MUSL_LIBC="ON" \
		-DLIBCXX_HAS_GCC_S_LIB="OFF" \
		-DLLVM_ENABLE_PROJECTS="clang;libcxx;libcxxabi;lld" \
		-DLLVM_HOST_TRIPLE="x86_64-linux-musl" \
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

FROM alpine:3.10.1 AS stage2

RUN apk add --no-cache \
		cmake \
		gcc \
		linux-headers \
		make \
		musl-dev \
		python3 \
		zlib-dev

# copy cloned LLVM GitHub source tree and built binaries from stage1
WORKDIR /root
COPY --from=stage1 /root/llvm-project ./llvm-project
COPY --from=stage1 /usr/local/llvm-stage1 /usr/local/llvm-stage1

# add llvm libc++ shared libraries to linker library path
RUN echo "/lib:/usr/local/lib:/usr/lib:/usr/local/llvm-stage1/lib" > /etc/ld-musl-x86_64.path

# create links to musl crtbegin/crtend/libgcc in /usr/lib so clang can find them
RUN ln -s /usr/lib/gcc/x86_64-alpine-linux-musl/8.3.0/crtbeginS.o /usr/lib/crtbeginS.o && \
	ln -s /usr/lib/gcc/x86_64-alpine-linux-musl/8.3.0/crtendS.o /usr/lib/crtendS.o && \
	ln -s /usr/lib/gcc/x86_64-alpine-linux-musl/8.3.0/libgcc.a /usr/lib/libgcc.a

# stage 2: build fully optimized clang/libc++/lld using initial clang/libc++/lld built in stage1
WORKDIR /root/build
ARG LLVM_CXXFLAGS="-ffunction-sections -fdata-sections"
ARG LLVM_LDFLAGS="-Wl,--plugin-opt=O2 -Wl,--gc-sections -Wl,--as-needed -Wl,--strip-all"
RUN cmake -G "Unix Makefiles" \
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
		-DLIBCXX_HAS_MUSL_LIBC="ON" \
		-DLIBCXX_HAS_GCC_S_LIB="OFF" \
		-DLLVM_ENABLE_PROJECTS="clang;libcxx;libcxxabi;lld" \
		-DLLVM_HOST_TRIPLE="x86_64-linux-musl" \
		-DLLVM_ENABLE_LLD="ON" \
		-DLLVM_ENABLE_LTO="OFF" \
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

FROM alpine:3.10.1

# clang/lld still depends on libgcc (/usr/lib/gcc/x86_64-alpine-linux-musl/8.3.0), however the package that provides that is gcc, so we must install it
RUN apk add --no-cache \
		dpkg \
		gcc \
		musl-dev \
		zlib

# copy final clang/libc++/lld from stage2
COPY --from=stage2 /usr/local/llvm /usr/local/llvm

# add llvm libc++ shared libraries to linker library path
RUN echo "/lib:/usr/local/lib:/usr/lib:/usr/local/llvm/lib" > /etc/ld-musl-x86_64.path

# create links to musl crtbegin/crtend/libgcc in /usr/lib so clang can find them
RUN ln -s /usr/lib/gcc/x86_64-alpine-linux-musl/8.3.0/crtbeginS.o /usr/lib/crtbeginS.o && \
	ln -s /usr/lib/gcc/x86_64-alpine-linux-musl/8.3.0/crtendS.o /usr/lib/crtendS.o && \
	ln -s /usr/lib/gcc/x86_64-alpine-linux-musl/8.3.0/libgcc.a /usr/lib/libgcc.a

# rename GNU linker so alternative can be set
RUN mv /usr/bin/ld /usr/bin/ld.gnu

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
