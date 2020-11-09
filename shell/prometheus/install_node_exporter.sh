#!/bin/bash

usr=deploy
grp=deploy

INST_DIR="/opt"
NODE_EXPORTER_APP_NAME="node_exporter-1.0.1.linux-amd64.tar.gz"
NODE_EXPORTER_APP_BASE_NAME="${NODE_EXPORTER_APP_NAME%.tar*}"
CONSUL_SERVER="10.10.11.62:8500"
STATIC_RESOURCE_SRV="10.10.11.64:9999"

HOST_IP=`ifconfig $(route | awk 'NR==3 {print}' | awk '{print $NF}') | grep -w inet | awk '{print $2}'`

install_depens_pkg() {
    yum install -y net-tools wget vim
}


install_node_exporter() {
    [ ! -d "${INST_DIR}/src" ] && mkdir -p ${INST_DIR}/src
    cd ${INST_DIR}/src
    wget http://${STATIC_RESOURCE_SRV}/exporter/${NODE_EXPORTER_APP_NAME}
    tar xf ${NODE_EXPORTER_APP_NAME} -C ${INST_DIR}
    #cd /opt/node_exporter-1.0.1.linux-amd64/
}


add_group() {
    local grp=$1

    if ! getent group ${grp}; then
        sudo groupadd ${grp}
    fi
}

add_user() {
    local usr=$1
    local grp=$2

    if ! getent passwd ${usr}; then
        sudo useradd -g ${grp} -m -s /bin/bash ${usr}
    fi
}

#add_group ${grp}
#add_user ${usr} ${grp}


install_pip() {
    yum -y install epel-release
    yum makecache
    [ ! -d ~/.pip ] && mkdir ~/.pip

    cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://pypi.doubanio.com/simple/
trusted-host = pypi.doubanio.com
EOF

    sudo yum -y install python-pip
}



install_supervisord() {
    install_pip
    sudo pip install supervisor
    [ ! -d /etc/supervisor/config.d ] && sudo mkdir -p /etc/supervisor/config.d
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
}


generate_node_supervisor_config() {
    sudo cat > /etc/supervisor/config.d/node-exporter.ini << EOF
[program:node-exporter]
command=${INST_DIR}/${NODE_EXPORTER_APP_BASE_NAME}/node_exporter
#command=/opt/node_exporter-1.0.1.linux-amd64/node_exporter
#directory=/opt/worker/
autostart=true
rutorestart=true
startsecs=5
user=root
stderr_logfile=${INST_DIR}/${NODE_EXPORTER_APP_BASE_NAME}/node_exporter.log
stdout_logfile=${INST_DIR}/${NODE_EXPORTER_APP_BASE_NAME}/node_exporter.log
EOF
}


#sudo chown -R deploy:deploy /opt/worker
#sudo chown -R deploy:deploy /etc/supervisor

start_service() {
    if ps -ef|grep -w supervisord | grep -v grep &> /dev/null; then
        supervisorctl update
        sleep 6
        supervisorctl status
    #echo "Start supervisor service"
    #sudo systemctl start supervisord
    #sudo systemctl status supervisord
    else
        sudo systemctl start supervisord
        sudo systemctl enable supervisord
        sudo systemctl status supervisord
    fi
}


generate_register_file() {
cat > ${INST_DIR}/${NODE_EXPORTER_APP_BASE_NAME}/nodepush.json << EOF
{
  "ID": "node-${HOST_IP}",
  "Name": "node-${HOST_IP}",
  "Tags": [
    "node-default"
  ],
  "Address": "${HOST_IP}",
  "Port": 9100,
  "Meta": {
    "instance": "node-${HOST_IP}",
    "role": "node-${HOST_IP}"
  },
  "EnableTagOverride": false,
  "Check": {
    "HTTP": "http://${HOST_IP}:9100/metrics",
    "Interval": "10s"
  },
  "Weights": {
    "Passing": 10,
    "Warning": 1
  }
}
EOF
}

register_to_consul() {
    curl -X PUT --data @${INST_DIR}/${NODE_EXPORTER_APP_BASE_NAME}/nodepush.json http://${CONSUL_SERVER}/v1/agent/service/register
}



# ##### main
install_depens_pkg

if [ ! -d ${INST_DIR}/${NODE_EXPORTER_APP_BASE_NAME} ]; then
    install_node_exporter
fi

if [ ! -d /etc/supervisor ]; then
    install_supervisord
    generate_node_supervisor_config
else
    generate_node_supervisor_config
fi

start_service
generate_register_file
register_to_consul



