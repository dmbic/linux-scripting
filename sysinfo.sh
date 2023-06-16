#!/bin/bash

# System Information
MyHostName=$(hostname)
MyOS=$(source /etc/os-release && echo "$PRETTY_NAME")
UpTime=$(uptime -p)

# Hardware Information


cpu=$(lshw -class processor | awk '/product/ {print $2, $3, $4, $5, $6, $7, $8, $9}')
cpu_speed=$(lshw -class processor | awk '/size/ {print $1, $2, $3, $4}')
max_cpu_speed=$(lshw -class processor | awk '/capabilities/ {print $3}' | sed 's/,//')
ram=$(free -h | awk '/Mem:/ {print $2}')
disks=$(lsblk -o NAME,SIZE,MODEL | awk '$1 ~ /sd/ {print $2, $3}')
video=$(lshw -class display | awk '/product/ {print $2, $3}')

# Network Information
fqdn=$(hostname -f)
host_address=$(ip a | awk '/inet / && !/127.0.0.1/ {split($2, a, "/"); print a[1]}')
gateway_ip=$(ip r | awk '/default/ {print $3}')
dns_server=$(grep 'nameserver' /etc/resolv.conf | awk '{print $2}')
interface=$(lshw -class network | awk '/logical name/ {print $3}' | head -n 1)
ip_address=$(ip a show "$interface" | awk '/inet / {split($2, a, "/"); print a[1]}')

# System Status
users=$(who | cut -d' ' -f1 | sort -u | paste -s -d',')
disk_space=$(df -h | awk '{print $1, $4}' | sed -n '2,$p')
process_count=$(ps -e | wc -l)
load_averages=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1, $2, $3}')
memory_allocation=$(free -h | awk '/Mem:/ {print "Total:", $2, "Used:", $3, "Free:", $4}')
listening_ports=$(ss -tln | awk 'NR>1 {print $5}' | awk -F':' '{print $NF}' | sort -u | paste -s -d',')
ufw_rules=$(sudo ufw status numbered)

# Generate Report
echo "
System Report generated by $USER, $(date +'%Y-%m-%d %H:%M:%S')

System Information
-------------------
Hostname: $MyHostName
OS: $MyOS
Uptime: $UpTime

Hardware Information
----------------------
CPU: $cpu
Speed: $cpu_speed (Max: $max_cpu_speed)
RAM: $ram
Disks: $disks
Video: $video

Network Information
---------------------
FQDN: $fqdn
Host Address: $host_address
Gateway IP: $gateway_ip
DNS Server: $dns_server

Interface: $interface
IP Address: $ip_address

System Status
--------------
Users Logged In: $users
Disk Space: $disk_space
Process Count: $process_count
Load Averages: $load_averages
Memory Allocation: $memory_allocation
Listening Network Ports: $listening_ports
UFW Rules: $ufw_rules
"

