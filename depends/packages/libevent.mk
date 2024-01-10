package=libevent
$(package)_version=2.1.12
$(package)_download_path=https://github.com/libevent/libevent/archive/
$(package)_file_name=$(package)-$($(package)_version).tar.gz
$(package)_download_file=release-$($(package)_version)-stable.tar.gz
$(package)_sha256_hash=7180a979aaa7000e1264da484f712d403fcf7679b1e9212c4e3d09f5c93efc24
$(package)_patches=0001-fix-windows-getaddrinfo.patch

define $(package)_preprocess_cmds
   patch -p1 < $($(package)_patch_dir)/0001-fix-windows-getaddrinfo.patch && \
  ./autogen.sh
endef

# When building for Windows, we set _WIN32_WINNT to target the same Windows
# version as we do in configure. Due to quirks in libevents build system, this
# is also required to enable support for ipv6. See #19375.
define $(package)_set_vars
  $(package)_config_opts=--disable-shared --disable-openssl --disable-libevent-regress
  $(package)_config_opts += --disable-dependency-tracking --enable-option-checking
  $(package)_config_opts_release=--disable-debug-mode
  $(package)_config_opts_linux=--with-pic
  $(package)_config_opts_freebsd=--with-pic
  $(package)_cppflags_mingw32=-D_WIN32_WINNT=0x0601

  ifeq ($(build_os),darwin) # When building on macOS, force x86 architecture.
  $(package)_ldflags+=-arch x86_64
  $(package)_cflags+=--target=x86_64-apple-darwin -I$(shell xcrun --show-sdk-path)/usr/include
  $(package)_cxxflags+=--target=x86_64-apple-darwin -I$(shell xcrun --show-sdk-path)/usr/include
  endif
endef

define $(package)_config_cmds
  $($(package)_autoconf)
endef

define $(package)_build_cmds
  $(MAKE)
endef

define $(package)_stage_cmds
  $(MAKE) DESTDIR=$($(package)_staging_dir) install
endef

define $(package)_postprocess_cmds
  rm lib/*.la
endef
