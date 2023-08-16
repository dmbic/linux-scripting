#!/bin/bash

# Checking for and updating hostname and keeping the user informed of what is happening
new_hostname="autosrv"
current_hostname=$(hostname)

if [ "$current_hostname" != "$new_hostname" ]; then
    echo "Changing hostname to '$new_hostname'..."
    sudo hostnamectl set-hostname "$new_hostname"
    echo "Hostname changed."

    # Update /etc/hosts with the new hostname
    echo "127.0.0.1 localhost" | sudo tee /etc/hosts
    echo "127.0.1.1 $new_hostname" | sudo tee -a /etc/hosts
else
    echo "Hostname is already set to '$new_hostname'."
fi

echo "Starting system configuration..."

# Identify the internet-connected interface
internet_interface=$(ip r | awk '/^default/ {print $5}')
echo "Internet-connected interface: $internet_interface"

# Identify any non-internet connected interface(s)
non_internet_interfaces=$(ip addr show | awk '/^[a-zA-Z]+[0-9]*:/ && !/lo|'"$internet_interface"'/ {gsub(/:$/,""); print $2}')

# Use a for loop to configure them to a static address and ohter nework configurations
for interface in $non_internet_interfaces; do
    echo "Configuring static network for interface $interface..."

    # Set static IP address and gateway
    sudo ip addr add 192.168.16.21/24 dev "$interface"
    sudo ip route add default via 192.168.16.1 dev "$interface"

    # Set DNS servers and search domains using resolv.conf
    echo "nameserver 192.168.16.1" | sudo tee /etc/resolv.conf
    echo "search home.arpa localdomain" | sudo tee -a /etc/resolv.conf

    echo "Network configuration for $interface is set to static."
done

echo "System configuration complete"


# Install SSH

echo "Installing SSH..."
sudo apt-get update
sudo apt-get install -y openssh-server

# set password authentication to no
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Install Apache2

echo "Installing Apache..."
sudo apt-get install -y apache2

# Enable SSL modules
sudo a2enmod ssl

# Restart Apache so that it lstens on port 80 for http, and port 443 for https (default)

echo "Restarting Apache..."
sudo systemctl restart apache2

# Install and configure Squid web proxy

echo "Installing Squid..."
sudo apt-get install -y squid

# Create a new Squid configuration file

echo "Applying changes to Squid..."
sudo tee /etc/squid/squid.conf>/dev/null <<EOF
http_port 3128
acl localnet src 192.168.16.0/24
http_access allow localnet
http_access deny all
EOF

# Restart Squid to apply the changes

echo "Restarting Squid..."
sudo systemctl restart squid

# Enable firewall
echo "Enabling firewall..."
sudo ufw enable

echo "Configuring firewall..."

# Allow ssh on port 22
sudo ufw allow 22/tcp

# Allow http on port 80
sudo ufw allow 80/tcp

# Allow https on port 443
sudo ufw allow 443/tcp

# Allow we proxy on port 3128
sudo ufw allow 3128/tcp

# Restart firewall

echo "Reloading firewall..."
sudo ufw reload


# User accounts and configurations
# Create the accounts

echo "Creating user accounts..."
user_accounts=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

# Create for loop over users so that each gets a home directory and bash shell, ssh keys, etc.
for user in "${user_accounts[@]}"; do
    sudo useradd -m -s /bin/bash "$user"

    # Generate SSH keys for rsa and ed25519 algorithms
    sudo -u "$user" ssh-keygen -t rsa -b 4096 -f "/home/$user/.ssh/id_rsa" -N ""
    sudo -u "$user" ssh-keygen -t ed25519 -f "/home/$user/.ssh/id_ed25519" -N ""

    # Add public keys to authorized_keys file
    sudo -u "$user" cat "/home/$user/.ssh/id_rsa.pub"|sudo tee -a "/home/$user/.ssh/authorized_keys">/dev/null
    sudo -u "$user" cat "/home/$user/.ssh/id_ed25519.pub"|sudo tee -a "/home/$user/.ssh/authorized_keys">/dev/null


    # Set permissions for .ssh directory and authorized_keys file
    sudo -u "$user" chmod 700 "/home/$user/.ssh"
    sudo -u "$user" chmod 600 "/home/$user/.ssh/authorized_keys"
done

# Modify settings to give sudo access to "dennis"
echo "Modifying settings for Dennis..."
sudo usermod -aG sudo dennis

echo "Done"

