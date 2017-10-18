#!/bin/bash
touch /tmp/ls.log
while true
do
count=1
id=1
while [ $count -le 24 ]
do
#sleep 20
for i in `seq 1 24`;
do
	if [ "$i" -ge 10 ]
        then 
		id=$i
		echo $id
	else
		id=0$i
		echo $id
	fi
	docker exec restreamer-$id /bin/ls -l /tmp/hls > /tmp/ls.log
#	echo "i= $i"
	let count+=1
	if ( ! grep m3u8 /tmp/ls.log > /dev/null)
		then 
			docker restart restreamer-$id > /dev/null
			touch /var/log/streamer.log
			echo "$(date) restreamer-$id: m3u8 file not found. Container is going to reboot" >> /var/log/streamer.log
	fi
done
done
sleep 400
done
exit
