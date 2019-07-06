# build-clang-llvm

Dockerfiles for building and bootstrapping clang/LLVM, including support for libc++ and lld+LTO, directly from GitHub sources.

# Estimated Build Times

Performing a full two stage bootstrap build on a MacBook Pro 2018 (2.9 GHz Intel Core i9, 32 GB RAM) with Docker Desktop version 2.0.0.3 (31259), engine 18.09.2 takes:

```
real    111m56.801s
user    0m1.014s
sys     0m1.221s
```
