#!/bin/bash
MYSQL_HOST=localhost
MYSQL="/usr/bin/mysql --defaults-file=/etc/mysql/debian.cnf"
MYSQLDUMP="/usr/bin/mysqldump --defaults-file=/etc/mysql/debian.cnf"

## BACKUP INSTELLINGEN / AANTAL DAGEN BEWAREN / MYSQL BIN PATH / BACKUP PATH
MYSQL_DAYS=7
MYSQL_PATH=/usr/bin/
BACKUP_PATH=/home/mysql/backup
REMOTE_BACKUP_PATH=/stack/mysql
BACKUP_ERRLOG=/var/log/backup/backup.error
BACKUP_LOG=/var/log/backup/backup.log
TAR_LOG=/var/log/backup/tar.log
MAIL_PROG=/usr/bin/mail
MAIL_ADDRESS=linux@example.com


## NIET EDITEN
# IO redirection for logging.
touch $BACKUP_LOG
exec 6>&1 # Link file descriptor #6 with stdout.
# Saves stdout.
exec > $BACKUP_LOG # stdout replaced with file $BACKUP_LOG.

touch $BACKUP_ERRLOG
exec 7>&2 # Link file descriptor #7 with stderr.
# Saves stderr.
exec 2> $BACKUP_ERRLOG # stderr replaced with file $BACKUP_LOG.
START="`date +%d-%b-%Y` `date +%H:%M:%S`"

touch $TAR_LOG

DAY=1440
DAY=$(($DAY*$MYSQL_DAYS))
echo "Backup databases..."
DBS=`$MYSQL -h$MYSQL_HOST -e"show databases"`

for DATABASE in $DBS
do
       if [ $DATABASE != "Database" ]; then
               FILENAME=`hostname -f`-`date +%b-%d-%Y-%H:%M:%S`-$DATABASE.sql
               $MYSQLDUMP --single-transaction --master-data=1 --ignore-table=mysql.event -h$MYSQL_HOST $DATABASE  > $BACKUP_PATH/mysql/$FILENAME

              # $MYSQL_PATH/mysqldump --defaults-file=/etc/mysql/debian.cnf -A --add-drop-database --events --master-data=1 --single-transaction --quick 2> /tmp/backupfoutmelding > $BACKUP_PATH/mysql/$FILENAME
               /bin/tar -czPf $BACKUP_PATH/mysql/$FILENAME.tar.gz $BACKUP_PATH/mysql/$FILENAME
               /bin/tar -tvPf $BACKUP_PATH/mysql/$FILENAME.tar.gz > $TAR_LOG
               if [ -s $TAR_LOG ]
               then
               rm $BACKUP_PATH/mysql/$FILENAME
               #/usr/bin/rsync --bwlimit=1500 -az $BACKUP_PATH/mysql/$FILENAME.tar.gz $REMOTE_BACKUP_PATH
               #/bin/cp $BACKUP_PATH/mysql/$FILENAME.tar.gz $REMOTE_BACKUP_PATH
               fi
               echo "DATABASE $DATABASE"
       fi
done

## OUDE BESTANDEN VERWIJDEREN
/usr/bin/find $BACKUP_PATH/mysql/ -mmin +$DAY -exec /bin/rm -r {} \;
#/usr/bin/find $REMOTE_BACKUP_PATH -mmin +$DAY -exec /bin/rm -r {} \;
exec 1>&6 6>&- # Restore stdout and close file descriptor #6.
exec 1>&7 7>&- # Restore stdout and close file descriptor #7.
END="`date +%d-%b-%Y` `date +%H:%M:%S`"


if [ -s "$BACKUP_ERRLOG" ]
then
echo >> $BACKUP_ERRLOG
echo Client: \"`hostname`\" >> $BACKUP_ERRLOG
echo Termination: failed >> $BACKUP_ERRLOG
echo Start time: $START >> $BACKUP_ERRLOG
echo End time: $END >> $BACKUP_ERRLOG
SUBJECT="MySQL: Backup failed of server `hostname`"
$MAIL_PROG -s "$SUBJECT" "$MAIL_ADDRESS" < $BACKUP_ERRLOG
else
echo >> $BACKUP_LOG
echo Client: \"`hostname`\" >> $BACKUP_LOG
echo Termination: Backup OK>> $BACKUP_LOG
echo Start time: $START >> $BACKUP_LOG
echo End time: $END >> $BACKUP_LOG
echo Backup files stored in $BACKUP_PATH/mysql >> $BACKUP_LOG
SUBJECT="MySQL: Backup OK of server `hostname`"
$MAIL_PROG -s "$SUBJECT" "$MAIL_ADDRESS" < $BACKUP_LOG
fi
