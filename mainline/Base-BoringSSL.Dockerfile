FROM gcc:15-trixie AS builder

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
		libtool \
		bash \
		pkg-config \
		build-essential \
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
	cp -r /usr/src/boringssl/build/* /usr/boringssl/lib; \
	ls /usr/boringssl/lib;

# clean
RUN set -eux; \
	rm -rf /tmp/* /usr/src;

ENV LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:/usr/boringssl/lib"

LABEL \
	description="Optimized BoringSSL for NGINX with GCC 15" \
	maintainer="Custom Auto Build" \
	openssl="BoringSSL (${BORINGSSL_COMMIT_ID})"

CMD ["sh"]
