#!/bin/bash
#for i in `seq 1 4`;
#do
let http_port=$1+8080
let https_port=$1+8400

if [ "$1" -ge 10 ]
then 
        id=$1
        echo $id
else
        id=0$1
        echo $id
fi

docker create --name restreamer-$id --restart always -e "RESTREAMER_USERNAME=admin" -e "RESTREAMER_PASSWORD=4820919" -e "LOGGER_LEVEL=4" -e "TIMEZONE=Europe/Kiev" -p $http_port:8080 -p $https_port:443 -v /mnt/restreamer/db$id:/restreamer/db -v /ssl:/ssl test-ms-streamer-slim
#docker start restreamer-$id
#done
docker ps
exit
