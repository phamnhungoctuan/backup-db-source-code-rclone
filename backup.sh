#!/bin/bash
SERVER_NAME=backup

TIMESTAMP=$(date +"%F")
BACKUP_DIR="/root/backup/$TIMESTAMP"
MYSQL=/usr/bin/mysql
MYSQLDUMP=/usr/bin/mysqldump
BACKUP_PATH=/var/www
SECONDS=0
domainRegex="^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.)+[a-zA-Z]{2,}$"


mkdir -p "$BACKUP_DIR/mysql"

echo "Starting Backup Database";
databases=`$MYSQL -e "SHOW DATABASES;" | grep -Ev 
"(Database|information_schema|performance_schema|mysql)"`

for db in $databases; do
    echo "- "$db;
	$MYSQLDUMP --force --opt $db | gzip > "$BACKUP_DIR/mysql/$db.gz"
done
echo "Finished";
echo '';

echo "Starting Backup Website";
for D in "$BACKUP_PATH/*"; do
	if [[ -d "${D}" && "${D##*/}" =~ $domainRegex ]]; then
		domain=${D##*/}
		echo "- "$domain;
		zip -r $BACKUP_DIR/$domain.zip $BACKUP_PATH/$domain/ -q -x *.git* node_modules/**\* 
vendor/**\*
	fi
done
echo "Finished";
echo '';

#Backup nginx config
echo "Starting Backup Nginx Configuration";
cp -r /etc/nginx/conf.d/ $BACKUP_DIR/nginx/
echo "Finished";
echo '';
size=$(du -sh $BACKUP_DIR | awk '{ print $1}')

echo "Starting Uploading Backup";
/usr/bin/rclone move $BACKUP_DIR "$SERVER_NAME:$SERVER_NAME/$TIMESTAMP" >> /var/log/rclone.log 2>&1
# Clean up
rm -rf $BACKUP_DIR
/usr/bin/rclone  -q --min-age 2w delete "$SERVER_NAME:$SERVER_NAME" #Remove all backups older than 2 week
/usr/bin/rclone  -q --min-age 2w rmdirs "$SERVER_NAME:$SERVER_NAME" #Remove all empty folders older than 2 
week
/usr/bin/rclone cleanup "$SERVER_NAME:" #Cleanup Trash
echo "Finished";
echo '';
#Upload is finished
duration=$SECONDS
echo "Total $size, $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
