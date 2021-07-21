- mysql备份上传到腾讯cos注意事项
```
#!/bin/bash
export LANG=en_US.utf8

echo "================ 进入cos备份脚本，上传备案文件到cos开始 =================" >> /var/log/backup.log

#cur_dir=$(cd `dirname $0`;pwd)
cur_dir="/opt/cron/cos_migrate_tool_v5-1.4.5"
cd ${cur_dir}
cp_path=${cur_dir}/src/main/resources:${cur_dir}/dep/*

#java -Dfile.encoding=UTF-8 $@ -cp "$cp_path" com.qcloud.cos_migrate_tool.app.App
/usr/local/jdk1.8.0_281/bin/java -Dfile.encoding=UTF-8 $@ -cp "$cp_path" com.qcloud.cos_migrate_tool.app.App

echo "================ 进入cos备份脚本，上传备案文件到cos完成 =================" >> /var/log/backup.log
```
