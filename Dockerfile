# Based on https://github.com/activescott/zcash-docker/blob/master/Dockerfile

FROM ubuntu:bionic

# This fixes stupid tzdata package: https://dev.to/setevoy/docker-configure-tzdata-and-timezone-during-build-20bk
ENV TZ=America/Los_Angeles
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /usr/src/zcash

# Most of this from https://zcash.readthedocs.io/en/latest/rtd_pages/user_guide.html

# Install dependencies - https://zcash.readthedocs.io/en/latest/rtd_pages/Debian-Ubuntu-build.html
RUN apt-get update && apt-get install -y \
      autoconf \
      automake \
      bsdmainutils \
      build-essential \
      curl \
      g++-multilib \
      git \
      libc6-dev \
      libtool \
      m4 \
      ncurses-dev \
      pkg-config \
      python3 \
      python3-zmq \
      unzip \
      wget \
      zlib1g-dev \
      libtinfo5 \
      libevent-dev \
      libboost-system-dev libboost-filesystem-dev libboost-chrono-dev \
      libboost-program-options-dev libboost-test-dev libboost-thread-dev \
      libssl-dev 
      
# Install Rust
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# zcash uses a newer version of Berkeley DB, that has to be built from source
# https://github.com/zcash/zcash/issues/1255
RUN wget http://download.oracle.com/berkeley-db/db-6.2.23.tar.gz && \
      tar -xzvf db-6.2.23.tar.gz && \
      cd db-6.2.23/build_unix && \
      ../dist/configure --prefix=/usr \
                  --enable-compat185 \
                  --enable-dbm \
                  --disable-static \
                  --enable-cxx && \
      make && make install

##### Checkout & Build ####
# Fetch the software and parameter files - https://github.com/zcash/zcash/wiki/1.0-User-Guide#fetch-the-software-and-parameter-files

ARG TAG=93db677b91ced8accdf67ed796f06275d09c8af2
RUN git clone https://github.com/LayerTwo-Labs/zcash-sidechain.git zcash-src

WORKDIR zcash-src
# NOTE: if you want to cause it to re-fetch, just append a comment to the below command:

RUN git checkout ${TAG}

## CLEAN ##
RUN git clean -f -x -d .

##### Fetch zkSNARK Params #####
# If the zcash params already exist (as copied from volume above, the below does nothing)
# TODO: Consider using a cache VOLUME for this when Docker 18.09 is available (see https://stackoverflow.com/a/52762779/51061)
RUN ./zcutil/fetch-params.sh

##### Build #####
RUN ./zcutil/clean.sh
# RUN ./zcutil/build.sh -j$(nproc)

RUN ./autogen.sh
RUN ./configure --disable-tests --disable-hardening --enable-online-rust RUST_TARGET=x86_64-unknown-linux-gnu 
RUN make 

##### PORTS #####
# https://zcash.readthedocs.io/en/latest/rtd_pages/troubleshooting_guide.html#system-requirements
EXPOSE 8232
EXPOSE 8233

# Mount /zcash-datadir to share blockchain across containers (and put conf there)
VOLUME /zcash-datadir

# Running Zcash - https://github.com/zcash/zcash/wiki/1.0-User-Guide#running-zcash
# NOTE: path provided to -conf seems to always  be releative to datadir
CMD ./src/zcashd 