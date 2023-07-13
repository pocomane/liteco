#!/bin/sh

cat << EOF > /etc/systemd/system/liteco.service
[Unit]
Description=Lightweight container control

[Service]
ExecStart=/opt/sandbox/startall.sh
ExecStop=/opt/sandbox/liteco.sh stop all
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

