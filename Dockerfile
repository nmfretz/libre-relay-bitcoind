# Berkeley DB stage - using pre-built image so that overall build time fits withing GitHub CI limits.
FROM lncm/berkeleydb:v4.8.30.NC AS berkeleydb

# Build stage
FROM debian:bookworm-slim AS builder

# Copy Berkeley DB from pre-built image
COPY --from=berkeleydb /opt/ /opt/

# Install build dependencies
RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    build-essential \
    libboost-all-dev \
    libevent-dev \
    # Berkeley DB is only required for the legacy wallet. Ubuntu and Debian have their own libdb-dev and libdb++-dev packages, but these will install Berkeley DB 5.3 or later. This will break binary wallet compatibility with the distributed executables, which are based on BerkeleyDB 4.8. Otherwise, you can build Berkeley DB yourself.
    # libdb-dev \
    # libdb++-dev \
    libtool \
    pkg-config \
    libzmq3-dev \
    libsqlite3-dev \
    # python3 - only needed if running test suite
    # optional for UPnP support:
    # libminiupnpc-dev \
    # optional for NAT-PMP support:
    # libnatpmp-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy local bitcoin source
WORKDIR /build
COPY . .

# Build Bitcoin Core
RUN ./autogen.sh
RUN ./configure \
    # Configure with Berkeley DB paths
    LDFLAGS=-L/opt/db4/lib/ \
    CPPFLAGS=-I/opt/db4/include/ \
    CXXFLAGS="-O2" \
    --build=$(dpkg-architecture -qDEB_BUILD_GNU_TYPE) \
    --host=$(dpkg-architecture -qDEB_HOST_GNU_TYPE) \
    --prefix=/build \
    --disable-man \
    --disable-shared \
    --disable-ccache \
    --disable-tests \
    --disable-fuzz \
    --disable-bench \
    --enable-static \
    --enable-reduce-exports \
    --without-gui \
    --without-libs \
    --with-utils \
    --with-sqlite \
    --with-daemon

# Build
RUN make -j$(nproc) && \
    make install

# Final stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libevent-2.1-7 \
    libevent-pthreads-2.1-7 \
    libzmq5 \
    libsqlite3-0 \
    libdb5.3++ \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/bin/bitcoind /bin
COPY --from=builder /build/bin/bitcoin-cli /bin

ENV HOME=/data
VOLUME /data/.bitcoin

EXPOSE 8332 8333 18332 18333 18443 18444

ENTRYPOINT ["bitcoind"]