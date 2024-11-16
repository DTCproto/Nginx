FROM alpine:latest

ARG NGINX_VERSION
ARG BORINGSSL_COMMIT_ID
ARG DYN_TLS_VERSION

# https://nginx.org/en/pgp_keys.html
# 'D6786CE303D9A9022998DC6CC8464D549AF75C0A' # Sergey Kandaurov <s.kandaurov@f5.com>
# '13C82A63B603576156E30A4EA0EA981B66B0D967' # Konstantin Pavlov <thresh@nginx.com>
ARG GPG_KEYS=D6786CE303D9A9022998DC6CC8464D549AF75C0A

ARG CONFIG="\
		--prefix=/etc/nginx \
		--sbin-path=/usr/sbin/nginx \
		--modules-path=/usr/lib/nginx/modules \
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
		--with-http_ssl_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_flv_module \
		--with-http_mp4_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_random_index_module \
		--with-http_secure_link_module \
		--with-http_stub_status_module \
		--with-http_auth_request_module \
		--with-http_xslt_module=dynamic \
		--with-http_image_filter_module=dynamic \
		--with-http_geoip_module=dynamic \
		--with-http_perl_module=dynamic \
		--with-threads \
		--with-stream \
		--with-stream_ssl_module \
		--with-stream_ssl_preread_module \
		--with-stream_realip_module \
		--with-stream_geoip_module=dynamic \
		--with-http_slice_module \
		--with-mail \
		--with-mail_ssl_module \
		--with-compat \
		--with-file-aio \
		--with-http_v2_module \
		--with-http_v3_module \
		--add-dynamic-module=/usr/src/ngx_headers_more \
		--add-dynamic-module=/usr/src/ngx_brotli \
		--add-dynamic-module=/usr/src/njs/nginx \
	"

RUN \
	addgroup -S nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
	&& apk add --no-cache --virtual .build-deps \
		autoconf \
		automake \
		bind-tools \
		binutils \
		build-base \
		ca-certificates \
		cmake \
		curl \
		gcc \
		gd-dev \
		geoip-dev \
		git \
		gnupg \
		go \
		libc-dev \
		libgcc \
		libstdc++ \
		libtool \
		libxslt-dev \
		linux-headers \
		make \
		pcre \
		pcre-dev \
		perl-dev \
		su-exec \
		tar \
		tzdata \
		zlib \
		zlib-dev \
		mercurial 

RUN \
	curl -fSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o nginx-${NGINX_VERSION}.tar.gz \
	&& mkdir -p /usr/src \
	&& tar -zxC /usr/src -f nginx-${NGINX_VERSION}.tar.gz \
	&& rm nginx-${NGINX_VERSION}.tar.gz

RUN \
	git clone --depth=1 --recurse-submodules https://github.com/google/ngx_brotli /usr/src/ngx_brotli \
	&& git clone --depth=1 https://github.com/openresty/headers-more-nginx-module /usr/src/ngx_headers_more \
	&& hg clone http://hg.nginx.org/njs /usr/src/njs

RUN \
	git clone https://boringssl.googlesource.com/boringssl /usr/src/boringssl \
	&& cd /usr/src/boringssl \
	&& git checkout --force --quiet ${BORINGSSL_COMMIT_ID} \
	&& (grep -qxF 'SET_TARGET_PROPERTIES(crypto PROPERTIES SOVERSION 1)' /usr/src/boringssl/crypto/CMakeLists.txt || echo -e '\nSET_TARGET_PROPERTIES(crypto PROPERTIES SOVERSION 1)' >> /usr/src/boringssl/crypto/CMakeLists.txt) \
	&& (grep -qxF 'SET_TARGET_PROPERTIES(ssl PROPERTIES SOVERSION 1)' /usr/src/boringssl/ssl/CMakeLists.txt || echo -e '\nSET_TARGET_PROPERTIES(ssl PROPERTIES SOVERSION 1)' >> /usr/src/boringssl/ssl/CMakeLists.txt) \
	&& mkdir -p /usr/src/boringssl/build \
	&& cmake -B/usr/src/boringssl/build -S/usr/src/boringssl -DCMAKE_BUILD_TYPE=RelWithDebInfo \
	&& make -C/usr/src/boringssl/build -j$(getconf _NPROCESSORS_ONLN)

