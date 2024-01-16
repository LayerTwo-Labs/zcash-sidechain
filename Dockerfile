FROM debian:bookworm-slim AS params-fetcher

RUN apt-get update && apt-get install -y curl
ADD zcutil/fetch-params.sh .
RUN ./fetch-params.sh

FROM debian:bookworm-slim AS worker

# Get build deps
RUN apt-get update && apt-get install -y \
 build-essential pkg-config libc6-dev m4 g++-multilib \
 autoconf libtool ncurses-dev unzip git python3 python3-zmq \
 zlib1g-dev curl bsdmainutils automake libtinfo5

COPY . .

RUN make -C ./depends/

ARG CONFIGURE_FLAGS="--disable-tests --disable-bench --disable-hardening --enable-online-rust"

# cargo fails later for some reason, if this dir doesn't exist
RUN mkdir .cargo 
RUN ./autogen.sh

# Build the C++ Rust bindings
RUN export CONFIG_SITE="/depends/$(./depends/config.guess)/share/config.site" && \
    ./configure ${CONFIGURE_FLAGS} && \
    make -C src cargo-build-lib

# Update the build settings to include the C++ Rust bindings, 
# and run the actual build
RUN export CONFIG_SITE="/depends/$(./depends/config.guess)/share/config.site" && \
    export LDFLAGS="-L$(dirname $(find /target -name 'libcxxbridge1.a')) -lcxxbridge1" && \
    ./configure ${CONFIGURE_FLAGS} && \
    make

# Verify the binary is working
RUN ./src/zsided --help

FROM debian:bookworm-slim AS final

# Quality of life for working with RPC API
RUN apt-get update && apt-get install -y curl

COPY --from=worker /src/zcashd /src/zside-cli /usr/bin

COPY --from=params-fetcher /root/.zcash-params /root/.zcash-params

# Verify the binary is working and installed
RUN zsided --help

ENTRYPOINT ["zsided"]