#########################################################################
#                                                                       #
#       Name of Script: netbsd-mailserver                               #
#       Description: DNS and local Mail Server with STARTTLS on NetBSD  #
#       Author: Jose Manuel Afonso Santana                              #
#       Alias: joseafon                                                 #
#       Email: jmasantana@linuxmail.org                                 #
#                                                                       #
#########################################################################

#!/bin/sh

##NETCARD NAME##

NETCARD=$(ifconfig | head -n 1 | awk '{print $1}' | cut -d ':' -f 1)

##FUNCTIONS##

PF_FIREWALL ()
{

    cp /etc/pf.conf /etc/pf.conf.backup
    rm /etc/pf.conf

echo "
###PF FIREWALL###

set skip on lo

scrub in all

block in quick from urpf-failed

block in all

##IMAP 4 over SSL (E-mail)##
pass in quick on $NETCARD proto tcp from $NETWORK_ADDRESS/24 to $IP port 993

##IMAP 4
pass in quick on $NETCARD proto tcp from $NETWORK_ADDRESS/24 to $IP port 143

##SMTP##
pass in quick on $NETCARD proto tcp from $NETWORK_ADDRESS/24 to $IP port 25

##SSH##
pass in quick on $NETCARD proto tcp from $NETWORK_ADDRESS/24 to $IP port 22

##DNS and RNDC##

pass in quick on $NETCARD proto { tcp, udp } from $NETWORK_ADDRESS/24 to $IP port { 53, 953 }

##ICMP##
pass inet proto icmp all icmp-type echoreq

##NTP##
pass in quick on $NETCARD proto udp from any to $IP port 123

pass out all
" > /etc/pf.conf

}

RC_CONF ()

{
    cp /etc/rc.conf /etc/rc.conf.backup
    rm /etc/rc.conf

    echo "
#	\$NetBSD: rc.conf,v 1.97 2014/07/14 12:29:48 mbalmer Exp $
#
# See rc.conf(5) for more information.
#
# Use program=YES to enable program, NO to disable it. program_flags are
# passed to the program on the command line.
#

# Load the defaults in from /etc/defaults/rc.conf (if it's readable).
# These can be overridden below.
#
if [ -r /etc/defaults/rc.conf ]; then
	. /etc/defaults/rc.conf
fi

# If this is not set to YES, the system will drop into single-user mode.
#
rc_configured=YES

# Add local overrides below.
#
hostname=$HOSTNAME.$DOMAIN_NAME
sshd=YES
ntpd=YES
ntpdate=YES
dovecot=YES
named=YES
wscons=YES
clear_tmp=YES
securelevel=1
pf=YES
pflogd=YES
pf_rules=\"/etc/pf.conf\"
pf_lags=\"\"

" > /etc/rc.conf


}

clear

echo "
+------------------------------+
|                              |
|      NETBSD-MAIL-SERVER      |
|                              |
+------------------------------+
"
echo "Updating pkgin"
echo "--------------"
sleep 2

echo
pkgin -y update

clear

echo "Installing dovecot"
echo "------------------"

echo
pkgin -y install dovecot

sleep 2

while :
do

clear

    echo "
+----------------------------+
|                            |
|       NETWORK CONFIG       |
|                            |
+----------------------------+
"
echo

echo "Only Class C Network support ---> 192.168.X.0/24"
echo
echo "Insert your ip"
echo "-------------"
echo
read IP

echo

echo "Insert your gateway"
echo "-------------------"
echo

read GATEWAY

echo

echo "Insert your network address"
echo "---------------------------"
echo
echo "Example:192.168.1.0"
echo
read NETWORK_ADDRESS

echo

echo "Insert your hostname"
echo "--------------------"
echo

read HOSTNAME 

echo

echo "Insert your domain name"
echo "-----------------------"
echo
echo "Example: myhouse.local"
echo
read DOMAIN_NAME

clear

echo "This is your network configuration"
echo "===================================="
echo
echo "IP ADDRESS: $IP"
echo "GATEWAY: $GATEWAY"
echo "NETWORK: $NETWORK_ADDRESS/24"
echo "HOSTNAME: $HOSTNAME"
echo "DOMAIN NAME: $DOMAIN_NAME"
echo "FQDN: $HOSTNAME.$DOMAIN_NAME"
echo
echo "====================================="
echo
echo "This is correct? [y/n]"
echo

