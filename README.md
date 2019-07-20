# build-clang-llvm

[![pipeline status](https://gitlab.com/coldfusionjp/build-clang-llvm/badges/master/pipeline.svg)](https://gitlab.com/coldfusionjp/build-clang-llvm/commits/master)

Dockerfiles for building and bootstrapping clang/LLVM, including support for libc++ and lld+LTO, directly from the sources available at the GitHub mirror of the LLVM subversion repository (https://github.com/llvm/llvm-project).

CI builds are run on GitLab, using an AWS c5.4xlarge instance to compile LLVM.  The Docker images are made freely available on Docker Hub at: https://hub.docker.com/r/coldfusionjp/amazonlinux-clang .

# Estimated Build Times

Below are approximate build times required to perform a full two-stage bootstap build on various hardware configurations.  Note that building an LTO optimized clang/LLVM requires large amounts of memory.

MacBook Pro 2018 (2.9 GHz Intel Core i9, 32 GB RAM) with Docker engine 18.09.2 (Docker prefs: 24GB RAM, 2GB swap):

```
real    111m56.801s
user    0m1.014s
sys     0m1.221s
```

AWS c5.4xlarge EC2 instance (16 CPU cores, 32 GB RAM):

```
real    63m0.509s
user    0m0.996s
sys     0m0.628s
```
