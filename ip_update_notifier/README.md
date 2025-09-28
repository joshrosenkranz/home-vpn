# Automated IP Address Change Notifications
This guide explains how to set up a systemd service to automatically send emails when the IP address of the home network changes.

## 1. Setup systemd service
Change the email in `check_ip.sh` to your email address.
Then run `sudo ./setup.sh` to install the proper dependencies and copy the files needed for the systemd service to the correct locations.

## 2. Setup mail configuration
Copy the following into `/etc/msmtprc`, replacing `YOUR_EMAIL` and `YOUR_PASSWORD` with a valid Gmail and Gmail app password.
App passwords can be set up at https://myaccount.google.com/apppasswords.

```
# Global Gmail configuration
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        gmail
host           smtp.gmail.com
port           587
from           YOUR_EMAIL
user           YOUR_EMAIL
password       YOUR_PASSWORD

account default : gmail
```

Run `sudo chmod 600 /etc/msmtprc` and `sudo chown root:root /etc/msmtprc`.

## 3. Start systemd service
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now check_ip.timer
sudo systemctl status check_ip.timer
```

## Notes
To test the email system, change `/var/local/current_ip.txt` to a different IP address and then run `check_ip.sh` or wait for the systemd service to run.
It will send you an email with the new IP address.
