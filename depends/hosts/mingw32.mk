mingw32_CFLAGS=-pipe
mingw32_CXXFLAGS=$(mingw32_CFLAGS) -isystem $(host_prefix)/include/c++/v1

mingw32_LDFLAGS?=-fuse-ld=lld

# Port from upstream https://github.com/zcash/zcash/commit/c3693a5f857b27224707538179840eea223c1b41
mingw32_LDFLAGS+=-L/usr/lib/gcc/x86_64-w64-mingw32/$(shell x86_64-w64-mingw32-g++-posix -dumpversion)

mingw32_release_CFLAGS=-O3
mingw32_release_CXXFLAGS=$(mingw32_release_CFLAGS)

mingw32_debug_CFLAGS=-O0
mingw32_debug_CXXFLAGS=$(mingw32_debug_CFLAGS)

mingw32_debug_CPPFLAGS=-D_GLIBCXX_DEBUG -D_GLIBCXX_DEBUG_PEDANTIC
