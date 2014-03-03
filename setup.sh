#!/bin/bash
# Based on Adafruit Learning Technologies Onion Pi project.
# For more info: http://learn.adafruit.com/onion-pi
#
# To do:
# * Code, code, and code!
# * Options for setting up relay, exit, or bridge
# * More anonymization of Onion Pi box
# * Further testing

if (( $EUID != 0 )); then
  /bin/echo "This must be run as root. Type in 'sudo $0' to run it as root."
  exit 1
fi

/bin/cat <<'Onion_Pi'
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

/bin/echo "This script will auto-setup a Tor proxy for you. It is recommend that you
run this script on a fresh installation of Raspbian."
read -p "Press [Enter] key to begin.."

/bin/echo "Updating package index.."
/usr/bin/apt-get update -y

/bin/echo "Updating out-of-date packages.."
/usr/bin/apt-get upgrade -y

/bin/echo "Removing Wolfram Alpha Enginer due to bug. More info:
http://www.raspberrypi.org/phpBB3/viewtopic.php?f=66&t=68263"
/usr/bin/apt-get remove wolfram-engine
/bin/echo "Downloading and installing various packages.."
/usr/bin/apt-get install -y tor chkrootkit unattended-upgrades ntp monit

/bin/echo "Configuring Tor.."
/bin/cat /dev/null > /etc/tor/torrc
/etc/tor/torrc <<'onion_pi_configuration'
# Onion Pi Config v0.2
# More information: https://github.com/breadtk/onion_pi/
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

/bin/echo "Fixing firewall configuration.."
/sbin/iptables -F
/sbin/iptables -t nat -F
/sbin/iptables -t nat -A PREROUTING -i wlan0 -p udp --dport 53 -j REDIRECT --to-ports 53
/sbin/iptables -t nat -A PREROUTING -i wlan0 -p tcp --syn -j REDIRECT --to-ports 9040
/bin/sh -c "/sbin/iptables-save > /etc/iptables.ipv4.nat"

/bin/echo "Wiping various  files and directories.."
/usr/bin/shred -fvzu -n 3 /var/log/wtmp
/usr/bin/shred -fvzu -n 3 /var/log/lastlog
/usr/bin/shred -fvzu -n 3 /var/run/utmp
/usr/bin/shred -fvzu -n 3 /var/log/mail.*
/usr/bin/shred -fvzu -n 3 /var/log/syslog*
/usr/bin/shred -fvzu -n 3 /var/log/messages*
/usr/bin/shred -fvzu -n 3 /var/log/auth.log*

/bin/echo "Setting up logging in /var/log/tor/notices.log.."
/usr/bin/touch /var/log/tor/notices.log
/bin/chown debian-tor /var/log/tor/notices.log
/bin/chmod 644 /var/log/tor/notices.log

/bin/echo "Setting tor to start at boot.."
/usr/sbin/update-rc.d tor enable

/bin/echo "Setting up Monit to watch Tor process.."
/etc/monit/monitrc << 'tor_monit'
check process tor with pidfile /var/run/tor/tor.pid
group tor
start program = "/etc/init.d/tor start"
stop program = "/etc/init.d/tor stop"
if failed port 9050 type tcp
   with timeout 5 seconds
   then restart
if 3 restarts within 5 cycles then timeout
tor_monit

/bin/echo "Starting monit.."
/usr/bin/monit quit
/usr/bin/monit -c /etc/monit/monitrc

/bin/echo "Starting tor.."
/usr/sbin/service tor start

/bin/echo "Setup complete!
To connect to your own node set your web browser to connect to:
  Proxy type: SOCKSv5
  IP: $(hostname -i | awk '{print $1}')
  Port: 9050

Verify your installation by visiting: https://check.torproject.org/
"

exit
