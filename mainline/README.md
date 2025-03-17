# fork src
[docker-nginx-boringssl](https://github.com/nginx-modules/docker-nginx-boringssl)

# 一、链接器切换

### 异常信息

```log
./configure: error: SSL modules require the OpenSSL library.
You can either do not enable the modules, or install the OpenSSL library
into the system, or build the OpenSSL library statically from the source
with Angie by using --with-openssl=<path> option.
```

### 原因

[boringssl-commit-c528061](https://github.com/google/boringssl/commit/c52806157c97105da7fdc2b021d0a0fcd5186bf3)

```text
libssl now requires a C++ runtime, in addition to the
pre-existing C++ requirement. Contact the BoringSSL team if this
causes an issue. Some projects may need to switch the final link to
use a C++ linker rather than a C linker.

除了预先存在的 C++ 要求外，libssl 现在还需要 C++ 运行时。
某些项目可能需要切换最终链接以使用 C++ 链接器而不是 C 链接器。
```

### 解决办法

[nginx-ticket-2605](https://trac.nginx.org/nginx/ticket/2605)

```shell
./configure \
	--with-cc-opt="-I/usr/src/boringssl/include" \
	--with-ld-opt="-L/usr/src/boringssl/build/ssl -L/usr/src/boringssl/build/crypto"
```

修改为：

```shell
./configure \
	--with-cc=c++ \
	--with-cc-opt="-I/usr/src/boringssl/include -x c" \
	--with-ld-opt="-L/usr/src/boringssl/build/ssl -L/usr/src/boringssl/build/crypto"
```

# 二、QEMU binfmt指定(V8+)版本

### 异常信息

```log
[CMakeFiles/fipsmodule.dir/build.make:677: CMakeFiles/fipsmodule.dir/gen/bcm/p256-armv8-asm-apple.S.o] Segmentation fault (core dumped)
```

### 原因

[tonistiigi/binfmt issues 215](https://github.com/tonistiigi/binfmt/issues/215)

```log
tonistiigi/binfmt V7 platform=arm64 与最新的 Ubuntu24.04 不兼容
```

### 解决办法

```text
指定binfmt(V8+)版本
```

```yaml
- name: Set up QEMU
  uses: docker/setup-qemu-action@v3
```

修改为：

```yaml
- name: Set up QEMU
  uses: docker/setup-qemu-action@v3
  with:
    image: tonistiigi/binfmt:qemu-v8.1.5
```

```yaml
- name: Set up QEMU
  uses: docker/setup-qemu-action@v3
  with:
    image: tonistiigi/binfmt:qemu-v9.2.0
```

# 二、QEMU binfmt指定(V8+)版本

### 异常信息

```log
ngx_http_js_module.so RSA_get0_crt_params: symbol not found
```

### 原因

[nginx/njs issues 499](https://github.com/nginx/njs/issues/499)

```log
only njs module uses libcrypto symbols from boringssl.

只有 njs 模块使用libcrypto来自 boringssl 的符号。
```

### 解决办法

```text
by default boringssl is compiled as a static library
during nginx compilation the library is linked against nginx binary
nginx dynamic modules use symbols from the nginx binary, but a dynamic module cannot use static symbols from the binary
I see several options:
compile boringssl as shared library (using -DBUILD_SHARED_LIBS=1). Ensure that boringssl library path is available during nginx binary start (for example using LD_LIBRARY_PATH variable).
compile njs module as a built-in module (--add-module), here you may use static boringssl

默认情况下 boringssl 被编译为静态库
在 nginx 编译期间，该库与 nginx 二进制文件链接
nginx 动态模块使用 nginx 二进制文件中的符号，但动态模块不能使用二进制文件中的静态符号
我看到了几种选择：
将 boringssl 编译为共享库（使用-DBUILD_SHARED_LIBS=1）。确保 boringssl 库路径在 nginx 二进制启动期间可用（例如，使用 LD_LIBRARY_PATH 变量）。
将 njs 模块编译为内置模块（--add-module），这里可以使用 static boringssl
```