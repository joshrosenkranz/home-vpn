# OpenVPN Server Setup on Raspberry Pi (Easy-RSA 3.x)

This guide explains how to set up an OpenVPN server on a Raspberry Pi using Easy-RSA 3.x, with instructions to generate client .ovpn files that include all certificates inline. This setup has been tested on a Raspberry Pi 3 Model B+ running Raspberry Pi OS (64-bit).

## 1. Update the System and Install Dependencies
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install openvpn easy-rsa -y
```

## 2. Set Up the PKI (Public Key Infrastructure)
```bash
# Create Easy-RSA directory
make-cadir ~/openvpn-ca
cd ~/openvpn-ca

# Initialize PKI
./easyrsa init-pki

# Build the CA (no password)
./easyrsa build-ca nopass
# When prompted for Common Name, you can accept the default: "Easy-RSA CA"

# Generate the server certificate request and key (no password)
./easyrsa gen-req server nopass

# Sign the server certificate with the CA
./easyrsa sign-req server server

# Generate Diffie-Hellman parameters (may take 5-10 minutes)
./easyrsa gen-dh

# Generate TLS authentication key
openvpn --genkey secret ta.key
```

## 3. Configure IP Forwarding
Uncomment `net.ipv4.ip_forward=1` in `/etc/sysctl.conf` (or add it if it doesn't exist). The bash command below will do that.
```bash
# Enable IPv4 forwarding
sudo sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## 4. Set Up NAT (Masquerading)
```bash
sudo apt install iptables-persistent -y

# Allow VPN clients to access the internet through wlan0
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o wlan0 -j MASQUERADE

# Save the iptables rules
sudo sh -c "iptables-save > /etc/iptables.rules"
```

## 5. Set Permissions for Certificates and Keys
```bash
# Adjust ownership and permissions
sudo chown root:root /home/josh/openvpn-ca/pki/{ca.crt,issued/server.crt,private/server.key,dh.pem}
sudo chmod 644 /home/josh/openvpn-ca/pki/{ca.crt,issued/server.crt,dh.pem}
sudo chmod 600 /home/josh/openvpn-ca/pki/private/server.key
sudo chown root:root /home/josh/openvpn-ca/ta.key
sudo chmod 644 /home/josh/openvpn-ca/ta.key
```

## 6. Copy Certificates and Keys to OpenVPN Directory
```bash
sudo mkdir -p /etc/openvpn/server
sudo cp /home/josh/openvpn-ca/pki/ca.crt /etc/openvpn/server/
sudo cp /home/josh/openvpn-ca/pki/issued/server.crt /etc/openvpn/server/
sudo cp /home/josh/openvpn-ca/pki/private/server.key /etc/openvpn/server/
sudo cp /home/josh/openvpn-ca/pki/dh.pem /etc/openvpn/server/
sudo cp /home/josh/openvpn-ca/ta.key /etc/openvpn/server/
sudo chmod 600 /etc/openvpn/server/server.key
```

## 7. Create the Server Configuration File

`/etc/openvpn/server.conf`:

```conf
port 1194
proto udp
dev tun

# Certificates and keys (Easy-RSA 3 paths)
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
dh /etc/openvpn/server/dh.pem
tls-auth /etc/openvpn/server/ta.key 0

# VPN subnet
server 10.8.0.0 255.255.255.0

# Push routes/DNS to clients
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"

# Security / performance
keepalive 10 120
cipher AES-256-CBC
auth SHA256
user nobody
group nogroup
persist-key
persist-tun

# Logging
status /var/log/openvpn-status.log
verb 3
```

## 8. Enable and Start OpenVPN Server
```bash
sudo systemctl enable openvpn@server
sudo systemctl start openvpn@server
sudo systemctl status openvpn@server
```

## 9. Set Up Client Configuration Template

Create `/etc/openvpn/client-base.conf`:

```conf
client
dev tun
proto udp
remote YOUR_SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
auth SHA256
verb 3
key-direction 1
```

Replace `YOUR_SERVER_IP` with your Pi’s public IP or DNS name.

## 10. Create Script to Generate Client .ovpn Files

`~/openvpn-ca/make_client.sh`:

```bash
#!/bin/bash
# Usage: ./make_client.sh <clientname>
# Example: ./make_client.sh josh

set -e

EASYRSA_DIR=/home/pi/openvpn-ca
OUTPUT_DIR=/home/pi/client-configs
BASE_CONF=/etc/openvpn/client-base.conf

CLIENT=$1

if [[ -z "$CLIENT" ]]; then
  echo "Usage: $0 <clientname>"
  exit 1
fi

cd $EASYRSA_DIR

# Build client certificate and key (nopass)
./easyrsa build-client-full $CLIENT nopass

# Create output directory
mkdir -p $OUTPUT_DIR/files

# Assemble .ovpn file with embedded certs/keys
OVPN=$OUTPUT_DIR/files/${CLIENT}.ovpn

cat $BASE_CONF \
  <(echo -e '<ca>') \
  $EASYRSA_DIR/pki/ca.crt \
  <(echo -e '</ca>\n<cert>') \
  $EASYRSA_DIR/pki/issued/${CLIENT}.crt \
  <(echo -e '</cert>\n<key>') \
  $EASYRSA_DIR/pki/private/${CLIENT}.key \
  <(echo -e '</key>\n<tls-auth>') \
  /etc/openvpn/server/ta.key \
  <(echo -e '</tls-auth>') \
  > $OVPN

echo "✔ Client config created: $OVPN"
```

Make it executable:

```bash
chmod +x ~/openvpn-ca/make_client.sh
```

## 11. Generate a Client Config
```bash
cd ~/openvpn-ca
./make_client.sh josh
```

Output: `/home/pi/client-configs/files/josh.ovpn`

Transfer this file to your device (phone/computer) and import into the OpenVPN app.

No separate `.crt` or `.key` files are needed — everything is included in `josh.ovpn`.

## 12. Test VPN Connection

Connect your client to the VPN.

Ping the server VPN IP (`10.8.0.1`).

Ping an external IP (e.g., `8.8.8.8`).

Open websites to confirm DNS resolution.

## Notes

If your Pi is using Wi-Fi, ensure NAT uses `wlan0` (`iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o wlan0 -j MASQUERADE`). For Ethernet, replace `wlan0` with `eth0`.

For additional clients, just run `./make_client.sh <clientname>`.
