FROM mizzy/centos-4.8-i386:latest

RUN yum makecache
RUN yum -y install gcc automake libtool make pkgconfig rpm-build zlib-devel

#
# OpenSSL 1.0.1u (for TLS 1.1/1.2 support)
#
COPY openssl/openssl-1.0.1u.tar.gz /tmp/

RUN cd /tmp \
 && tar xzvf openssl-1.0.1u.tar.gz \
 && cd openssl-1.0.1u/ \
 && /usr/bin/perl ./Configure linux-elf -Wa,--noexecstack --prefix=/opt/openssl-1.0.1u --openssldir=/opt/openssl-1.0.1u shared zlib-dynamic \
 && make depend \
 && make \
 && make install

RUN echo '/opt/openssl-1.0.1u/lib' > /etc/ld.so.conf.d/openssl.conf \
 && ldconfig \
 && echo 'export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/opt/openssl-1.0.1u/lib/pkgconfig' > /etc/profile.d/pkgconfig.sh \
 && source /etc/profile.d/pkgconfig.sh

#
# cURL 7.62.0
#
# @ https://support.shopgate.com/hc/en-us/articles/115006896288-How-do-I-upgrade-my-SSL-library-to-support-TLS-1-2-#3.1
# "...you need to have at least cURL version 7.34.0 in order to support TLS 1.2"
#
COPY curl/curl-7.62.0.tar.gz /tmp/

RUN cd /tmp \
 && tar xzvf curl-7.62.0.tar.gz \
 && cd curl-7.62.0/ \
 && LDFLAGS="-L/opt/openssl-1.0.1u/lib" \
    CPPFLAGS="-I/opt/openssl-1.0.1u/include" \
    CXXFLAGS=$CPPFLAGS \
    CFLAGS=$CPPFLAGS \
    LIBS="-lssl -lcrypto" \
    ./configure --prefix=/opt/curl-7.62.0 \
 && make \
 && make install

RUN ln -s /opt/curl-7.62.0/bin/curl /usr/local/bin/curl

#
# nginx 1.14.1
#
COPY nginx/nginx-1.14.1.tar.gz /tmp/
ADD nginx/ngx_http_substitutions_filter_module.tar.gz /tmp/

RUN yum -y install pcre-devel

RUN useradd -u 1000 -m appadm

RUN cd /tmp \
 && tar xzvf nginx-1.14.1.tar.gz \
 && cd nginx-1.14.1/ \
 && ./configure \
    --prefix=/opt/nginx-1.14.1 \
    --user=appadm \
    --group=appadm \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --with-compat \
    --with-debug \
    --with-threads \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-pcre \
    --with-stream \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-openssl=/tmp/openssl-1.0.1u \
    --add-module=/tmp/ngx_http_substitutions_filter_module

# @ https://stackoverflow.com/a/36363668
RUN cd /tmp/nginx-1.14.1/ \
 && sed -i 's/.\/config/MACHINE=i686 \.\/config \-m32/' objs/Makefile \
 && make \
 && make install

COPY nginx/nginx.conf /etc/nginx/

RUN mkdir /etc/nginx/ssl/
COPY nginx/ssl/* /etc/nginx/ssl/

RUN ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 8080 8443

STOPSIGNAL SIGTERM

# CMD ["/bin/bash"]
CMD ["nginx", "-g", "daemon off;"]