ARG BASE_IMAGE="alpine:latest"

FROM ${BASE_IMAGE} AS builder

# 生产阶段
FROM alpine:latest

ARG NGINX_COMMIT_ID="HEAD~0"
ARG BORINGSSL_COMMIT_ID="HEAD~0"

# 安装运行时依赖
RUN set -eux; \
	addgroup -S nginx; \
	adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx; \
    apk add --no-cache \
    tzdata \
    ca-certificates \
    bash \
    ;

# 配置环境变量和工作目录
WORKDIR /etc/nginx

# 复制文件：从构建阶段复制编译好的二进制文件、配置文件、模块等
COPY --from=builder /usr/sbin/nginx /usr/sbin/
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /var/log/nginx /var/log/nginx
COPY --from=builder /usr/share/nginx /usr/share/nginx

COPY --from=builder /usr/lib/nginx/modules/ngx_http_brotli_static_module.so* /usr/lib/nginx/modules/
# COPY --from=builder /usr/lib/nginx/modules/ngx_http_brotli_filter_module.so* /usr/lib/nginx/modules/
COPY --from=builder /usr/lib/nginx/modules/ngx_http_headers_more_filter_module.so* /usr/lib/nginx/modules/
# COPY --from=builder /usr/lib/nginx/modules/ngx_http_xslt_filter_module.so* /usr/lib/nginx/modules/
# COPY --from=builder /usr/lib/nginx/modules/ngx_http_image_filter_module.so* /usr/lib/nginx/modules/
# COPY --from=builder /usr/lib/nginx/modules/ngx_http_geoip_module.so* /usr/lib/nginx/modules/
# COPY --from=builder /usr/lib/nginx/modules/ngx_stream_geoip_module.so* /usr/lib/nginx/modules/
# COPY --from=builder /usr/lib/nginx/modules/ngx_http_perl_module.so* /usr/lib/nginx/modules/
# COPY --from=builder /usr/lib/nginx/modules/ngx_http_js_module.so* /usr/lib/nginx/modules/
# COPY --from=builder /usr/lib/nginx/modules/ngx_stream_js_module.so* /usr/lib/nginx/modules/

# 依赖列表 base
COPY --from=builder /usr/lib/libpcre2* /usr/lib/
COPY --from=builder /usr/lib/libstdc++.so* /usr/lib/
COPY --from=builder /usr/lib/libgcc_s.so* /usr/lib/
COPY --from=builder /usr/local/lib/libssl.so* /usr/local/lib/
COPY --from=builder /usr/local/lib/libcrypto.so* /usr/local/lib/

# 依赖列表 load_module modules/ngx_http_brotli_filter_module.so;
COPY --from=builder /usr/lib/libbrotlicommon.so* /usr/lib/
COPY --from=builder /usr/lib/libbrotlienc.so* /usr/lib/
COPY --from=builder /usr/lib/libbrotlidec.so* /usr/lib/

# 依赖列表 load_module modules/ngx_http_geoip_module.so;
# 依赖列表 load_module modules/ngx_stream_geoip_module.so;
# COPY --from=builder /usr/lib/libGeoIP.so* /usr/lib/

# 依赖列表 load_module modules/ngx_http_image_filter_module.so;
# COPY --from=builder /usr/lib/libgd.so* /usr/lib/
# COPY --from=builder /usr/lib/libpng16.so* /usr/lib/
# COPY --from=builder /usr/lib/libjpeg.so* /usr/lib/
# COPY --from=builder /usr/lib/libfontconfig.so* /usr/lib/
# COPY --from=builder /usr/lib/libfreetype.so* /usr/lib/
# COPY --from=builder /usr/lib/libXpm.so* /usr/lib/
# COPY --from=builder /usr/lib/libtiff.so* /usr/lib/
# COPY --from=builder /usr/lib/libwebp.so* /usr/lib/
# COPY --from=builder /usr/lib/libavif.so* /usr/lib/
# COPY --from=builder /usr/lib/libexpat.so* /usr/lib/
# COPY --from=builder /usr/lib/libbz2.so* /usr/lib/
# COPY --from=builder /usr/lib/libzstd.so* /usr/lib/
# COPY --from=builder /usr/lib/libsharpyuv.so* /usr/lib/
# COPY --from=builder /usr/lib/libdav1d.so* /usr/lib/
# COPY --from=builder /usr/lib/libaom.so* /usr/lib/
# COPY --from=builder /usr/lib/libXau.so* /usr/lib/
# COPY --from=builder /usr/lib/libXdmcp.so* /usr/lib/
# COPY --from=builder /usr/lib/libbsd.so* /usr/lib/
# COPY --from=builder /usr/lib/libmd.so* /usr/lib/
# COPY --from=builder /usr/lib/libX11* /usr/lib/
# COPY --from=builder /usr/lib/libxcb* /usr/lib/

# 依赖列表 load_module modules/ngx_http_xslt_filter_module.so;
# 依赖列表 load_module modules/ngx_http_js_module.so modules/ngx_stream_js_module.so;
# COPY --from=builder /usr/lib/libxml2.so* /usr/lib/
# COPY --from=builder /usr/lib/libxslt.so* /usr/lib/
# COPY --from=builder /usr/lib/libexslt.so* /usr/lib/
# COPY --from=builder /usr/lib/liblzma.so* /usr/lib/
# COPY --from=builder /usr/lib/libgcrypt.so* /usr/lib/
# COPY --from=builder /usr/lib/libgpg-error.so* /usr/lib/
# /usr/lib/libxslt-plugins

# 依赖列表 load_module modules/ngx_http_perl_module.so;
# COPY --from=builder /usr/lib/perl5 /usr/lib/perl5
# COPY --from=builder /usr/share/perl5 /usr/share/perl5

# 拷贝自定义的 NGINX 配置文件
# COPY --from=builder /etc/nginx/nginx.conf /etc/nginx/nginx.conf
# COPY --from=builder /etc/nginx/start.sh /etc/nginx/start.sh
COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh /etc/nginx/start.sh

# ssl lib(警告：会导致默认的alpine包命令异常)
#RUN set -eux; \
#    rm -rf /usr/lib/libssl.so* /usr/lib/libcrypto.so*; \
#    ln -s /usr/local/lib/libssl.so /usr/lib/libssl.so; \
#    ln -s /usr/local/lib/libcrypto.so /usr/lib/libcrypto.so;

# clean
RUN set -eux; \
    # 按需减小体积
	rm -rf /tmp/* /var/cache/apk/*;

LABEL description="Nginx Docker Build with BoringSSL" \
      maintainer="Custom Auto Build" \
      openssl="BoringSSL (${BORINGSSL_COMMIT_ID})" \
      nginx="Nginx (${NGINX_COMMIT_ID})"

# 定义容器暴露的端口
# EXPOSE 80 443

# 挂载 NGINX 配置和站点目录
VOLUME /etc/nginx/http.d /etc/nginx/stream.d

STOPSIGNAL SIGTERM

# 设置容器启动命令
ENTRYPOINT ["/bin/bash", "/etc/nginx/start.sh"]

# 设置容器启动命令(ENTRYPOIN[]的默认参数)
CMD ["-g", "daemon off;"]
