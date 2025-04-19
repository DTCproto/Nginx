ARG BASE_IMAGE="alpine:latest"

FROM ${BASE_IMAGE} AS builder

ARG NGINX_COMMIT_ID="HEAD~0"
ARG BORINGSSL_COMMIT_ID="HEAD~0"
ARG NGX_BROTLI_COMMIT_ID="HEAD~0"
ARG NGX_HEADERS_MORE_COMMIT_ID="HEAD~0"
ARG NJS_COMMIT_ID="HEAD~0"
ARG QUICKJS_COMMIT_ID="HEAD~0"
ARG NGX_TCP_BRUTAL_COMMIT_ID="HEAD~0"

# nginx:alpine nginx -V

ARG NGINX_CC_OPT="-O2 -fstack-clash-protection -Wformat -Werror=format-security -fno-plt"
ARG NGINX_LD_OPT="-Wl,--as-needed,-O2,--sort-common -Wl,-z,pack-relative-relocs"

ARG NGINX_MODULES_PATH="/usr/lib/nginx/modules"

# https://nginx.org/en/pgp_keys.html
# 'D6786CE303D9A9022998DC6CC8464D549AF75C0A' # Sergey Kandaurov <s.kandaurov@f5.com>
# '13C82A63B603576156E30A4EA0EA981B66B0D967' # Konstantin Pavlov <thresh@nginx.com>
# ARG GPG_KEYS=D6786CE303D9A9022998DC6CC8464D549AF75C0A

# https://github.com/nginx/ci-self-hosted/blob/main/.github/workflows/nginx-buildbot.yml

ARG NGINX_BASE_CONFIG="\
		--prefix=/etc/nginx \
		--sbin-path=/usr/sbin/nginx \
		--modules-path=${NGINX_MODULES_PATH} \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--pid-path=/var/run/nginx.pid \
		--lock-path=/var/run/nginx.lock \
		--http-client-body-temp-path=/var/cache/nginx/client_temp \
		--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
		--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
		--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
		--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
		--with-perl_modules_path=/usr/lib/perl5/vendor_perl \
		--user=nginx \
		--group=nginx \
	"

ARG NGINX_CORE_MODULES="\
		--with-http_addition_module \
		--with-http_auth_request_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_flv_module \
		--with-http_mp4_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_random_index_module \
		--with-http_secure_link_module \
		--with-http_stub_status_module \
		--with-http_slice_module \
		--with-http_v2_module \
		--with-http_v3_module \
		--with-http_ssl_module \
		--with-http_realip_module \
		--with-stream \
		--with-stream_ssl_module \
		--with-stream_ssl_preread_module \
		--with-stream_realip_module \
		--with-mail \
		--with-mail_ssl_module \
		--with-threads \
		--with-compat \
		--with-file-aio \
	"

ARG NGINX_DYNAMIC_MODULES="\
		--with-http_xslt_module=dynamic \
		--with-http_perl_module=dynamic \
		--with-http_image_filter_module=dynamic \
		--with-http_geoip_module=dynamic \
		--with-stream_geoip_module=dynamic \
		--add-dynamic-module=/usr/src/ngx_headers_more \
		--add-dynamic-module=/usr/src/ngx_brotli \
		--add-dynamic-module=/usr/src/njs/nginx \
		--add-dynamic-module=/usr/src/brutal-nginx \
	"

RUN set -eux; \
	mkdir -p /usr/src; \
	addgroup -S nginx; \
	adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx; \
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
		gd-dev \
		geoip-dev \
		libxslt-dev \
		libxml2-dev \
		linux-headers \
		pcre2-dev \
		perl-dev \
		bash \
		zlib-dev \
		;

RUN set -eux; \
	git clone https://github.com/nginx/nginx /usr/src/nginx; \
	cd /usr/src/nginx; \
	git checkout --force --quiet ${NGINX_COMMIT_ID};

RUN set -eux; \
	git clone --recurse-submodules https://github.com/google/ngx_brotli /usr/src/ngx_brotli; \
	cd /usr/src/ngx_brotli; \
	git checkout --force --quiet ${NGX_BROTLI_COMMIT_ID};

