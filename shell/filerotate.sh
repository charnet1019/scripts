#!/bin/bash

RESERVE_NUM=4

NEED_ROTATE_DIRS="
/data/backup/mysql/10_100_10_x
/data/backup/mysql/10_100_10_x
/data/backup/mysql/10_100_10_x
"

# 保留指定数目的目录数量
reserved_backup_dir() {
    local NUM=$1             # 保留目录个数
    local DIR=$2             # 备份目录

    [ -d $DIR ] || exit 

    FileNum=$(ls -l ${DIR} | grep "^d" | wc -l)
    while(($FileNum > $NUM)); do 
        OldDir=$(ls -lrt ${DIR} | grep "^d" | awk 'NR==1 {print $NF}')
        echo 'Delete File: '$OldDir
        rm -rf ${DIR}/${OldDir}
        let FileNum--
    done
    #exit
}

# 保留指定数目的文件数量
reserved_backup_file() {
    local NUM=$1             # 保留文件个数
    local DIR=$2             # 备份目录

    [ -d $DIR ] || exit 

    FileNum=$(ls -l ${DIR} | grep "^-" | wc -l)
    while(($FileNum > $NUM)); do 
        OldFile=$(ls -lrt ${DIR} | grep "^-" | awk 'NR==1 {print $NF}')
        echo 'Delete File: '$OldFile
        rm -rf ${DIR}/${OldFile}
        let FileNum--
    done
    #exit
}



for d in ${NEED_ROTATE_DIRS}; do
    reserved_backup_dir "${RESERVE_NUM}" "${d}"
    reserved_backup_file "${RESERVE_NUM}" "${d}"
done


