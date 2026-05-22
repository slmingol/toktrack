FROM rust:1.88-slim-bookworm AS builder

WORKDIR /build

# Cache dependency compilation as a separate layer.
# Only invalidated when Cargo.toml or Cargo.lock change.
COPY Cargo.toml Cargo.lock ./
RUN mkdir -p src benches && \
    echo "fn main() {}" > src/main.rs && \
    echo "" > src/lib.rs && \
    echo "fn main() {}" > benches/parser_bench.rs && \
    CARGO_PROFILE_RELEASE_LTO=false \
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16 \
    cargo build --release --bins && \
    rm -rf src benches target/release/deps/toktrack* target/release/toktrack

# Rebuild only toktrack when source changes
COPY src ./src
COPY benches ./benches
RUN CARGO_PROFILE_RELEASE_LTO=false \
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16 \
    cargo build --release --bins

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/target/release/toktrack /usr/local/bin/toktrack

CMD ["toktrack"]
