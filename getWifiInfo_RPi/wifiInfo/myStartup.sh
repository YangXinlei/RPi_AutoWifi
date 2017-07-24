#!/bin/bash

OUT=/home/pi/BT/wifiInfo/log.log
OUTII=/home/pi/BT/wifiInfo/log2.log
sleep 5
sudo /usr/local/bin/node /home/pi/BT/wifiInfo/echo/main.js >> /home/pi/BT/wifiInfo/log.log 2>$OUT &

sleep 1

sudo /usr/local/bin/node /home/pi/BT/wifiInfo/main.js >> $OUTII 2>$OUTII &

exit 0
