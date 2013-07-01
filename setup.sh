#!/bin/bash
# Based on Adafruit Learning Technologies Onion Pi project
# More info: http://learn.adafruit.com/onion-pi
# 
#
# To do:
# * Code, code, and code!
# * Welcome banner
# * Options for setting up relay, exit, or bridge
# * Anonymization of Onion Pi box
# * Further testing

if (( $EUID != 0 )); then
  echo "This must be run as root. Type in 'sudo $0' to run it as root."
  exit 1
fi

cat <<'Onion_Pi'
                            ~
                           /~
                     \  \ /**
                      \ ////
                      // //
                     // //
                   ///&//
                  / & /\ \
                /  & .,,  \
              /& %  :       \
            /&  %   :  ;     `\
           /&' &..%   !..    `.\
          /&' : &''" !  ``. : `.\
         /#' % :  "" * .   : : `.\
        I# :& :  !"  *  `.  : ::  I
        I &% : : !%.` '. . : : :  I
        I && :%: .&.   . . : :  : I
        I %&&&%%: WW. .%. : :     I
         \&&&##%%%`W! & '  :   ,'/
          \####ITO%% W &..'  #,'/
            \W&&##%%&&&&### %./
              \###j[\##//##}/
                 ++///~~\//_
                  \\ \ \ \  \_
                  /  /    \
Onion_Pi

echo "This script will auto-setup a Tor proxy for you."
read -p "Press [Enter] key to begin..."

echo "Updating packages..."
apt-get update -q -y

echo "Installing Tor..."
apt-get install tor

echo "Configuring Tor..."
/etc/tor/torrc <<'onion_pi_configuration'
# v0.2
Log notice file /var/log/tor/notices.log
VirtualAddrNetwork 10.192.0.0/10
AutomapHostsSuffixes .onion,.exit
AutomapHostsOnResolve 1
TransPort 9040
TransListenAddress 192.168.42.1
DNSPort 53
DNSListenAddress 192.168.42.1
SocksPort 9050
ClientOnly 1
Exitpolicy reject *:*

onion_pi_configuration

echo "Fixing firewall configuration..."
iptables -F
iptables -t nat -F
iptables -t nat -A PREROUTING -i wlan0 -p udp --dport 53 -j REDIRECT --to-ports 53
iptables -t nat -A PREROUTING -i wlan0 -p tcp --syn -j REDIRECT --to-ports 9040
sh -c "iptables-save > /etc/iptables.ipv4.nat"

echo "Setting up logging in /var/log/tor/notices.log ..."
touch /var/log/tor/notices.log
chown debian-tor /var/log/tor/notices.log
chmod 644 /var/log/tor/notices.log

echo "Setting tor to start at boot..."
update-rc.d tor enable

echo "Setting starting tor..."
service tor start

echo "Setup complete!
To connect to your own node set your web browser to connect to:
  Proxy type: SOCKSv5
  IP: $(hostname -i | awk '{print $2}')
  Port: 9050

Verify by visiting: https://check.torproject.org/
"

exit 0
