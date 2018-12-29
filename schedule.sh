#!/bin/bash

####################

min_el=20
dir=/home/franchini/Satellite
where=$dir/code/ravenna.qth #frilsham.qth
predict=$dir/predict/predict

####################

cd $dir/code
rm -r passages.*

# Update Satellite Information
echo "Update Satellite Information..."
wget -qr https://www.celestrak.com/NORAD/elements/weather.txt -O weather.txt
if [ "$?" -eq "0" ]; then
    grep "NOAA 15" weather.txt -A 2 > weather.tle
    grep "NOAA 18" weather.txt -A 2 >> weather.tle
    grep "NOAA 19" weather.txt -A 2 >> weather.tle
    grep "METEOR-M 2" weather.txt -A 2 >> weather.tle
    rm -rf weather.txt
    echo "...done"
else
    echo "...no network"
fi

echo -e "\nMinimum elevation:" $min_el

today=`date +'%Y%m%d'`

for sat in "NOAA 15" "NOAA 18" "NOAA 19" "METEOR-M 2"; do
    
    time=`date +%s`
    
    while [ `date -d @$time +%Y%m%d` -eq "$today" ]; do
	
	max_el=0
	max_el=`$predict -q $where -t weather.tle -p "${sat}" "$time" | awk '{if($5>max){max=$5}}END{print max}'`
	if [[ -n "$max_el" ]] && [[ "$max_el" -gt "$min_el" ]]; then

	    # Acquisition of Signal - Lost of Signal
	    AOS=`$predict -q $where -t weather.tle -p "${sat}" "$time" | head -1 | awk '{print $1 " " $3 " " $4}'`
	    LOS=`$predict -q $where -t weather.tle -p "${sat}" "$time" | tail -1 | awk '{print $1 " " $3 " " $4}'`

	    # Day of the passage
	    day=`$predict -q $where -t weather.tle -p "${sat}" "$time" | head -1 | awk '{print $1}'`

	    # saves only the passages in the current day
	    if [ `date --date=@${day} +%Y%m%d` -eq "$today" ]; then
		echo -e $AOS " " $LOS " " $sat "\t" $max_el >> passages.tmp
	    fi
	    
	fi
	
	end_time=`$predict -q $where -t weather.tle -p "${sat}" "$time" | tail -1 | awk '{print $1}'`
	
	time=$[$end_time+60]

    done

done

if [ -f passages.tmp ]; then

    echo -e "\nStart                         Stop                          Satellite \t Max El"
    echo    "==============================================================================="
    sort passages.tmp | uniq > passages.txt
    rm passages.tmp

    # Remove old 'at' jobs
    for i in `atq | awk '{print $1}'`; do atrm $i; done
    
    # Submit jobs
    while read line; do
	
	echo "$line"
	
	# pass the unix time
	sat=`echo $line | awk '{print $7 " " $8}'`
	start=`echo $line | awk '{print $1}'`
	stop=`echo $line | awk '{print $4}'`
	elevation=`echo $line | awk '{print $9}'`

	source submit_job.sh $sat $start $stop $elevation &>> jobs.log

    done < passages.txt

    less recordings.log | sort | uniq > recordings.tmp
    mv recordings.tmp recordings.log
    
else
    echo -e "\nNo passages for today"
fi


echo " "

