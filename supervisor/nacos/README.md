### 修改startup.sh
- 将进程后端启动改为前台启动
将
```
#nohup $JAVA ${JAVA_OPT} nacos.nacos >> ${BASE_DIR}/logs/start.out 2>&1 &
```
修改:
```
$JAVA ${JAVA_OPT} nacos.nacos >> ${BASE_DIR}/logs/start.out 2>&1
```
