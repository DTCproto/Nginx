FROM gcc:15 AS builder

ARG BORINGSSL_COMMIT_ID="HEAD~0"
ARG BUILD_SHARED_LIBS="1"

# 安装 GCC 15 和构建工具
RUN set -eux; \
	apt-get update; \
	DEBIAN_FRONTEND=noninteractive \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		tzdata \
		git \
		make \
		cmake \
		ninja-build \
		; \
	rm -rf /var/lib/apt/lists/*; \
	mkdir -p /usr/src;

# CMAKE_BUILD_TYPE: Debug, Release, RelWithDebInfo, MinSizeRel
# -j$(getconf _NPROCESSORS_ONLN) | -j"$(nproc)"
RUN set -eux; \
	# git clone https://boringssl.googlesource.com/boringssl /usr/src/boringssl; \
	git clone https://github.com/google/boringssl.git /usr/src/boringssl; \
	cd /usr/src/boringssl; \
	git checkout --force --quiet ${BORINGSSL_COMMIT_ID}; \
	mkdir -p /usr/src/boringssl/build; \
	cmake -B/usr/src/boringssl/build -S/usr/src/boringssl \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS} \
		-DCMAKE_C_FLAGS="-O2 -fPIC" \
		-DCMAKE_CXX_FLAGS="-O2 -fPIC" \
		-GNinja; \
#	ninja -C /usr/src/boringssl/build; \
	cmake --build /usr/src/boringssl/build --parallel $(nproc);

# 复制 BoringSSL 头文件和静态库到标准路径
RUN set -eux; \
	mkdir -p /usr/boringssl/include /usr/boringssl/lib; \
	cp -r /usr/src/boringssl/include/openssl /usr/boringssl/include/openssl; \
	cp /usr/src/boringssl/build/libssl.* /usr/boringssl/lib; \
	cp /usr/src/boringssl/build/libcrypto.* /usr/boringssl/lib;

# 精简运行文件
RUN set -eux; \
	strip /usr/boringssl/lib/*;

# 方便作为基础构建镜像
FROM gcc:15-bookworm

ARG BORINGSSL_COMMIT_ID="HEAD~0"

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		tzdata \
		; \
	apt-get clean; \
	rm -rf /tmp/* /var/lib/apt/lists/*;

COPY --from=builder /usr/boringssl /usr/local

ENV LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64"

LABEL \
	description="Optimized BoringSSL for NGINX with GCC 15" \
	maintainer="Custom Auto Build" \
	openssl="BoringSSL (${BORINGSSL_COMMIT_ID})"

CMD ["sh"]
