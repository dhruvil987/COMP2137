#!/bin/bash

# Define variables for target machines
TARGET1="remoteadmin@172.16.1.10"
TARGET2="remoteadmin@172.16.1.11"
NMS_HOSTS="/etc/hosts"

# Function to execute commands on remote machines
execute_remote_command() {
    ssh $1 "$2"
}

# Function to update NMS hosts file
update_nms_hosts() {
    echo -e "$1" | sudo tee -a "$NMS_HOSTS"
}

#going tp Target 1 configuration
execute_remote_command $TARGET1 "sudo hostnamectl set-hostname loghost"  # Change hostname to loghost on Target1
execute_remote_command $TARGET1 "sudo sed -i 's/172.16.1.10\ttarget1/172.16.1.3\tloghost/' $NMS_HOSTS"  # Update IP and hostname in NMS hosts file for Target1
execute_remote_command $TARGET1 "sudo sed -i 's/172.16.1.10\tloghost/172.16.1.4\twebhost/' $NMS_HOSTS"  # Add webhost entry in NMS hosts file for Target1
execute_remote_command $TARGET1 "sudo apt-get update && sudo apt-get install -y ufw"  # Update and install UFW on Target1
execute_remote_command $TARGET1 "sudo ufw allow from 172.16.1.0/24 to any port 514 proto udp"  # Allow UDP connections on Target1
execute_remote_command $TARGET1 "sudo sed -i '/imudp/s/^#//' /etc/rsyslog.conf && sudo systemctl restart rsyslog"  # Configure rsyslog on Target1

#going  Target 2 configuration
execute_remote_command $TARGET2 "sudo hostnamectl set-hostname webhost"  # Change hostname to webhost on Target2
execute_remote_command $TARGET2 "sudo sed -i 's/172.16.1.11\ttarget2/172.16.1.4\twebhost/' $NMS_HOSTS"  # Update IP and hostname in NMS hosts file for Target2
execute_remote_command $TARGET2 "sudo sed -i 's/172.16.1.11\twebhost/172.16.1.3\tloghost/' $NMS_HOSTS"  # Add loghost entry in NMS hosts file for Target2
execute_remote_command $TARGET2 "sudo apt-get update && sudo apt-get install -y ufw apache2"  # Update and install UFW and Apache2 on Target2
execute_remote_command $TARGET2 "sudo ufw allow 80/tcp"  # Allow HTTP connections on Target2
execute_remote_command $TARGET2 "echo '*.* @loghost' | sudo tee -a /etc/rsyslog.conf"  # Configure rsyslog on Target2
execute_remote_command $TARGET2 "sudo systemctl restart rsyslog"  # Restart rsyslog service on Target2

# Update NMS hosts file
update_nms_hosts "172.16.1.3\tloghost\n172.16.1.4\twebhost"  # Update NMS hosts file with IP and hostnames for loghost and webhost

# Check configurations
if firefox http://webhost &>/dev/null; then  # Check if default Apache page can be retrieved from webhost
    if ssh remoteadmin@loghost grep webhost /var/log/syslog &>/dev/null; then  # Check if logs from webhost can be retrieved from loghost
        echo "Configuration update succeeded."  # Print success message
    else
        echo "Failed to retrieve logs from loghost for webhost."  # Print failure message for log retrieval
    fi
else
    echo "Failed to retrieve default Apache page from webhost."  # Print failure message for Apache page retrieval
fi

