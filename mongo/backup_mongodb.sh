#!/bin/bash

timestamp=$(date +%04Y%02m%02d%02H%02M)
BackupLocation="/opt/cron/backup"

MONGO_HOST="10.10.11.xx"
MONGO_PORT="37017"
MONGO_USER="mongo"
MONGO_PASSWD="mongo"
AUTH_DB="myapp"
BACKUP_DB="myapp"

BACKUP_REMOTE_SERVER="10.10.52.xx"
BACKUP_REMOTE_PATH="/data/mongo_bak"

CompressExtName="bz2"

RESERVE_DAYS=5

dumpdb() {
    /opt/mongodb-linux-x86_64-rhel70-4.2.2/bin/mongodump -h ${MONGO_HOST} --port ${MONGO_PORT} -u ${MONGO_USER} -p "${MONGO_PASSWD}" --authenticationDatabase=${AUTH_DB} -d ${BACKUP_DB} -o "${BackupLocation}"
}


compressFile() {
        tar -cjvf "$1_${timestamp}.$CompressExtName" $1
}


enterWorkspace() {
        cd ${BackupLocation}
}

deletePlainDumpout() {
        rm -rf ${BackupLocation}/${BACKUP_DB}
}

scpFileDump() {
    scp "${BackupLocation}/${BACKUP_DB}_${timestamp}.${CompressExtName}" "${BACKUP_REMOTE_SERVER}:${BACKUP_REMOTE_PATH}"
}

clean_old_data() {
    find ${BackupLocation} -name "${BACKUP_DB}_*.bz2" -type f -mtime +${RESERVE_DAYS} -exec rm {} \; > /dev/null 2>&1
}


main() {
        enterWorkspace
        dumpdb
        compressFile ${BACKUP_DB}
        deletePlainDumpout
        scpFileDump
        
        clean_old_data
}

main














