FROM alpine:latest AS builder

ARG BORINGSSL_COMMIT_ID="HEAD~0"
ARG BUILD_SHARED_LIBS="1"

RUN set -eux; \
	mkdir -p /usr/src; \
	apk add --no-cache --virtual build-deps \
		ca-certificates \
		tzdata \
		gnupg \
		make \
		cmake \
		ninja \
		gcc \
		git \
		build-base \
		libc-dev \
		libgcc \
		libstdc++ \
		;

# CMAKE_BUILD_TYPE: Debug, Release, RelWithDebInfo, MinSizeRel
# -j$(getconf _NPROCESSORS_ONLN) | -j"$(nproc)"
RUN set -eux; \
	git clone https://boringssl.googlesource.com/boringssl /usr/src/boringssl; \
	cd /usr/src/boringssl; \
	git checkout --force --quiet ${BORINGSSL_COMMIT_ID}; \
	mkdir -p /usr/src/boringssl/build; \
	cmake -B/usr/src/boringssl/build -S/usr/src/boringssl -DCMAKE_BUILD_TYPE=Release \
	-GNinja \
	-DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS} \
	-DCMAKE_C_FLAGS="-O3 -fPIC" -DCMAKE_CXX_FLAGS="-O3 -fPIC"; \
#	ninja -C /usr/src/boringssl/build; \
	cmake --build /usr/src/boringssl/build --parallel $(nproc);

# 复制 BoringSSL 头文件和静态库到标准路径
RUN set -eux; \
	mkdir -p /usr/boringssl/include /usr/boringssl/lib; \
	cp -r /usr/src/boringssl/include/openssl /usr/boringssl/include/openssl; \
	cp /usr/src/boringssl/build/libssl.* /usr/boringssl/lib; \
	cp /usr/src/boringssl/build/libcrypto.* /usr/boringssl/lib;

FROM alpine:latest

ARG BORINGSSL_COMMIT_ID="HEAD~0"

RUN set -eux; \
    apk add --no-cache \
    tzdata \
    ca-certificates;

COPY --from=builder /usr/boringssl /usr/local
COPY --from=builder /usr/lib /usr/lib

# clean
RUN set -eux; \
	rm -rf /tmp/* /var/cache/apk/*;

LABEL \
	description="Optimized BoringSSL for NGINX" \
    maintainer="Custom Auto Build" \
	openssl="BoringSSL (${BORINGSSL_COMMIT_ID})"

CMD ["sh"]
