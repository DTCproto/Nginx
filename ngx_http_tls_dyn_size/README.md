# fork src

[ngx_http_tls_dyn_size](https://github.com/nginx-modules/ngx_http_tls_dyn_size)

# 测试说明：

[参考：cloudflare blog](https://blog.cloudflare.com/optimizing-tls-over-tcp-to-reduce-latency/)

[参考：reddit blog](https://www.reddit.com/r/nginx/comments/4ng82l/new_cloudflare_nginx_patch_optimizing_tls_over/)

### 测试结果：

```TEXT
该补丁并未生效
```

```TEXT
Nginx(1.27.2)+BoringSSL(0.20241024.0)
```

##### 测试命令：

```SHELL
curl -4 -o /dev/null -w "Connect: %{time_connect} Start Transfer: %{time_starttransfer} Total time: %{time_total} \n" -s https://www.simple.com:443
```
