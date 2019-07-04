#!/bin/bash

temp_min=50
temp_max=95

fan_min=12
fan_max=100

# Percentage of the old reading which will be used to calculate the new fan speed
force=90

# Seconds between each reading
delay=3

# Average only when difference is less than
avg_skip=20

echo "Fan control started"

fan_speed_old=64

if [ -f "/tmp/last_speed" ]; then
    fan_speed_old=$(sed -n '1p' < "/tmp/last_speed")
	echo "Last speed was $fan_speed_old"
fi

# Enable manual control
modprobe ipmi_devintf
modprobe ipmi_si
ipmitool raw 0x30 0x30 0x01 0x00 > /dev/null 2>&1

while true; do
	temp=`sensors | grep "CPU Temp"`
	temp=${temp:15:2}
	
	echo "CPU Temp: $temp"
	
	if [[ $temp = *[[:digit:]]* ]]; then
		# Temperature is a number, so we can use it to calculate speed
		fan_speed=$((($temp-$temp_min)*($fan_max-$fan_min)/($temp_max-$temp_min)+$fan_min))
	else
		# Something went wrong when getting temperature, set fans to max to be safe
		echo -e "Temperature does not look like a number, setting fans to max!"
		fan_speed=$fan_max
	fi
	
	if [[ $fan_speed -lt $fan_min ]]; then
		fan_speed=$fan_min
	elif [[ $fan_speed -gt $fan_max ]]; then
		fan_speed=$fan_max
	fi
	
	res=$(echo "$fan_speed-$fan_speed_old" | bc)
	
	if [[ "$res" -lt 0 ]] ; then
		res=$(echo `expr 0 - $res`)
	fi
	
	if [[ $res -lt $avg_skip ]]; then
		echo "Method: Averaging"
		cforce=$(echo "scale=4;$force/100" | bc -l)
		old=$(echo "scale=4;($fan_speed_old*1000)*$cforce" | bc -l)
		
		cforce=$(echo "scale=4;1-$cforce" | bc -l)
		new=$(echo "scale=4;($fan_speed*1000)*$cforce" | bc -l)
		
		fan_speed=$(echo "scale=0;$old+$new" | bc -l)
		fan_speed=$(echo "scale=0;$fan_speed/1000" | bc -l)
		
		fan_speed=$(echo "($fan_speed+0.5)/1" | bc) # Convert float to int
	else
		echo "Method: Jump"
	fi
	
	if [[ $fan_speed -lt $fan_min ]]; then
		fan_speed=$fan_min
	elif [[ $fan_speed -gt $fan_max ]]; then
		fan_speed=$fan_max
	fi
	
	fan_speed_old=$fan_speed
	
	echo -e "Fan speed: $fan_speed"
	
	fan_speed_hex=`echo "obase=16; $fan_speed" | bc`
	cmd="0x30 0x30 0x02 0xff 0x$fan_speed_hex"
	echo "Command: $cmd"

	# Set fan speed
	ipmitool raw $cmd > /dev/null 2>&1
	
	current=$(date +"%S")
	current=$(echo $current | sed 's/^0*//')
	if [[ $current -gt 51 ]]; then
		echo $fan_speed_old > /tmp/last_speed
		sleep 1
		exit
	fi
	
	echo -e ""
	
	sleep $delay
done
