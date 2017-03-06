log="/tmp/softwareupdate.log"

if [ ! -e $log ]
then
 touch $log
fi

crontab="/etc/crontab"

if [ -e $crontab ]
then
 if grep /usr/sbin/softwareupdate $crontab
  then
   echo entry exist waiting for cron to run.
 else
   echo "30 * * * * root /usr/sbin/softwareupdate -l &> $log" >> $crontab
 fi
else
 echo "SHELL=/bin/sh" > $crontab
 echo "PATH=/bin:/sbin:/usr/bin:/usr/sbin" >> $crontab
 echo "30 * * * * root /usr/sbin/softwareupdate -l &> $log" >> $crontab
fi

/usr/bin/tail -1 $log