read ANSWER

echo

    case $ANSWER in

    y) break ;;

    n) echo "Reconfigure"
        sleep 2 ;;

    *)  echo "Option not valid"
         sleep 2 ;;

    esac

done

echo "
up
media autoselect
$IP netmask 255.255.255.0 media autoselect
" > /etc/ifconfig.$NETCARD

echo "$GATEWAY" > /etc/mygate

clear

postconf -e 'home_mailbox = Maildir/' 
postconf -e 'mydomain = '$DOMAIN_NAME''
postconf -e 'myhostname = '$HOSTNAME'.'$DOMAIN_NAME''
postconf -e 'mynetworks = '$NETWORK_ADDRESS'/24, 127.0.0.1/8'
postconf -e 'mydestination =  $mydomain, $myhostname, localhost.$mydomain, localhost'

clear

echo "To generate SSL certificate and private key"

sleep 2

echo

mkdir -p /etc/ssl/certs && mkdir -p /etc/ssl/private 
cp /usr/share/examples/openssl/openssl.cnf /etc/openssl/

openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/private/$DOMAIN_NAME.key -out /etc/ssl/certs/$DOMAIN_NAME.crt -nodes -sha256 -days 365

clear

chmod 600 /etc/ssl/private/$DOMAIN_NAME.key

postconf -e 'smtpd_tls_security_level = may'
postconf -e 'smtpd_use_tls = yes'
postconf -e 'smtpd_tls_auth_only = yes'
postconf -e 'smtpd_tls_cert_file = /etc/ssl/certs/'$DOMAIN_NAME'.crt'
postconf -e 'smtpd_tls_key_file = /etc/ssl/private/'$DOMAIN_NAME'.key'
postconf -e 'smtpd_tls_loglevel = 1'
postconf -e 'inet_interfaces = all'

echo "smtp      inet  n       -       n       -       -       smtpd" >> /etc/postfix/master.cf


sed -i '21d' /usr/pkg/etc/dovecot/dovecot.conf

rm /usr/pkg/etc/dovecot/conf.d/10-ssl.conf 

echo "
##
## SSL settings
##

# SSL/TLS support: yes, no, required. <doc/wiki/SSL.txt>
ssl = yes

# PEM encoded X.509 SSL/TLS certificate and private key. They're opened before
# dropping root privileges, so keep the key file unreadable by anyone but
# root. Included doc/mkcert.sh can be used to easily generate self-signed
# certificate, just make sure to update the domains in dovecot-openssl.cnf
ssl_cert = </etc/ssl/certs/$DOMAIN_NAME.crt
ssl_key = </etc/ssl/private/$DOMAIN_NAME.key


# If key file is password protected, give the password here. Alternatively
# give it when starting dovecot with -p parameter. Since this file is often
# world-readable, you may want to place this setting instead to a different
# root owned 0600 file by using ssl_key_password = <path.
#ssl_key_password =

# PEM encoded trusted certificate authority. Set this only if you intend to use
# ssl_verify_client_cert=yes. The file should contain the CA certificate(s)
# followed by the matching CRL(s). (e.g. ssl_ca = </etc/ssl/certs/ca.pem)
#ssl_ca =

# Require that CRL check succeeds for client certificates.
#ssl_require_crl = yes

# Directory and/or file for trusted SSL CA certificates. These are used only
# when Dovecot needs to act as an SSL client (e.g. imapc backend or
# submission service). The directory is usually /etc/ssl/certs in
# Debian-based systems and the file is /etc/pki/tls/cert.pem in
# RedHat-based systems.
#ssl_client_ca_dir =
#ssl_client_ca_file =

# Require valid cert when connecting to a remote server
#ssl_client_require_valid_cert = yes

# Request client to send a certificate. If you also want to require it, set
# auth_ssl_require_client_cert=yes in auth section.
#ssl_verify_client_cert = no

# Which field from certificate to use for username. commonName and
# x500UniqueIdentifier are the usual choices. You'll also need to set
# auth_ssl_username_from_cert=yes.
#ssl_cert_username_field = commonName

