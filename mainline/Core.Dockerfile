ARG BASE_IMAGE="debian:bookworm-slim"

FROM ${BASE_IMAGE} AS builder

# 依赖列表
# find /usr/lib/nginx/modules -type f -exec ldd {} \;
# find /usr/lib/nginx/modules -type f -exec sh extract-libs.sh {} /deps \;

# 提取 ELF 依赖到 /deps，避免重复复制
COPY extract-libs.sh /extract-libs.sh
COPY exclude-libs.txt /exclude-libs.txt
COPY extract-perl-modules.sh /extract-perl-modules.sh

RUN set -eux; \
	chmod +x /extract-libs.sh; \
	chmod +x /extract-perl-modules.sh; \
	mkdir -p /deps; \
	### 主程序
	EXCLUDE_FILE=/exclude-libs.txt /extract-libs.sh /usr/sbin/nginx /deps; \
	### module
	# EXCLUDE_FILE=/exclude-libs.txt /extract-libs.sh /usr/lib/nginx/modules/ngx_mail_module.so /deps; \
	EXCLUDE_FILE=/exclude-libs.txt /extract-libs.sh /usr/lib/nginx/modules/ngx_http_brotli_static_module.so /deps; \
	# EXCLUDE_FILE=/exclude-libs.txt /extract-libs.sh /usr/lib/nginx/modules/ngx_http_brotli_filter_module.so /deps; \
	# EXCLUDE_FILE=/exclude-libs.txt /extract-libs.sh /usr/lib/nginx/modules/ngx_http_headers_more_filter_module.so /deps; \
	# EXCLUDE_FILE=/exclude-libs.txt /extract-libs.sh /usr/lib/nginx/modules/ngx_http_xslt_filter_module.so /deps; \
	# EXCLUDE_FILE=/exclude-libs.txt /extract-libs.sh /usr/lib/nginx/modules/ngx_http_geoip_module.so /deps; \
	# EXCLUDE_FILE=/exclude-libs.txt /extract-libs.sh /usr/lib/nginx/modules/ngx_stream_geoip_module.so /deps; \
	# EXCLUDE_FILE=/exclude-libs.txt /extract-libs.sh /usr/lib/nginx/modules/ngx_http_js_module.so /deps; \
	# EXCLUDE_FILE=/exclude-libs.txt /extract-libs.sh /usr/lib/nginx/modules/ngx_stream_js_module.so /deps; \
	### 【ngx_http_image_filter_module依赖非常多】
	# EXCLUDE_FILE=/exclude-libs.txt /extract-libs.sh /usr/lib/nginx/modules/ngx_http_image_filter_module.so /deps; \
	### 【ngx_http_perl_module需要额外依赖库】
	# EXCLUDE_FILE=/exclude-libs.txt /extract-libs.sh /usr/lib/nginx/modules/ngx_http_perl_module.so /deps; \
	# EXTRA_DIRS="/usr/lib/perl5/vendor_perl" /extract-perl-modules.sh /deps; \
	ls /deps/usr/sbin/nginx; \
	ls /deps/usr/lib/nginx/modules/;

# 生产阶段
FROM debian:bookworm-slim

ARG NGINX_COMMIT_ID="HEAD~0"
ARG BORINGSSL_COMMIT_ID="HEAD~0"

# 安装运行时依赖
RUN set -eux; \
	###【alpine】
	# addgroup -S nginx; \
	# adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx; \
	###【Debian/Ubuntu】
	groupadd -r nginx; \
	useradd -r -g nginx -s /sbin/nologin -d /var/cache/nginx nginx; \
	mkdir -p /var/cache/nginx; \
	chown -R nginx:nginx /var/cache/nginx; \
	apt-get update; \
	DEBIAN_FRONTEND=noninteractive \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		tzdata \
		; \
	apt-get clean; \
	rm -rf /tmp/* /var/lib/apt/lists/*;

# 配置环境变量和工作目录
WORKDIR /etc/nginx

# 复制从构建阶段复制编译好的可执行文件、模块及其依赖等
COPY --from=builder /deps/. /

# 复制配置文件
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /var/log/nginx /var/log/nginx
COPY --from=builder /usr/share/nginx /usr/share/nginx

# 拷贝自定义的 NGINX 配置文件
# COPY --from=builder /etc/nginx/nginx.conf /etc/nginx/nginx.conf
# COPY --from=builder /etc/nginx/start.sh /etc/nginx/start.sh
COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh /etc/nginx/start.sh

ENV LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:/usr/boringssl/lib"

LABEL description="Nginx Docker Build with BoringSSL" \
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
