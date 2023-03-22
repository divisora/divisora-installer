#!/usr/bin/env bash

OS=$(lsb_release -i)
OS_NAME=$(cut -f2 <<< "$OS")

RELEASE=$(lsb_release -r)
OS_RELEASE=$(cut -f2 <<< "$RELEASE")

if [ "Ubuntu" != "$OS" ] && [ "22.04" != "$OS_RELEASE" ]; then
  echo "Only Ubuntu 22.04 is supported"
  exit
fi

# Remove old / Other docker and snapd
REMOVE_PKGS="docker docker-engine docker.io containerd runc snapd"
sudo apt-get remove -y $REMOVE_PKGS
sudo apt-get purge -y $REMOVE_PKGS

# Install podman
sudo apt-get -y update
sudo apt-get -y install podman
sudo apt-get -y install python3-docker podman-docker # Docker API (podman do not have a API yet)
sudo apt-get -y install python3-ldap
sudo apt-get -y install freeipa-client

# Install other dependencies
REQUIRED_PKGS="iptables python3"
for p in $REQUIRED_PKGS
do
  PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $p|grep "install ok installed")
  echo "Checking for $p: $PKG_OK"
  if [ "" = "$PKG_OK" ]; then
    echo "Installing $p"
    sudo apt-get --yes install $p
  fi
done

# Root dependancy table
# [x] divisora-node-manager     Must be root to run Docker SDK
# [?] divisora-nginx            
# [?] divisora-core-manager
# [?] divisora-novnc
# [?] divisora-cubicle-ubuntu

# Build NGINX
## Must run as root as long as divisora-node-manager.service need to run as root
(cd ../divisora-nginx && sudo podman build -t divisora/nginx .)

# Build Core-Manager
## Must run as root as long as divisora-node-manager.service need to run as root
(cd ../divisora-core-manager && sudo podman build -t divisora/core-manager .)

# Build Node-Manager
## Must run as root as long as the service need to run as root
(cd ../divisora-node-manager && sudo ./setup.sh)

# Build Freeipa
# TODO: Follow the instructions for now. Building it dynamicly seems to be anoyingly hard.
#       Most likly not gonna be integrated anyway(?)

# Build NOVNC
(cd ../divisora-novnc && sudo podman build -t divisora/novnc .)

# Build Cubicle Ubuntu
# Yes, cubicle-openbox is correct until we fix some hardcodes variables.
(cd ../divisora-cubicle-ubuntu && sudo podman build -t divisora/cubicle-openbox .)

# Instructions
echo ""
echo "[#] Instructions"
echo "[#] Start / configure freeipa (non-root):"
echo "[#] Warning: Do not run this as root!"
echo ""
echo "##### If you dont have Freeipa already #####"
echo "   mkdir -p ~/git"
echo "   cd ~/git && git clone https://github.com/freeipa/freeipa-container.git"
echo "   podman build -t freeipa-alma9 -f Dockerfile.almalinux-9 ."
echo ""
echo "   sudo mkdir -p /opt/divisora_freeipa/data"
echo "   sudo chown -R $USER: /opt/divisora_freeipa"
echo "   podman run --name divisora_freeipa_installer --dns=127.0.0.1 -ti -h ipa.domain.internal -v /opt/divisora_freeipa/data:/data:Z freeipa-alma9 exit-on-finished"
echo "   podman rm divisora_freeipa_installer"
echo "   sudo sh -c 'echo "net.ipv4.ip_unprivileged_port_start=53" >> /etc/sysctl.conf'"
echo "   sudo sysctl --system"
echo "   podman run -d --name divisora_freeipa --dns=127.0.0.1 -h ipa.domain.internal -p 10.0.0.1:53:53/udp -p 10.0.0.1:53:53/tcp -p 8080:80/tcp -p 8443:443/tcp -p 389:389/tcp -p 636:636/tcp -p 88:88/tcp -p 464:464/tcp -p 88:88/udp -p 464:464/udp -p 123:123/udp --read-only --sysctl net.ipv6.conf.all.disable_ipv6=0 -v /opt/divisora_freeipa/data:/data:Z localhost/freeipa-alma9"
echo "   (change /etc/systemd/resolved.conf to point to 10.0.0.1)"
echo "#####"
echo ""
echo "[#] Setup network (as-root)"
echo "   sudo podman network create --subnet 192.168.66.0/24 --gateway 192.168.66.1 divisora_front"
echo ""
echo "[#] Start Core Manager (as-root)"
echo "   sudo podman run --name divisora_core-manager --network divisora_front --network-alias=core-manager -d divisora/core-manager:latest"
echo ""
echo "[#] Start NGINX (as-root)"
echo "   sudo podman run --name divisora_nginx --network divisora_front -d -p 80:80 -p 443:443 divisora/nginx:latest"
echo ""
echo "[#] Start Node manager (as-root)"
echo "   sudo systemctl start divisora-node-manager.service"
echo ""