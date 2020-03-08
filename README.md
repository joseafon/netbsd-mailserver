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
- cd netbsd-mailserver

## Setup
- su -
- chmod 700 netbsd-mailserver

## Run
sh netbsd-mailserver

## Add users and passwords to Mail Server
- su -
- useradd -m -s /sbin/nologin username
- passwd username
