#!/bin/sh
###############
#
# (c) SANS Internet Storm Center 2014 ; https://isc.sans.edu
#
#     This code is free to use / modify as long as it is attributed
#   contact handlers@sans.edu for feedback.
#   (thanks to @0xmitsurugi and Dan Fayette for providing some updates)
#
###############

# if your copy of openssl is not in your path, please add full path here
# Note for example that for OS X, the default install uses openssl 0.9.8,
# which will not work. If you install openssl 1.0.1 from Macports, you
# have to change this line to openssl="/opt/local/bin/openssl"

openssl="openssl"
ciphers="DHE-RSA-AES256-SHA256 DHE-RSA-AES256-GCM-SHA384 AES128-GCM-SHA256 AES256-GCM-SHA384"

########
#
#  no changes needed beyond this point
#
########

program=$0
host=$1
port=$2

# 
# copied from http://www.linuxjournal.com/content/validating-ip-address-bash-script
#

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}


if ! $openssl ciphers | grep -q DHE-RSA-AES256-SHA256 ; then 
  echo "your version of openssl does not support the required ciphers."
  echo "upgrade to the latest version (1.0.1h or later)"
  exit
fi


if [ -z "$port" ] ; then 
  port=443
fi

if [ -z "$host" ] ; then
  echo "usage: $program hostname [port]"
  exit
fi

if ! host "$host" > /dev/null ; then 
   if ! valid_ip $host; then 
      echo "ERROR: host $host does not resolve to an IP address";
      exit
   fi
fi

#
# check if we can connect via SSL at all
#

if ! openssl s_client -connect $host:$port < /dev/null 2>/dev/null >/dev/null; then
  echo "Can not connect to server. Verify IP address and Port"
  exit
fi

if openssl s_client -connect $host:$port < /dev/null 2>&1 | grep -q 'unknown protocol'; then
  echo "This is not an SSL server."
  exit
fi



#
# check if TLS 1.2 is supported at all
#

if $openssl s_client -connect $host:$port -tls1_2 < /dev/null 2>&1 | grep -q 'wrong version number'; then
   echo "ERROR: The server does not support TLS 1.2 at all. This script will not produce meaningful results and will not run.";
   exit
fi


ciphers="DHE-RSA-AES256-SHA256 DHE-RSA-AES256-GCM-SHA384 AES128-GCM-SHA256 AES256-GCM-SHA384"

s=0




for b in $ciphers; do
  if $openssl s_client -cipher $b -connect $host:$port < /dev/null 2>&1 | grep -q 'handshake failure'; then
     output="- $b not supported\n$output"
  else
     output="+ $b is supported\n$output"
     s=$((s+1))
  fi
  
done
if [ "$s" -gt "0" ] ; then
echo "*** TEST PASS ***"
echo "You are supporting $s out of 4 new ciphers. You likely patched for MS14-066.\n"
else 
echo "*** TEST FAIL ***"
echo "You are not supporting any of the new ciphers. You likely didn't patch for MS14-066\n";
fi
echo $output
echo 
echo "Note: This test ONLY checks the new ciphers. Loadbalancers, web application firewalls, or specific SSL configurations may give false results. Feedback: handlers@sans.edu"

