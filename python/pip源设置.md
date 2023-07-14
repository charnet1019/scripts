# linux下设置pip源  
1. 在/root/.pip/下创建pip.ini
2. 配置如下

```ini
[global]
timeout=40
index-url=http://mirrors.aliyun.com/pypi/simple/
extra-index-url=
        https://pypi.tuna.tsinghua.edu.cn/simple/
        http://pypi.douban.com/simple/
        http://pypi.mirrors.ustc.edu.cn/simple/
[install]
trusted-host=
        pypi.tuna.tsinghua.edu.cn
        mirrors.aliyun.com
        pypi.douban.com
        pypi.mirrors.ustc.edu.cn
```


# windows下设置pip源  
1. 在用户目录下创建pip目录并在其下创建pip.ini
2. 配置如下

```ini
[global]
timeout=40
index-url=http://mirrors.aliyun.com/pypi/simple/
extra-index-url=
        https://pypi.tuna.tsinghua.edu.cn/simple/
        http://pypi.douban.com/simple/
        http://pypi.mirrors.ustc.edu.cn/simple/
[install]
trusted-host=
        pypi.tuna.tsinghua.edu.cn
        mirrors.aliyun.com
        pypi.douban.com
        pypi.mirrors.ustc.edu.cn
```