RUN \
	cd /usr/src/nginx-${NGINX_VERSION} \
	&& curl -fSL https://raw.githubusercontent.com/DTCproto/Nginx/refs/heads/main/ngx_http_tls_dyn_size/nginx__dynamic_tls_records_${DYN_TLS_VERSION}%2B.patch -o dynamic_tls_records.patch \
	&& patch -p1 < dynamic_tls_records.patch

RUN \
	cd /usr/src/nginx-${NGINX_VERSION} \
	&& ./configure ${CONFIG} --with-debug \
	--with-cc=c++ \
	--with-cc-opt="-I/usr/src/boringssl/include -x c" \
	--with-ld-opt="-L/usr/src/boringssl/build/ssl -L/usr/src/boringssl/build/crypto"

RUN \
	cd /usr/src/nginx-${NGINX_VERSION} \
	&& make -j$(getconf _NPROCESSORS_ONLN)

RUN \
	cd /usr/src/nginx-${NGINX_VERSION} \
	&& mv objs/nginx objs/nginx-debug \
	&& mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
	&& mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
	&& mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
	&& mv objs/ngx_http_perl_module.so objs/ngx_http_perl_module-debug.so \
	&& mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so

RUN \
	cd /usr/src/nginx-${NGINX_VERSION} \
	&& ./configure ${CONFIG} \
	--with-cc=c++ \
	--with-cc-opt="-I/usr/src/boringssl/include -x c" \
	--with-ld-opt="-L/usr/src/boringssl/build/ssl -L/usr/src/boringssl/build/crypto"

RUN \
	cd /usr/src/nginx-${NGINX_VERSION} \
	&& make -j$(getconf _NPROCESSORS_ONLN)

RUN \
	cd /usr/src/nginx-${NGINX_VERSION} \
	&& make install

RUN \
	cd /usr/src/nginx-${NGINX_VERSION} \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& mkdir /etc/nginx/stream.d/ \
	&& mkdir -p /usr/share/nginx/html/ \
	&& install -m644 html/index.html /usr/share/nginx/html/ \
	&& install -m644 html/50x.html /usr/share/nginx/html/ \
	&& install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
	&& install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
	&& install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
	&& install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
	&& install -m755 objs/ngx_http_perl_module-debug.so /usr/lib/nginx/modules/ngx_http_perl_module-debug.so \
	&& install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so

RUN \
	cd /usr/src/nginx-${NGINX_VERSION} \
	&& ln -s /usr/lib/nginx/modules /etc/nginx/modules \
	&& strip /usr/sbin/nginx* \
	&& strip /usr/lib/nginx/modules/*.so \
	&& rm -rf /usr/src/nginx-${NGINX_VERSION} \
	&& rm -rf /usr/src/boringssl /usr/src/ngx_* /usr/src/njs

	# Bring in gettext so we can get `envsubst`, then throw
	# the rest away. To do this, we need to install `gettext`
	# then move `envsubst` out of the way so `gettext` can
	# be deleted completely, then move `envsubst` back.

RUN \
	apk add --no-cache --virtual .gettext gettext \
	&& mv /usr/bin/envsubst /tmp/ \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	) tzdata ca-certificates" \
	&& apk add --no-cache --virtual .nginx-rundeps $runDeps \
	&& apk del .build-deps \
	&& apk del .gettext \
	&& mv /tmp/envsubst /usr/local/bin/

RUN \
	# forward request and error logs to docker log collector
	ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

# clean
RUN \
	rm -rf /tmp/*

COPY nginx.conf /etc/nginx/nginx.conf

LABEL description="Nginx Docker Build with BoringSSL" \
      maintainer="Custom Auto Build" \
      openssl="BoringSSL (${BORINGSSL_COMMIT_ID})" \
      nginx="Nginx (${NGINX_VERSION})"

# 定义容器暴露的端口
# EXPOSE 80 443

# 挂载 NGINX 配置和站点目录
VOLUME /etc/nginx/conf.d /etc/nginx/stream.d

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
