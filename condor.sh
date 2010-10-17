#!/bin/sh 
#set -x 

# Code (c) Greg Nokes under GPL 2 or later 
# greg (at) nokes (dot) name 
#Pinger 2.0a GNokes 10/7/05. Took original code, cleaned up. 
#3.0.1 10/18/05 added mail.cfg and re-wrote callhome() to use it; also cleaned up code a wee bit 
#3.0.2 10/18/05 removed path from config files 
#3.0.3 10/18/05 readded path to config files 
# #3.1.1 10/19/05 removed two call homes - program only calls home when host is down, comes up. 
#3.2 10/31/05 Need to follow one email directive 
#3.3 11/02/05 Need to have email sent only after host down on second cycle; added safteynet 
#3.3.1 11/03/05 Added MAILGATE, changed all paths to belfry. Moved exectution to belfry. 
#3.4 9/16/10 Started to use BASE to set the base directory to local. Change BASE to change execution directory

########### # Defines # ########### 
BASE=. 
TEMP=$BASE/tmp/condor.tmp 
LOG=$BASE/log/condor.log
TRACK=$BASE/log/condordown.log 
SITE=`cat $(BASE)/site.cfg` 
TOAST=$BASE/tmp/condor.toast 
ML=`cat $(BASE)/mail.cfg` 
RPT=$BASE/tmp/condor.rpt 
MAILGATE= 

############# # Functions # ############# 
# All of my functions go here 
PING () { 
# Do Pinging and write to Logfile 
# Also check for previous down state, ignore if site was up 
# callhome with down if site down, callhome with up if site came back up  
for i in $SITE do 
	if ! ping -c 3 -w 5 $i>/dev/null then 
		echo $i:noping 
		printf "Host:\tDown\t$i\t$(date)\n">>$LOG 
		if [ -e "/tmp/$i.ping.dropped" ] 
		then 
			echo $i:down 
			CALLHOME $i Down 
			rm /tmp/$i.ping* 
			touch /tmp/$i.ping.no 
			printf "Host:\tDown\t$i\t$(date)\n">>$TRACK 
		elif [ -e "/tmp/$i.ping.yes" ] 
		then 
			echo $i:dropped rm /tmp/$i.ping* 
			touch /tmp/$i.ping.drop 
			printf "Host:\tDropped\t$i\t$(date)\n">>$TRACK 
		else 
			echo $i:dropped rm /tmp/$i.ping* 
			touch /tmp/$i.ping.drop 
			printf "Host:\tDropped\t$i\t$(date)\n">>$TRACK 
		fi 
	else 
		if [ -e "/tmp/$i.ping.no" ] 
		then 
			echo $i:back CALLHOME $i Up 
			printf "Host:\tUp\t$i\t$(date)\n">>$TRACK 
			printf "Host:\tUp\t$i\t$(date)\n">>$LOG 
		elif [ -e "/tmp/$i.ping.drop" ] 
		then 
			echo $i:back 
			printf "Host:\tUp\t$i\t$(date)\n">>$LOG 
			printf "Host:\tUp\t$i\t$(date)\n">>$TRACK
		elif [ -e "/tmp/$i.ping.yes" ] 
		then 
			printf "Host:\t\t$i\t$(date)\n">>$LOG 
		fi 
		echo $i:pingcheck 
		rm /tmp/$i.ping* 
		touch /tmp/$i.ping.yes 
	fi 
done 
}  

CALLHOME () { 
#Build the Report  
printf "$1 $2\n">> $RPT  
}  

MAILER () { 
# Check to see if we can get to the gateway 
if ping -c 6 -w 10 $MAILGATE>/dev/null then 
	#Yup - proceed 
	for m in $ML do cat $RPT | mail -s "Condor Report" $m 
	done
else 
	# Uh-oh. We have a problem! 
	# In a perfect world we would dial out with a modem 
	printf "ALERT ALERT ALERT ALERT ALERT $(date) CANNOT SEND MAIL\n">>$LOG 
	printf "ALERT ALERT ALERT ALERT ALERT $(date) CANNOT SEND MAIL\n">>$TRACK 
	# Write a temp file so we can tell next cycle that we had a problem 
	touch $TOAST  
fi  
}  

MCP () {  
# Master Control Program  
# Initial housekeeping 
mv $TEMP /tmp/condor2.tmp touch $TEMP>/dev/null 
# We need to create the file, so the delete does not throw an error 
touch $RPT rm $RPT>/dev/null  
# Write cool line to log 
echo " =========================================================================">> $LOG  
# Run Ping Checks on all target hosts 
PING  
# Did we have a major problem last cycle? 
if [ -e "$TOAST" ] then 
	printf "ALERT ALERT ALERT ALERT ALERT $(date) Main Site BACK!!\n">>$RPT 
	rm $TOAST 
fi  
# If we have something to report, then send it off 
if [ -e "$RPT" ] then MAILER 
fi 
} 

########### # Program # ########### 
 
MCP>>$TEMP