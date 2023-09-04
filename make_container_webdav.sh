#!/bin/sh
set -xe

LITECO="/opt/sandbox/liteco.sh"
USERLIST="user_one another_user"

CONTAINERPATH="$1"
shift

if [ -z "$CONTAINERPATH" ] ; then
  echo "invalid container name" 1>&2
  exit 13
fi

if [ -e "$CONTAINERPATH" ] ; then
  echo "container '$CONTAINERPATH' already exists" 1>&2
  exit 13
fi

mkdir -p "$CONTAINERPATH"

pacstrap -K "$CONTAINERPATH" pacman archlinux-keyring gzip
echo "nameserver 192.168.2.1" >> "$CONTAINERPATH"/etc/resolv.conf

$LITECO run "$CONTAINERPATH" sh << EOF
set -xe

pacman --noconfirm -S nginx-mainline nginx-mainline-src git base-devel libxslt
pacman -D --asdeps libxslt
useradd user

pacman --noconfirm -S apache # NOTE: used only for the htpasswd utility - TODO : can it be substituted?

EOF

$LITECO -u run "$CONTAINERPATH" sh << EOF
set -xe

cd tmp/
git clone https://aur.archlinux.org/nginx-mainline-mod-auth_pam.git
cd nginx-mainline-mod-auth_pam/
ls -lha /dev
makepkg
ls -lha /dev
mv *.pkg.tar.zst /opt
cd ..
git clone https://aur.archlinux.org/nginx-mainline-mod-dav-ext.git
cd nginx-mainline-mod-dav-ext/
makepkg
mv *.pkg.tar.zst /opt
cd ..

EOF

$LITECO run "$CONTAINERPATH" sh << EOF
set -xe

cd opt/
pacman --noconfirm -U *.pkg.tar.zst
rm *.pkg.tar.zst
cd ..
cp /etc/nginx.conf /etc/nginx.conf.orig
mkdir /etc/enginx/sites-enabled

EOF

$LITECO run "$CONTAINERPATH" sh << EOF
set -xe

mkdir -p /etc/nginx/access
cd /etc/nginx/access
openssl req -new -x509 -nodes -newkey rsa:4096 -keyout webdav.key -out webdav.crt -days 9999 -nodes -subj "/C=IT/ST=Italy/L=Rome/O=ACompany/OU=ADepartment/CN=webdavbox" 
chmod 400 webdav.key
chmod 444 webdav.crt

EOF

cat << 'EOF' > "$CONTAINERPATH/run.sh"
#!/bin/sh

run(){
  NAM="$1"
  shift
  $@ 2>&1 | sed 's-^-'"$NAM"': -g' &
  #$@ 2>&1 | while read line ; do printf "%s: %s" "$NAM" "$line" ; done
}

rm /etc/nginx/access/all.pwd
cat /etc/nginx/access/*.pwd > /etc/nginx/access/all.pwd
run NGINX nginx -c /etc/nginx/nginx.conf

wait -n $(jobs -p)
#sh

EOF

$LITECO run "$CONTAINERPATH" chmod ug+x "/run.sh"

$LITECO run "$CONTAINERPATH" sh << EOF
rm -f /var/cache/pacman/pkg/*
EOF

$LITECO run "$CONTAINERPATH" mkdir -p /etc/nginx/sites-enabled

echo "" > "$CONTAINERPATH/etc/nginx/nginx.conf"
echo "" > "$CONTAINERPATH/etc/nginx/sites-enabled/webdav.conf"

$LITECO run "$CONTAINERPATH" cp -f /etc/nginx/nginx.conf /etc/nginx/nginx.conf.orig
cat << EOF >> "$CONTAINERPATH/etc/nginx/nginx.conf"
user user;
worker_processes auto;
worker_cpu_affinity auto;

load_module "/usr/lib/nginx/modules/ngx_http_auth_pam_module.so";
load_module "/usr/lib/nginx/modules/ngx_http_dav_ext_module.so";

events {
  multi_accept on;
  worker_connections 1024;
}

http {
  charset utf-8;
  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  server_tokens off;
  log_not_found off;
  types_hash_max_size 4096;
  client_max_body_size 16M;

  # MIME
  include mime.types;
  default_type application/octet-stream;

  # logging
  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log warn;

  # load configs
  include /etc/nginx/conf.d/*.conf;
  include /etc/nginx/sites-enabled/*;
}

EOF

cat << EOF >> "$CONTAINERPATH/etc/nginx/sites-enabled/webdav.conf"

server {
  #listen 9123 default_server;
  #listen [::]:9123 default_server;
  listen 9123 ssl;
  listen [::]:9123 ssl;
  ssl_certificate /etc/nginx/access/webdav.crt;
  ssl_certificate_key /etc/nginx/access/webdav.key;
  root /share/;
  index index.html index.htm index.nginx-debian.html;
  server_name _;

  add_header 'Access-Control-Allow-Origin' '*' always;
  add_header 'Access-Control-Allow-Methods' '*' always;
  add_header 'Access-Control-Allow-Headers' '*' always;
  add_header 'Access-Control-Expose-Headers' '*' always;
  if (\$request_method = OPTIONS){
    return 200;
  }

  location / {
    dav_ext_methods PROPFIND OPTIONS;
    dav_access user:r group:r all:r;

    client_max_body_size 0;
    create_full_put_path on;
    client_body_temp_path /tmp/;

    auth_basic "Restricted";
    auth_basic_user_file /etc/nginx/access/all.pwd; 
  }

  location ^~ /common/ {
    dav_methods PUT DELETE MKCOL COPY MOVE;
    dav_ext_methods PROPFIND OPTIONS;
    dav_access user:rw group:rw all:rw;

    client_max_body_size 0;
    create_full_put_path on;
    client_body_temp_path /tmp/;

    auth_basic "Restricted";
    auth_basic_user_file /etc/nginx/access/all.pwd; 
  }

EOF

for USER in $USERLIST ; do
$LITECO run "$CONTAINERPATH" htpasswd -bcB /etc/nginx/access/"$USER".pwd "$USER" password
cat << EOF >> "$CONTAINERPATH/etc/nginx/sites-enabled/webdav.conf"
  location ^~ /${USER}_personal/ {
    dav_methods PUT DELETE MKCOL COPY MOVE;
    dav_ext_methods PROPFIND OPTIONS;
    dav_access user:rw group:rw all:rw;

    client_max_body_size 0;
    create_full_put_path on;
    client_body_temp_path /tmp/;

    auth_basic "Restricted";
    auth_basic_user_file /etc/nginx/access/$USER.pwd;
  }

EOF
echo "ATTENTION ! WEBDAV IS CONFIGURED WITH AN INSECURE PASSWORD - CHANGE IT AS SOON AS YOU CAN ! WITH ./liteco.sh "$CONTAINERPATH" htpasswd -B '/etc/nginx/$USER.pwd' '$USER'"
done

cat << EOF >> "$CONTAINERPATH/etc/nginx/sites-enabled/webdav.conf"
  location ~ ^/[^/]+/ {
    deny all;
  }
}

EOF

