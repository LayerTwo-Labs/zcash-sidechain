package=native_clang
# To update the Clang compiler:
# - Change the versions below, and the MSYS2 version in libcxx.mk
# - Run the script ./contrib/devtools/update-clang-hashes.sh
# - Manually fix the versions for packages that don't exist (the LLVM project
#   doesn't uniformly cut binaries across releases).
# The Clang compiler should use the same LLVM version as the Rust compiler.
$(package)_major_version=15
$(package)_version=15.0.6
$(package)_download_path_linux=https://github.com/llvm/llvm-project/releases/download/llvmorg-$($(package)_version)
$(package)_download_file_linux=clang+llvm-$($(package)_version)-x86_64-linux-gnu-ubuntu-18.04.tar.xz
$(package)_file_name_linux=clang-llvm-$($(package)_version)-x86_64-linux-gnu-ubuntu-18.04.tar.xz
$(package)_sha256_hash_linux=38bc7f5563642e73e69ac5626724e206d6d539fbef653541b34cae0ba9c3f036
$(package)_download_path_darwin=https://github.com/llvm/llvm-project/releases/download/llvmorg-15.0.4
$(package)_download_file_darwin=clang+llvm-15.0.4-x86_64-apple-darwin.tar.xz
$(package)_file_name_darwin=clang-llvm-15.0.4-x86_64-apple-darwin.tar.xz
$(package)_sha256_hash_darwin=4c98d891c07c8f6661b233bf6652981f28432cfdbd6f07181114195c3536544b
# 2023-02-16: No FreeBSD packages are available for Clang 15, so we use Clang 14
# here. This means FreeBSD builds will use two different versions of LLVM, but
# FreeBSD is only a Tier 3 platform, so that is acceptable.
$(package)_download_path_freebsd=https://github.com/llvm/llvm-project/releases/download/llvmorg-14.0.6
$(package)_download_file_freebsd=clang+llvm-14.0.6-amd64-unknown-freebsd12.tar.xz
$(package)_file_name_freebsd=clang-llvm-14.0.6-amd64-unknown-freebsd12.tar.xz
$(package)_sha256_hash_freebsd=b0a7b86dacb12afb8dd2ca99ea1b894d9cce84aab7711cb1964b3005dfb09af3
$(package)_download_file_aarch64_linux=clang+llvm-$($(package)_version)-aarch64-linux-gnu.tar.xz
$(package)_file_name_aarch64_linux=clang-llvm-$($(package)_version)-aarch64-linux-gnu.tar.xz
$(package)_sha256_hash_aarch64_linux=8ca4d68cf103da8331ca3f35fe23d940c1b78fb7f0d4763c1c059e352f5d1bec

ifneq (,$(wildcard /etc/arch-release))
$(package)_dependencies=native_libtinfo
endif

# Ensure we have clang native to the builder, not the target host
ifneq ($(canonical_host),$(build))
$(package)_exact_download_path=$($(package)_download_path_$(build_os))
$(package)_exact_download_file=$($(package)_download_file_$(build_os))
$(package)_exact_file_name=$($(package)_file_name_$(build_os))
$(package)_exact_sha256_hash=$($(package)_sha256_hash_$(build_os))
endif

define $(package)_stage_cmds
  mkdir -p $($(package)_staging_prefix_dir)/bin && \
  cp bin/clang-$($(package)_major_version) $($(package)_staging_prefix_dir)/bin && \
  cp bin/lld $($(package)_staging_prefix_dir)/bin && \
  cp bin/llvm-ar $($(package)_staging_prefix_dir)/bin && \
  cp bin/llvm-config $($(package)_staging_prefix_dir)/bin && \
  cp bin/llvm-nm $($(package)_staging_prefix_dir)/bin && \
  cp bin/llvm-objcopy $($(package)_staging_prefix_dir)/bin && \
  cp -P bin/clang $($(package)_staging_prefix_dir)/bin && \
  cp -P bin/clang++ $($(package)_staging_prefix_dir)/bin && \
  cp -P bin/ld.lld $($(package)_staging_prefix_dir)/bin && \
  cp -P bin/ld64.lld $($(package)_staging_prefix_dir)/bin && \
  cp -P bin/lld-link $($(package)_staging_prefix_dir)/bin && \
  cp -P bin/llvm-ranlib $($(package)_staging_prefix_dir)/bin && \
  cp -P bin/llvm-strip $($(package)_staging_prefix_dir)/bin && \
  (test ! -f include/x86_64-unknown-linux-gnu/c++/v1/__config_site || \
   cp include/x86_64-unknown-linux-gnu/c++/v1/__config_site include/c++/v1/__config_site) && \
  mv include/ $($(package)_staging_prefix_dir) && \
  mv lib/ $($(package)_staging_prefix_dir) && \
  mv libexec/ $($(package)_staging_prefix_dir)
endef
