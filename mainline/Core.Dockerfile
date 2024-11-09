ARG NGINX_VERSION
ARG BORINGSSL_COMMIT_ID
ARG DOCKERHUB_USERNAME

FROM ${DOCKERHUB_USERNAME}/nginx:${NGINX_VERSION}${BORINGSSL_COMMIT_ID}base-boringssl as builder

# 生产阶段
FROM alpine:latest

# 安装运行时依赖
RUN \
    apk update && \
    apk upgrade && \
    apk add --no-cache \
    tzdata \
    ca-certificates

# 配置环境变量和工作目录
WORKDIR /etc/nginx

# 复制文件：从构建阶段复制编译好的二进制文件、配置文件、模块等
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /usr/lib/nginx/modules /usr/lib/nginx/modules
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /var/log/nginx /var/log/nginx

# 依赖列表 base
COPY --from=builder /usr/lib/libpcre.so* /usr/lib/
COPY --from=builder /usr/lib/libstdc++.so* /usr/lib/
COPY --from=builder /usr/lib/libgcc_s.so* /usr/lib/

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
# COPY --from=builder /usr/lib/libxml2.so* /usr/lib/
# COPY --from=builder /usr/lib/libxslt.so* /usr/lib/
# COPY --from=builder /usr/lib/libexslt.so* /usr/lib/
# COPY --from=builder /usr/lib/liblzma.so* /usr/lib/
# COPY --from=builder /usr/lib/libgcrypt.so* /usr/lib/
# COPY --from=builder /usr/lib/libgpg-error.so* /usr/lib/
# /usr/lib/libxslt-plugins

# 创建 nginx 用户
# 将 NGINX 运行日志指向 Docker 日志收集系统
RUN \
    addgroup -S nginx \
    && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# 拷贝自定义的 NGINX 配置文件
COPY --from=builder /etc/nginx/nginx.conf /etc/nginx/nginx.conf

# 定义容器暴露的端口
# EXPOSE 80 443

# 挂载 NGINX 配置和站点目录
VOLUME /etc/nginx/conf.d /etc/nginx/stream.d

# 设置容器启动命令
CMD ["nginx", "-g", "daemon off;"]
