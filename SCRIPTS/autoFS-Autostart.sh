# add this line to /etc/bash.bashrc to make autoFS launch automatically  on boot

cd /home/SCRIPTS/ && bash stage2-network-config.sh && bash stage3_storage.sh && bash stage4_webserver.sh && sleep 1 && bash stage4_webserver_dark.sh
