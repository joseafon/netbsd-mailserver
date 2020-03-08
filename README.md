![Diagrama1](https://user-images.githubusercontent.com/57175463/76168051-8dfc4c00-6163-11ea-980e-5f0cd60fa66a.jpeg)

## netbsd-mailserver

## Script to autoinstall a DNS and local Mail Server with STARTTLS on NetBSD  

## Language
Shell script (Bourne Shell)

## Tested on
NetBSD 9.0

## Prerequisites
- A new NetBSD installation
- A Class C network -----> 192.168.X.0/24

## Services
Named (Bind9), Postfix, Dovecot, PF FIREWALL, SSH

## Installation
- wget --no-check-certificate https://codeload.github.com/joseafon/netbsd-mailserver/zip/master
- unzip master 
- cd netbsd-mailserver-master

## Setup
- su 
- chmod 700 netbsd-mailserver.sh

## Run
sh netbsd-mailserver.sh

## Add users and passwords to Mail Server
- su 
- useradd -m -s /sbin/nologin username
- passwd username
