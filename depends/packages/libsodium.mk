package=libsodium
$(package)_version=1.0.18
$(package)_download_path=https://download.libsodium.org/libsodium/releases/
$(package)_file_name=$(package)-$($(package)_version).tar.gz
$(package)_sha256_hash=6f504490b342a4f8a4c4a02fc9b866cbef8622d5df4e5452b46be121e46636c1
$(package)_dependencies=
$(package)_patches=1.0.15-pubkey-validation.diff 1.0.15-signature-validation.diff
$(package)_config_opts=

define $(package)_set_vars

ifeq ($(build_os),darwin) # When building on macOS, force x86 architecture.
$(package)_ldflags+=-arch x86_64
$(package)_cflags+=--target=x86_64-apple-darwin -I$(shell xcrun --show-sdk-path)/usr/include
$(package)_cxxflags+=--target=x86_64-apple-darwin -I$(shell xcrun --show-sdk-path)/usr/include
endif

endef

define $(package)_preprocess_cmds
  patch -p1 < $($(package)_patch_dir)/1.0.15-pubkey-validation.diff && \
  patch -p1 < $($(package)_patch_dir)/1.0.15-signature-validation.diff && \
  cd $($(package)_build_subdir); DO_NOT_UPDATE_CONFIG_SCRIPTS=1 ./autogen.sh
endef

define $(package)_config_cmds
  $($(package)_autoconf) --enable-static --disable-shared
endef

define $(package)_build_cmds
  $(MAKE)
endef

define $(package)_stage_cmds
  $(MAKE) DESTDIR=$($(package)_staging_dir) install
endef
