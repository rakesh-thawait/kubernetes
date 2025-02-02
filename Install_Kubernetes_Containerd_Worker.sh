#!/bin/bash

sudo apt update
# Install Containerd
wget https://github.com/containerd/containerd/releases/download/v1.7.11/containerd-1.7.11-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-1.7.11-linux-amd64.tar.gz
# Setup Containerd as a service
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
chmod +x containerd.service
sudo mkdir -p /usr/local/lib/systemd/system
sudo cp containerd.service /usr/local/lib/systemd/system/

# Install Runc
wget https://github.com/opencontainers/runc/releases/download/v1.1.14/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc
# Generate Containerd config file and copy it at /etc/containerd/ directory
sudo mkdir -p /etc/containerd/
containerd config default > /etc/containerd/config.toml
systemctl restart containerd

# Add Kubernetes Signing Key to ensure the software is authentic
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# Add Kubernetes to software repositories
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
# Ensure all packages are up to date:
sudo apt update
# Install Kubernetes Tools: kubeadm, kubelet and kubectl.
sudo apt install kubeadm kubelet kubectl -y
# Mark the packages as held back to prevent automatic installation, upgrade, or removal
sudo apt-mark hold kubeadm kubelet kubectl
# Disable all swap spaces with the swapoff command:
sudo swapoff -a
# Make the necessary adjustments to the /etc/fstab file:
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load the required containerd modules
cat >/etc/modules-load.d/containerd.conf <<EOF
sudo modprobe overlay
sudo modprobe br_netfilter
EOF

# Add the modules:
sudo modprobe overlay
sudo modprobe br_netfilter

#Configure Kubernetes networking
cat >/etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Reload the configuration changes:
sudo sysctl --system

# Configure Kubelet cgroup driver
echo "KUBELET_EXTRA_ARGS=\"--cgroup-driver=cgroupfs\"" > /etc/default/kubelet

KUBELET_EXTRA_ARGS="--cgroup-driver=cgroupfs"

# Restart kubelet
sudo systemctl daemon-reload && sudo systemctl restart kubelet

# Update Kubelet config
echo "Environment=\"KUBELET_EXTRA_ARGS=--fail-swap-on=false\"" >> /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf

# Restart kubelet
sudo systemctl daemon-reload && sudo systemctl restart kubelet

#################################################################################################### 

# Worker node only

kubeadm join 3.111.54.139:6443 --token 1a910t.yj1j5buzuklpzjgz \
        --discovery-token-ca-cert-hash sha256:e78710809794250da2784deb3354094fcaeb49e972864ca003b0d389c12aeca1