#!/bin/bash

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# You MUST WRITE
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
TOKEN=							#TOKEN of RocketChat	#RocketChatのToken．Tokenについてはググろう
USERID=							#UserID of RocketChat	#RocketChatのシェル芸botを実行するユーザーID． ユーザーのroleにはbotも追加しておく
ROOMID=							#RoomID of RocketChat	#シェル芸botを動かすRocketChatのルームID．
URL=							#URL or IP addr of RocketChat, If the Rocket.Chat Server don't use Well Known Port, You must add port num (ex localhost.localdomain:3000). Don't write http or https 
							#RocketChatの鯖のURL．http等はいらないがウェルノウンポートではない場合ポート番号も追加する(ex localhost.localdomain:3000)．
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# If you want change, Rewrite
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
RAMDISK=/ramdisk		#RAMDISK Dir.This script use ramdisk #本スクリプトはRAMDISKを使用する．そのマウントディレクトリの設定．ディレクトリはなくても生成される．逆に中にファイルやフォルダがあると動かない
FILENAME=Command.txt		#$RAMDISK/FILENAME is a text file. shellgei will be in this file and this script will share this file with docker container
				#シェル芸を記述するファイル名．dockerコンテナにディレクトリ共有で渡す．ホストでの絶対パスは$RAMDISK/$FILENAME
OUTPUT=output.txt		#A temporary text file of stdout. Not stderr. Path=$RAMDISK/$OUTPUT #シェル芸の実行結果の標準出力を格納するファイル．ホストでの絶対パスは$RAMDISK/$FILENAME
MAXLINE=100			#max lines of output. #シェル芸実行結果の最大行数．RocketChatに送信されるテキストの最大行数
TIMEOUTTIME=120			#Container's Lifespan. Born a container and Passes This time(seconds), kill the container  #実行の長いシェル芸の打ち切り時間．シェル芸ごとに新規のコンテナが生成されるが，この秒数以上は存在できない

COMMANDOLD=date			#Shellgei read one before. Shellgei's Buffer#前回実行したコマンドのバッファ．これと比較することで新しいシェル芸が入力されたか確認する．
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


MOUNTOK=0			#RAMDISK mount check num. Don't Touch #RAMDISKがマウント出来たかの確認．出来ないと1になる（はず）．
ps -A|grep docker >/dev/null 2>/dev/null	#dockerが起動しているかの確認
if [ $? != 0 ];then
	systemctl start dcoker			#dockerの起動．systemdではないシステムの場合は書き換えて．
fi

while true; do
	curl -s https://$URL/api/info > /dev/null 2>/dev/null	#サーバーとコネクションとれるかの確認
	if [ $? = 0 ];then					#Yes
		#シェル芸部分の読み取り
		COMMANDIS=`curl -s -H "X-Auth-Token:$TOKEN" -H "X-User-Id:$USERID" https://$URL/api/v1/chat.getMentionedMessages?roomId=$ROOMID|head -c 100000|sed 's/{"_id":"/\n/g'|head -n 30|sed -e '1d'|sed -z 's/"u":\n/"u":/g'|sed -z 's/"mentions":\[\n/"mentions":\[/g'|sed -e "/\"u\":$USERID/d"|head -n 1|sed s/^.*\"msg\":\"@shellgeibot\ //|sed 's/","ts":"20.*$//'|sed -e "s/\\\\\\\\\\\\\\\\/\\\\\\\\/g"|sed -e "s/\\\\\\\\\"/\"/g"`
		if [ "$COMMANDIS" != "$COMMANDOLD" ];then	#読み取ったシェル芸が一周前に実行したものと異なるかの確認．同じである場合実行されない．
			find $RAMDISK > /dev/null 2> /dev/null #RAMdisk用ディレクトリの存在確認
			if [ $? != 0 ];then
				mkdir -p $RAMDISK		#なければ作る
			fi
			df|grep ramdisk|grep $RAMDISK > /dev/null 2> /dev/null		#RAMdiskがマウントされているかの確認
			if [ $? = 0 ];then
				MOUNTOK=0

			else
				mount -t tmpfs -o size=10M ramdisk $RAMDISK		#されていなければRAMdiskをマウント サイズは10MBだけどご自由に
				MOUNTOK=$?
			fi
			echo $COMMANDIS > $RAMDISK/$FILENAME				#シェル芸をdockerコンテナに渡すファイルに書き込む
			COMMANDOLD=$COMMANDIS						#シェル芸を一周後に参照するためにバッファリング
			DOCKERPS=`date|base64|tr -d '='`	#make name of docker container from date command # dateコマンドのbase64エンコードをコンテナ名へ設定
			echo "sleep $TIMEOUTTIME && docker ps|grep $DOCKERPS > /dev/null && docker kill $DOCKERPS > /dev/null"|bash & #docker container kill command after Timeout #一定時間以上生き残っていたdocker コンテナを消す

			#シェル芸をdocker コンテナに渡して実行．コンテナはシェル芸終了後破棄
			docker run --rm --name $DOCKERPS --pids-limit 400 -v $RAMDISK:/images -w /images --net=none theoldmoon0602/shellgeibot /bin/bash -c "cat /images/$FILENAME|bash|head -n $MAXLINE" > $RAMDISK/$OUTPUT 2> /dev/null 
			while docker ps|grep $DOCKERPS > /dev/null 2> /dev/null;do	#dockerコンテナが生きているうちは先に進まないようにする．これがないと画像ファイル生成系シェル芸で正常に画像ファイルが出力されない事がある．
				sleep 1
			done
		
			#シェル芸実行による標準出力をRocket.Chatのトークルームに送信する．標準エラー出力については出力しない．
			curl -s -H "X-Auth-Token:$TOKEN" -H "X-User-Id:$USERID" -H "Content-type:application/json" https://$URL/api/v1/chat.postMessage -d " { \"roomId\" : \"$ROOMID\", \"text\": \"$(cat $RAMDISK/$OUTPUT|sed 's/\\/\\\\/g'|sed -e 's/$/\\n/g'|tr -d '\n')\"}" > /dev/null 2> /dev/null
			rm $RAMDISK/$FILENAME	#シェル芸のかかれたファイルの削除
			rm $RAMDISK/$OUTPUT	#シェル芸の結果のかかれたファイルの削除
			ls $RAMDISK|nl|grep 1 > /dev/null	#シェル芸により生成されたファイルの有無の確認．
			if [ $? = 0 ];then
				#複数のファイルが出力されても送信されるのはアルファベット順で最初の1ファイルのみ
				IMAGEFILE=`ls $RAMDISK|grep -v $FILENAME|grep -v $OUTPUT|head -n 1`
				curl "https://$URL/api/v1/rooms.upload/$ROOMID" -F file\=@$RAMDISK/$IMAGEFILE -F "msg=output file of shellgei" -F "description=Image from Shellgei" -H "X-Auth-Token: $TOKEN" -H "X-User-Id: $USERID" > /dev/null 2>/dev/null
			fi
			sleep 1
			umount $RAMDISK	#RAMdiskのアンマウント．毎周RAMdiskをマウントしなおすことで過去に実行したシェル芸のファイルが混入することを防ぐ
		fi
	else
		COMMANDIS=$COMMANDOLD	#サーバとコネクションがとれなかった場合，コマンドに過去のコマンドをコピーしておく．3行後の動作のため
	fi		
	sleep 5	#トークルームのメンションされたメッセージの取得周期
	COMMANDOLD=$COMMANDIS	#シェル芸をバッファリング
done
