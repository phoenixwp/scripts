#!/bin/bash
for i in `seq $1 $2`;
do
	let http_port=$i+8080
	let https_port=$i+8400
	if [ "$i" -ge 10 ]
	then
            id=$i
	else
            id=0$i
	fi
	docker create --name restreamer-$id --restart always -e "RESTREAMER_USERNAME=admin" -e "RESTREAMER_PASSWORD=4820919" -e "LOGGER_LEVEL=4" -e "TIMEZONE=Europe/Kiev" -p $http_port:8080 -p $https_port:443 -v /mnt/restreamer/db$id:/restreamer/db -v /ssl:/ssl ms-streamer
	docker start restreamer-$id
done
docker ps
exit
