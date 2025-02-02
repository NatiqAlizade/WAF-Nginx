#!/bin/bash

mkdir /root/Modsecurity && cd /root/Modsecurity

wget https://github.com/SpiderLabs/ModSecurity/releases/download/v3.0.8/modsecurity-v3.0.8.tar.gz

tar -xvzf modsecurity-v3.0.8.tar.gz

cd modsecurity-v3.0.8
./build.sh
./configure

make
make install

mkdir /root/Nginx && cd /root/Nginx
git clone https://github.com/SpiderLabs/ModSecurity-nginx.git

wget https://nginx.org/download/nginx-1.27.3.tar.gz
tar xzf nginx-1.27.3.tar.gz

useradd -r -M -s /sbin/nologin -d /usr/local/nginx nginx

cd nginx-1.27.3
./configure --user=nginx --group=nginx --with-pcre-jit --with-debug --with-compat --with-http_ssl_module --with-http_realip_module --add-dynamic-module=/root/Nginx/ModSecurity-nginx --http-log-path=/var/log/nginx/access.log --error-log-path=/var/log/nginx/error.log

make
make modules
make install

ln -s /usr/local/nginx/sbin/nginx /usr/local/sbin/
nginx -V

cp /root/Modsecurity/modsecurity-v3.0.8/modsecurity.conf-recommended /usr/local/nginx/conf/modsecurity.conf

cp /root/Modsecurity/modsecurity-v3.0.8/unicode.mapping /usr/local/nginx/conf/

cd /root && mkdir nginx-backup

cp /usr/local/nginx/conf/nginx.conf /root/nginx-backup/

printf 'load_module modules/ngx_http_modsecurity_module.so;
user  nginx;
worker_processes  1;
pid        /run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    server {
        listen       80;
        server_name  nginx.example.com;
        modsecurity  on;
        modsecurity_rules_file  /usr/local/nginx/conf/modsecurity.conf;
        access_log  /var/log/nginx/access_example.log;
        error_log  /var/log/nginx/error_example.log;
        location / {
            root   html;
            index  index.html index.htm;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }                                                                                                                                                      
}'>/usr/local/nginx/conf/nginx.conf

sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /usr/local/nginx/conf/modsecurity.conf

git clone https://github.com/SpiderLabs/owasp-modsecurity-crs.git /usr/local/nginx/conf/owasp-crs

cd /usr/local/nginx/conf/owasp-crs
cp /usr/local/nginx/conf/owasp-crs/crs-setup.conf{.example,}
cd .. && echo -e "Include owasp-crs/crs-setup.conf
Include owasp-crs/rules/*.conf" >> /usr/local/nginx/conf/modsecurity.conf
configuration="[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t -q -g 'daemon on; master_process on;'
ExecStart=/usr/local/nginx/sbin/nginx -g 'daemon on; master_process on;'
ExecReload=/usr/local/nginx/sbin/nginx -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
"
echo "$configuration">/etc/systemd/system/nginx.service

rm /usr/local/nginx/conf/owasp-crs/rules/REQUEST-910-IP-REPUTATION.conf
systemctl daemon-reload
systemctl start nginx
systemctl enable nginx

curl localhost?doc=/bin/ls
tail /var/log/modsec_audit.log
