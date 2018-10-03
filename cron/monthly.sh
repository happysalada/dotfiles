#!/bin/bash
set -x

# `crontab -l` sez this runs every month on the first

# update the list of hosts to block requests from
cd ~/code/hosts
grh
gl
pip3 install --user -r requirements.txt
python3 updateHostsFile.py --auto --replace --extensions social fakenews gambling
sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder
