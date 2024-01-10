package=bdb
$(package)_version=6.2.23
$(package)_download_path=https://download.oracle.com/berkeley-db
$(package)_file_name=db-$($(package)_version).tar.gz
$(package)_sha256_hash=47612c8991aa9ac2f6be721267c8d3cdccf5ac83105df8e50809daea24e95dc7
$(package)_build_subdir=build_unix
$(package)_patches=clang-12-stpcpy-issue.diff winioctl-and-atomic_init_db.patch

ifneq ($(host_os),darwin)
$(package)_dependencies=libcxx
endif


define $(package)_set_vars
$(package)_config_opts=--disable-shared --enable-cxx --disable-replication --enable-option-checking 
$(package)_config_opts_mingw32=--enable-mingw
$(package)_config_opts_linux=--with-pic
$(package)_config_opts_freebsd=--with-pic
$(package)_ldflags+=-L$(build_prefix)/lib

ifeq ($(build_os),darwin) # When building on macOS, force x86 architecture.
$(package)_ldflags+=-arch x86_64
$(package)_cflags+=--target=x86_64-apple-darwin -I$(shell xcrun --show-sdk-path)/usr/include
$(package)_cxxflags+=--target=x86_64-apple-darwin -I$(shell xcrun --show-sdk-path)/usr/include

# Atomic support needs to be turned off, as that can't be checked while cross compiling.
$(package)_config_opts+=--disable-atomicsupport

# We need this to pick up system libraries
$(package)_ldflags+=-L$(shell xcrun --show-sdk-path)/usr/lib 
endif

ifneq ($(build_os),darwin)
$(package)_config_opts_darwin=--disable-atomicsupport
endif
$(package)_config_opts_aarch64=--disable-atomicsupport
$(package)_cxxflags+=-std=c++17

ifeq ($(host_os),freebsd)
  $(package)_ldflags+=-static-libstdc++ -lcxxrt
else
  $(package)_ldflags+=-static-libstdc++ -lc++abi
endif

endef

define $(package)_preprocess_cmds
  patch -p1 <$($(package)_patch_dir)/clang-12-stpcpy-issue.diff && \
  patch -p1 <$($(package)_patch_dir)/winioctl-and-atomic_init_db.patch
endef

define $(package)_config_cmds
  ../dist/$($(package)_autoconf)
endef

define $(package)_build_cmds
  $(MAKE) libdb_cxx-6.2.a libdb-6.2.a
endef

define $(package)_stage_cmds
  $(MAKE) DESTDIR=$($(package)_staging_dir) install
endef

define $(package)_postprocess_cmds
  cd $(BASEDIR)/../zcutil && \
  mkdir -p bin && \
  mv -f $($(package)_staging_dir)$(host_prefix)/bin/db_* bin
endef
