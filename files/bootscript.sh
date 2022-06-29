#!/bin/bash -xe
exec > /var/log/userdata.log 2>&1
set +e

## Update OS and install necessary packages
apt-add-repository ppa:ansible/ansible -y
apt update
apt install -y chrony apt-transport-https python3-pip awscli jq ansible
sed -i '1s;^;server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4\n;' /etc/chrony/chrony.conf && /etc/init.d/chrony restart # Install NTP with Amazon Time Sync Service

pip3 install boto3 botocore pymsteams --user
pip3 install --upgrade awscli --user
ansible-galaxy collection install amazon.aws

## Download and install Amazon SSM agent package
mkdir /build-artifacts
cd /build-artifacts
wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
dpkg -i amazon-ssm-agent.deb

## Download SSM Plugin
wget https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb
dpkg -i session-manager-plugin.deb

## Download and install Amazon CloudWatch agent package
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:AmazonCloudWatch-${STACK_NAME}-parameter