RUN set -eux; \
	git clone https://github.com/openresty/headers-more-nginx-module /usr/src/ngx_headers_more; \
	cd /usr/src/ngx_headers_more; \
	git checkout --force --quiet ${NGX_HEADERS_MORE_COMMIT_ID};

# RUN set -eux; \
#	git clone https://github.com/bellard/quickjs /usr/src/quickjs; \
#	cd /usr/src/quickjs; \
#	git checkout --force --quiet ${QUICKJS_COMMIT_ID}; \
#	mkdir -p build; \
#	CFLAGS='-O2 -fPIC' make build/libquickjs.a;

RUN set -eux; \
	git clone https://github.com/quickjs-ng/quickjs /usr/src/quickjs; \
	cd /usr/src/quickjs; \
	git checkout --force --quiet ${QUICKJS_COMMIT_ID}; \
	CFLAGS="-O2 -fPIC" cmake -B build; \
	cmake --build build --target qjs -j $(nproc);

RUN set -eux; \
	git clone https://github.com/nginx/njs /usr/src/njs; \
	cd /usr/src/njs; \
	git checkout --force --quiet ${NJS_COMMIT_ID};

RUN set -eux; \
	git clone https://github.com/sduoduo233/brutal-nginx /usr/src/brutal-nginx; \
	cd /usr/src/brutal-nginx; \
	git checkout --force --quiet ${NGX_TCP_BRUTAL_COMMIT_ID};

# Nginx不作为被依赖的共享库，无需-fPIC
# Nginx Core + Dynamic Modules
# 分开编译会导致部分模块加载异常(例如ngx_http_perl_module)
RUN set -eux; \
	cd /usr/src/nginx; \
	./auto/configure ${NGINX_BASE_CONFIG} ${NGINX_CORE_MODULES} ${NGINX_DYNAMIC_MODULES} \
	--build="nginx-core" \
	--with-cc=c++ \
	--with-cc-opt="${NGINX_CC_OPT} -I/usr/local/include -I/usr/src/quickjs -x c" \
	--with-ld-opt="${NGINX_LD_OPT} -L/usr/local/lib -L/usr/src/quickjs/build"; \
	make -j"$(nproc)"; \
	make install;

RUN set -eux; \
	cd /usr/src/nginx; \
	mkdir /etc/nginx/conf.d/; \
	mkdir /etc/nginx/stream.d/; \
	mkdir -p /usr/share/nginx/html/; \
	install -m644 docs/html/index.html /usr/share/nginx/html/; \
	install -m644 docs/html/50x.html /usr/share/nginx/html/;

# 配置环境变量和工作目录
WORKDIR /etc/nginx

COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh /etc/nginx/start.sh

RUN set -eux; \
	ln -s /usr/lib/nginx/modules /etc/nginx/modules; \
	# forward request and error logs to docker log collector
	ln -sf /dev/stdout /var/log/nginx/access.log; \
	ln -sf /dev/stderr /var/log/nginx/error.log;

RUN set -eux; \
	chown -R nginx:nginx /etc/nginx/start.sh; \
	chown -R nginx:nginx /etc/nginx/start.sh; \
	chmod -R 755 /etc/nginx/start.sh;

# clean
RUN set -eux; \
	rm -rf \
		/usr/src \
		/usr/libexec \
		; \
	rm -rf /tmp/* /var/cache/apk/*;

LABEL \
	description="Nginx Docker Build with BoringSSL" \
	maintainer="Custom Auto Build" \
	openssl="BoringSSL (${BORINGSSL_COMMIT_ID})" \
	nginx="Nginx (${NGINX_COMMIT_ID})"

# 定义容器暴露的端口
# EXPOSE 80 443

# 挂载 NGINX 配置和站点目录
VOLUME /etc/nginx/conf.d /etc/nginx/stream.d

STOPSIGNAL SIGTERM

# 设置容器启动命令
ENTRYPOINT ["/bin/bash", "/etc/nginx/start.sh"]

# 设置容器启动命令(ENTRYPOIN[]的默认参数)
CMD ["-g", "daemon off;"]
