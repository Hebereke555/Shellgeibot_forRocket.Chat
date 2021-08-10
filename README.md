# Shellgeibot_forRocket.Chat
Shellgeibot for Rocket.Chat

必要環境
-------------
systemd,
docker,
curl,
bash,
sed,
awk,
unzip

root account

使い方/How To Use
-------------
*STEP1:*

Download

	mkdir /shellscripts && cd /shellscripts
	wget https://raw.githubusercontent.com/Hebereke555/Shellgeibot_forRocket.Chat/main/shellgeibot_rocketchat.sh
	chmod a+x shellgeibot_rocketchat.sh
	
*STEP2:*
	
Edit the variables in the script
	
	TOKEN=*Token of bot account in Rocket.Chat*
	USERID=*UserId of bot account in Rocket.Chat*
	ROOMID=*Your RoomId of Rocket.Chat*
	URL=*URL of your Rocket.Chat Server*

*STEP3:*

Start docker
	
	systemctl start docker
	
*STEP4:*

Systemd
	
	cd /etc/systemd/system/
	wget https://raw.githubusercontent.com/Hebereke555/Shellgeibot_forRocket.Chat/main/shellgeibot_rocketchat.service
	systemctl enable shellgeibot_rocketchat.service
	systemctl start shellgeibot_rocketchat.service
