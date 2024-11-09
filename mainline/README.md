# fork src
[docker-nginx-boringssl](https://github.com/nginx-modules/docker-nginx-boringssl)

# 链接器切换

### 异常信息

```
./configure: error: SSL modules require the OpenSSL library.
You can either do not enable the modules, or install the OpenSSL library
into the system, or build the OpenSSL library statically from the source
with Angie by using --with-openssl=<path> option.
```

### 原因

[boringssl-commit-c528061](https://github.com/google/boringssl/commit/c52806157c97105da7fdc2b021d0a0fcd5186bf3)

```
libssl now requires a C++ runtime, in addition to the
pre-existing C++ requirement. Contact the BoringSSL team if this
causes an issue. Some projects may need to switch the final link to
use a C++ linker rather than a C linker.

除了预先存在的 C++ 要求外，libssl 现在还需要 C++ 运行时。
某些项目可能需要切换最终链接以使用 C++ 链接器而不是 C 链接器。
```

### 解决办法

[nginx-ticket-2605](https://trac.nginx.org/nginx/ticket/2605)

```
./configure \
	--with-cc-opt="-I/usr/src/boringssl/include" \
	--with-ld-opt="-L/usr/src/boringssl/build/ssl -L/usr/src/boringssl/build/crypto"
```

修改为：

```
./configure \
	--with-cc=c++ \
	--with-cc-opt="-I/usr/src/boringssl/include -x c" \
	--with-ld-opt="-L/usr/src/boringssl/build/ssl -L/usr/src/boringssl/build/crypto"
```
