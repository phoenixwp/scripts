#!/bin/sh
# openWRT setup script
# version 0.4.4
set_udhcpc_user(){
	touch /etc/udhcpc.user
	echo 'set_rfc2132_routes() {' >> /etc/udhcpc.user
	echo '  local max=128' >> /etc/udhcpc.user
	echo '  local type' >> /etc/udhcpc.user
	echo '  while [ -n "$1" -a $max -gt 0 ]; do' >> /etc/udhcpc.user
	echo '  route add "${1%%/*}" gw "${1##*/}"' >> /etc/udhcpc.user
	echo '  max=$(($max-1))' >> /etc/udhcpc.user
	echo '  shift 1' >> /etc/udhcpc.user
	echo '  done' >> /etc/udhcpc.user
	echo '}' >> /etc/udhcpc.user
	echo 'if [[ "$1" == renew || "$1" == bound ]]' >> /etc/udhcpc.user
	echo '  then' >> /etc/udhcpc.user
	echo '  [ -n "$routes" ] && set_rfc2132_routes $routes' >> /etc/udhcpc.user
	echo 'fi' >> /etc/udhcpc.user
	chmod +x /etc/udhcpc.user
}
set_wifi(){
        uci set wireless.@wifi-device[0].disabled=0
	uci set wireless.@wifi-device[0].country=UA
	uci set wireless.@wifi-device[0].channel=auto
        uci set wireless.@wifi-iface[0].ssid=$1
        uci set wireless.@wifi-iface[0].key=$2
        uci set wireless.@wifi-iface[0].encryption='psk2+ccmp'
        uci commit wireless
}
#############
if [ ! $# == 2 ];
	then
        echo "Script usage: sh $0 username password" 
        exit
fi
iface=`uci get network.wan.ifname`
user=$1
pass=$2
#
patched=0
if grep "set_rfc2132_routes()" /lib/netifd/dhcp.script >> null
        then
        echo Older patch method found! Restoring original file...
        cp -f /rom/lib/netifd/dhcp.script /lib/netifd/dhcp.script
        chmod +x /lib/netifd/dhcp.script
fi
if [ -f "/etc/udhcpc.user" ]
        then
        if grep "set_rfc2132_routes()" /etc/udhcpc.user >> null
                then
                patched=1
        fi
fi
if ! [ -x "/sbin/route" ]
        then
        echo route : non-executable
fi
case "$patched" in
        0 )
        echo Adding DHCP option 33...
        set_udhcpc_user
        ;;
        1 )
        echo option 33 already applied...
        ;;
esac
if grep "/lib/netifd/dhcp.script" /etc/sysupgrade.conf >> null
        then
        sed -i "/\/lib\/netifd\/dhcp.script/d" "/etc/sysupgrade.conf"
fi
if ! grep "/etc/udhcpc.user" /etc/sysupgrade.conf >> null
        then
        echo Adding /etc/udhcpc.user to sysupgrade.conf
        echo '/etc/udhcpc.user' >> /etc/sysupgrade.conf
else
        echo udhcpc.user already in sysupgrade.conf
        break
fi
#
if ! cat /etc/config/network|grep pppoe > null
	then
	echo Setting up PPPoE...					########
        uci set network.wan.proto=pppoe
        uci set network.wan.username=$user
        uci set network.wan.password=$pass
        uci set network.wan.keepalive='3 10'
else
	echo PPPoE already configured
	break
fi
if ! cat /etc/config/network|grep 'da' > null
	then
	echo Setting up dual access interface...			########
	uci set network.da=interface
	uci set network.da.proto=dhcp
	uci set network.da.ifname=$iface
	uci set network.da.delegate=0
	uci set network.da.defaultroute=0
else
	echo dual access already configured
	break
fi
if grep 'ula_prefix' /etc/config/network > null
	then
	uci delete network.globals.ula_prefix
fi
if grep 'network.globals' /etc/config/network > null
        then
	uci delete network.globals
fi
echo Pinning wan6 to wan iface						########
uci set network.wan6.ifname=@wan
uci commit network
echo restarting network...						########
/etc/init.d/network restart
sleep 10
echo Internet connection cheking...					########
success=0
err=0
while success=1
do
	if (route -n|awk '{print $2}'|grep 217.77.208.254 > null)
	then
        	success=1
	        echo Internet connection esthablished
	        break
	else
	echo Error! Intenet connection failed
	if ! ifconfig $iface | grep -i running > null
	then err=1
	elif ifstatus wan | grep -i auth_topeer_failed > null
	then err=2
	fi
	case "$err" in
	[0] )	break
		;;
	[1] )   echo No link. Check WAN cable and press Enter
		read
		sleep 5
		continue
		;;
	[2] )   echo Error 691.
		echo Login: `uci get network.wan.username`
		echo Password: `uci get network.wan.password` 
		echo Retype login and password:
		echo Login:
		read user
                echo Password:
                read pass
	        uci set network.wan.username=$user
	        uci set network.wan.password=$pass
		uci commit network
		/etc/init.d/network restart
		sleep 15
		continue
		;;
	esac
	fi
done
echo Installing igmpproxy and kmod-ipt-nathelper-rtsp		#######
opkg update
opkg install igmpproxy
opkg install kmod-ipt-nathelper-rtsp
#
echo Fixing igmpproxy restart...				#######
touch /etc/hotplug.d/iface/40-igmpproxy
chmod a+rx /etc/hotplug.d/iface/40-igmpproxy
echo '#!/bin/sh' > /etc/hotplug.d/iface/40-igmpproxy
echo '[ "$INTERFACE" = wan ] && [ "$ACTION" = ifup ] && /etc/init.d/igmpproxy restart' >> /etc/hotplug.d/iface/40-igmpproxy 
echo '/etc/hotplug.d/iface/40-igmpproxy' >> /etc/sysupgrade.conf
#
echo Enabling igmpproxy autostart				#######
/etc/init.d/igmpproxy enable
echo Adding igmpproxy rules					#######
uci set igmpproxy.wan.network=da
uci set igmpproxy.wan.altnet=0.0.0.0/0
uci commit igmpproxy
/etc/init.d/igmpproxy restart
#
echo Adding "da" zone						#######
echo ----------------
sleep 1
uci add firewall zone
uci set firewall.@zone[2].name='da'
uci set firewall.@zone[2].input='REJECT'
uci set firewall.@zone[2].forward='REJECT'
uci set firewall.@zone[2].output='ACCEPT'
uci set firewall.@zone[2].network='da'
uci set firewall.@zone[2].masq=1
uci set firewall.@zone[2].mtu_fix=1
echo Adding more forwarding rules				########
sleep 1
uci add firewall forwarding
uci set firewall.@forwarding[1].src=lan
uci set firewall.@forwarding[1].dest=da
uci commit firewall
/etc/init.d/firewall restart
sleep 5
echo Choose the way to setup Wi-Fi:
echo [1] - setup Wi-Fi and use login and password for I-net as SSID\&key
echo [2] - setup Wi-Fi using custom SSID\&key
echo [3] - skip this step and finish installation
choice=0
ssid=$user
key=$pass
while choice=1 || choice=2 || choice=3
do
        echo Enter your choice\(1/2/3\):
        read choice
case "$choice" in
        [1] ) 
        set_wifi $ssid $key
        echo $user
        echo $pass
        break
        ;;
        [2] )
        echo Enter SSID:
        read ssid
        echo Enter key:
        read key
        set_wifi $ssid $key
        break
        ;;
        [3] )
        break
        ;;
esac
done
echo Installation complete. Router is going to reboot...
reboot
exit 0
