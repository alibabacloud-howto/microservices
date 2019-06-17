#!/usr/bin/env bash

echo "LC_ALL=en_US.utf-8" >> /etc/environment
echo "LANG=en_US.utf-8" >> /etc/environment
echo "LANGUAGE=en_US.UTF-8" >> /etc/environment
export LC_ALL=en_US.utf-8
export LANG=en_US.utf-8
export LANGUAGE=en_US.UTF-8

yum update -y
yum install -y java-1.8.0-openjdk maven

systemctl enable microservicesbackendapp
systemctl start microservicesbackendapp

systemctl enable firewalld
systemctl start firewalld
firewall-cmd --add-forward-port=port=80:proto=tcp:toport=8080

sleep 10