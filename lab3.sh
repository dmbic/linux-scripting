#!/bin/bash


# Check if running as root
if [ "$EUID" -ne 0 ]; then
    exec sudo "$0" "$@"  # Re-run this script with sudo
fi

# Install curl if not already installed

if ! command -v curl &> /dev/null; then
    echo "Installing Curl..."
    apt-get update
    apt-get install curl -y
fi


# ---------------------------

# Configure Server 1

echo "Changing system name to loghost..."
hostnamectl set-hostname loghost

echo "Changing IP address to host number 3 on the LAN..."
ip addr add 172.16.1.3/24 dev eth0

echo "Adding webhost entry to /etc/hosts..."
echo "172.16.1.4 webhost" >> /etc/hosts

echo "Installing ufw if necessary and allowing connections to port 514/udp..."
apt update
apt install ufw -y
ufw allow 514/udp

echo "Configuring rsyslog to listen for UDP connections..."
sed -i '/^#module(load="imudp")$/s/^#//' /etc/rsyslog.conf
sed -i '/^#input(type="imudp" port="514")$/s/^#//' /etc/rsyslog.conf
systemctl restart rsyslog

echo "Server1 configuration complete."


# -----------------------

# Configure server2


echo "Changing system name to webhost..."
hostnamectl set-hostname webhost

echo "Changing IP address to host number 4 on the LAN..."
ip addr add 172.16.1.4/24 dev eth0

echo "Adding loghost entry to /etc/hosts..."
echo "172.16.1.3 loghost" >> /etc/hosts

echo "Installing ufw if necessary and allowing connections to port 80/tcp..."
apt update
apt install ufw -y
ufw allow 80/tcp

echo "Installing apache2..."
apt install apache2 -y

echo "Configuring rsyslog to send logs to loghost..."
echo "*.* @loghost" >> /etc/rsyslog.conf
systemctl restart rsyslog

echo "Server2 configuration complete."

# -----------------------

# Transfer and run server1_config.sh on server1
scp server1_config.sh remoteadmin@172.16.1.10:/tmp/
ssh remoteadmin@172.16.1.10 'bash /tmp/server1_config.sh' > server1_report.txt

# Transfer and run server2_config.sh on server2
scp server2_config.sh remoteadmin@172.16.1.11:/tmp/
ssh remoteadmin@172.16.1.11 'bash /tmp/server2_config.sh' > server2_report.txt

# Update /etc/hosts on NMS
echo "Updating NMS /etc/hosts..."
sed -i '/^172.16.1.3 loghost$/d' /etc/hosts
sed -i '/^172.16.1.4 webhost$/d' /etc/hosts
echo "172.16.1.3 loghost" >> /etc/hosts
echo "172.16.1.4 webhost" >> /etc/hosts

# Verify Apache and syslog configurations
curl http://webhost > apache_test.txt
ssh remoteadmin@loghost grep webhost /var/log/syslog > syslog_test.txt

# Check results and display messages
if [ $? -eq 0 ] && [ -s apache_test.txt ] && [ -s syslog_test.txt ]; then
    echo "Configuration update succeeded!"
else
    echo "Configuration update encountered issues."
    echo "Check apache_test.txt and syslog_test.txt for details."
fi

# Clean up temporary files
rm apache_test.txt syslog_test.txt

