#!/bin/bash

# Install dependencies
sudo apt install msmtp msmtp-mta mailutils -y

# Copy files
cp check_ip.sh /usr/local/bin/check_ip.sh
cp check_ip.service /etc/systemd/system/check_ip.service
cp check_ip.timer /etc/systemd/system/check_ip.timer

chmod +x /usr/local/bin/check_ip.sh
chmod +x /etc/systemd/system/check_ip.service
chmod +x /etc/systemd/system/check_ip.timer
