#!/bin/bash

usr=deploy
grp=deploy

add_group() {
    local grp=$1

    if ! getent group ${grp}; then
        sudo groupadd -r ${grp}
    fi
}

add_user() {
    local usr=$1
    local grp=$2

    if ! getent passwd ${usr}; then
        sudo useradd -g ${grp} -r -m -s /bin/bash ${usr}
    fi
}

add_group ${grp}
add_user ${usr} ${grp}

sudo yum -y install epel-release
sudo yum makecache

sudo yum -y install python-pip
sudo pip install supervisor

sudo mkdir -p /etc/supervisor/config.d

sudo cat > /etc/supervisor/supervisord.conf << 'EOF'
[unix_http_server]
file=/tmp/supervisor.sock   ; the path to the socket file
[supervisord]
logfile=/tmp/supervisord.log ; main log file; default $CWD/supervisord.log
logfile_maxbytes=50MB        ; max main logfile bytes b4 rotation; default 50MB
logfile_backups=10           ; # of main logfile backups; 0 means none, default 10
loglevel=info                ; log level; default info; others: debug,warn,trace
pidfile=/tmp/supervisord.pid ; supervisord pidfile; default supervisord.pid
nodaemon=false               ; start in foreground if true; default false
silent=false                 ; no logs to stdout if true; default false
minfds=100000 ; min. avail startup file descriptors; default 1024
minprocs=200                 ; min. avail process descriptors;default 200
[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface
[supervisorctl]
serverurl=unix:///tmp/supervisor.sock ; use a unix:// URL  for a unix socket
[include]
files = /etc/supervisor/config.d/*.ini
EOF

sudo cat > /etc/supervisor/config.d/frontend.ini << EOF
[program:frontend]
command=/usr/local/bin/npm run start
directory=/data/myapp/
autostart=true
rutorestart=true
startsecs=5
user=deploy
stderr_logfile=/var/log/myqpp/frontend.log
stdout_logfile=/var/log/myapp/frontend.log
EOF

sudo cat > /usr/lib/systemd/system/supervisord.service << 'EOF'
[Unit]
Description=Supervisor process control system for UNIX
Documentation=http://supervisord.org
After=network.target

[Service]
ExecStart=/usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
ExecStop=/usr/bin/supervisorctl $OPTIONS shutdown
ExecReload=/usr/bin/supervisorctl -c /etc/supervisor/supervisord.conf $OPTIONS reload
KillMode=process
Restart=on-failure
RestartSec=50s
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

sudo chown -R deploy:deploy /data/myapp/
sudo chown -R deploy:deploy /etc/supervisor

echo "Start supervisor service"
sudo systemctl start supervisord
sudo systemctl status supervisord