# SSL DH parameters
# Generate new params with `openssl dhparam -out /etc/dovecot/dh.pem 4096`
# Or migrate from old ssl-parameters.dat file with the command dovecot
# gives on startup when ssl_dh is unset.
#ssl_dh = </etc/dovecot/dh.pem

# Minimum SSL protocol version to use. Potentially recognized values are SSLv3,
# TLSv1, TLSv1.1, and TLSv1.2, depending on the OpenSSL version used.
#ssl_min_protocol = TLSv1

# SSL ciphers to use, the default is:
#ssl_cipher_list = ALL:!kRSA:!SRP:!kDHd:!DSS:!aNULL:!eNULL:!EXPORT:!DES:!3DES:!MD5:!PSK:!RC4:!ADH:!LOW@STRENGTH
# To disable non-EC DH, use:
#ssl_cipher_list = ALL:!DH:!kRSA:!SRP:!kDHd:!DSS:!aNULL:!eNULL:!EXPORT:!DES:!3DES:!MD5:!PSK:!RC4:!ADH:!LOW@STRENGTH

# Colon separated list of elliptic curves to use. Empty value (the default)
# means use the defaults from the SSL library. P-521:P-384:P-256 would be an
# example of a valid value.
#ssl_curve_list =

# Prefer the server's order of ciphers over client's.
#ssl_prefer_server_ciphers = no

# SSL crypto device to use, for valid values run "openssl engine"
#ssl_crypto_device =

# SSL extra options. Currently supported options are:
#   compression - Enable compression.
#   no_ticket - Disable SSL session tickets.
#ssl_options =
" > /usr/pkg/etc/dovecot/conf.d/10-ssl.conf

sed -i '30d' /usr/pkg/etc/dovecot/conf.d/10-mail.conf

echo "protocols = imap lmtp" >> /usr/pkg/etc/dovecot/dovecot.conf
echo "mail_location = maildir:~/Maildir" >> /usr/pkg/etc/dovecot/conf.d/10-mail.conf

cp -v /usr/pkg/share/examples/rc.d/dovecot /etc/rc.d/

echo 

postconf -e 'smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination'

echo 

REVERSE_IP=$(echo $IP | awk -F . '{print $3"."$2"."$1}')

echo "
zone \"$DOMAIN_NAME\" {
    type master;
    notify no;
    file \"$DOMAIN_NAME\";
};

zone \"$REVERSE_IP.IN-ADDR.ARPA\" {
    type master;
    notify no;
    file \"$REVERSE_IP\";
};
" >> /etc/named.conf


echo "
;	\$NetBSD: localhost,v 1.2 2000/05/19 13:07:37 sommerfeld Exp $

\$TTL	3600
@	IN	SOA	$DOMAIN_NAME. hostmaster.$DOMAIN_NAME. (
				1999012100	; Serial
				3600		; Refresh
				300		; Retry
				3600000		; Expire
				3600 )		; Minimum

		          IN    NS	$DOMAIN_NAME.
$DOMAIN_NAME.          IN    A   $IP
$DOMAIN_NAME.     IN  MX 10   $DOMAIN_NAME.
$HOSTNAME              IN    A   $IP
" > /etc/namedb/$DOMAIN_NAME

HOSTNUMBER=$(echo $IP | cut -d "." -f 4)

echo "
;	\$NetBSD: localhost,v 1.2 2000/05/19 13:07:37 sommerfeld Exp $

\$TTL	3600
@	IN	SOA	$DOMAIN_NAME. hostmaster.$DOMAIN_NAME. (
				1999012100	; Serial
				3600		; Refresh
				300		; Retry
				3600000		; Expire
				3600 )		; Minimum

		IN	NS	        $DOMAIN_NAME.
$DOMAIN_NAME.     IN  A           $IP
$HOSTNUMBER     IN  PTR         $HOSTNAME.$DOMAIN_NAME.
" > /etc/namedb/$REVERSE_IP

clear

RC_CONF
PF_FIREWALL
newaliases

clear

echo "****MAIL SERVER READY****"

sleep 2

echo

echo "****REBOOT SYSTEM****"

echo

reboot

