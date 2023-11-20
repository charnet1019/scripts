# 使用shc加密shell脚本  
> shc -r -f analyze_big_keys.sh -o analyze_big_keys  

[shc仓库](https://github.com/neurobin/shc)


# es备份
elasticdump --concurrency=4 --limit=2000 --input=http://10.0.0.49:9200/order --output=order.json --type=data
# es还原
elasticdump --output=http://127.0.0.1:9200/order --type=data --input=order.json




# CentOS  

```bash
mac_list=""
ip_list=""

release_version=$(cat /etc/centos-release 2>/dev/null)
pkgs=$($(which rpm 2>/dev/null) -qa --qf "%{NAME} %{VERSION}-%{RELEASE} %{ARCH}\n" 2>/dev/null | awk '{print "\"" $1 "\": \"" $2 "\"" ","}' 2>/dev/null)

b=$(which ifconfig 2>/dev/null)
if [[ $b != "" ]]; then
    mac_list=$(ifconfig | grep ether | awk '{print "\"" $2 "\", " }')
    ip_list=$(ifconfig | grep "inet " | awk '{print "\"" $2 "\", " }')
else
    mac_list=$(ip a | grep ether | awk '{print "\"" $2 "\", " }')
    ip_list=$(ip a | grep "inet " | awk '{print "\"" $2 "\", " }')
fi

perm_u_s=$(find / -perm -u=s -type f 2>/dev/null | awk '{print "\""  $1 "\","}' 2>/dev/null) 

echo "{\"kernel_version\": \"$(uname -r)\", \"release_version\": \"$release_version\", \"arch\": \"$(uname -m)\", \"mac_list\": [${mac_list%,*}], \"ip_list\": [${ip_list%,*}], \"pkgs\": {${pkgs%,*}}, \"perm_u_s\": [${perm_u_s%,*}]}"
```


# Windows  

```bash
systeminfo&&wmic product get name,version&&wmic nic where PhysicalAdapter=True get MACAddress,Name&&wmic NICCONFIG WHERE IPEnabled=true GET IPAddress
```

# Ubuntu  

```bash
mac_list=""
ip_list=""

release_version=$(cat /etc/os-release | grep "PRETTY_NAME=" | awk -F "=" '{ gsub(/"/,"",$2); print $2 }')
pkgs="["$($(which dpkg 2>/dev/null) --list | awk '{print "\"" $2 "\": \"" $3 "\"," }')"]"

b=$(which ifconfig 2>/dev/null)
if [[ $b != "" ]]; then
    mac_list=$(ifconfig | grep ether | awk '{print "\"" $2 "\", " }')
    ip_list=$(ifconfig | grep "inet " | awk '{print "\"" $2 "\", " }')
else
    mac_list=$(ip a | grep ether | awk '{print "\"" $2 "\", " }')
    ip_list=$(ip a | grep "inet " | awk '{print "\"" $2 "\", " }')
fi

perm_u_s=$(find / -perm -u=s -type f 2>/dev/null | awk '{print "\""  $1 "\","}' 2>/dev/null) 

echo "{\"kernel_version\": \"$(uname -r)\", \"release_version\": \"$release_version\", \"arch\": \"$(uname -m)\", \"mac_list\": [${mac_list%,*}], \"ip_list\": [${ip_list%,*}], \"pkgs\": {${pkgs%,*}}, \"perm_u_s\": [${perm_u_s%,*}]}"
```


# RedHat  

```bash
mac_list=""
ip_list=""

release_version=$(cat /etc/redhat-release 2>/dev/null)
pkgs=$($(which rpm 2>/dev/null) -qa --qf "%{NAME} %{VERSION}-%{RELEASE} %{ARCH}\n" 2>/dev/null | awk '{print "\"" $1 "\": \"" $2 "\"" ","}' 2>/dev/null)

b=$(which ifconfig 2>/dev/null)
if [[ $b != "" ]]; then
    mac_list=$(ifconfig | grep HWaddr | awk '{print "\"" $5 "\", " }')
    ip_list=$(ifconfig | grep "inet addr" | awk '{print $2}' | awk -F ":" '{print "\"" $2 "\", " }')
else
    mac_list=$(ip a | grep "ether" | awk '{print "\"" $2 "\", " }')
    ip_list=$(ip a | grep "inet " | awk '{print $2}' | awk -F "/" '{print "\"" $1 "\", " }')
fi

perm_u_s=$(find / -perm -u=s -type f 2>/dev/null | awk '{print "\""  $1 "\","}' 2>/dev/null) 

echo "{\"kernel_version\": \"$(uname -r)\", \"release_version\": \"$release_version\", \"arch\": \"$(uname -m)\", \"mac_list\": [${mac_list%,*}], \"ip_list\": [${ip_list%,*}], \"pkgs\": {${pkgs%,*}}, \"perm_u_s\": [${perm_u_s%,*}]}"
```
