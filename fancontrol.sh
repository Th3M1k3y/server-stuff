#!/bin/bash
 
temp_min=50
temp_max=95
 
fan_min=10
fan_max=100
 
# Percentage of the old reading which will be used to calculate the new fan speed
force=90
 
# Seconds between each reading
delay=3
 
# Average only when difference is less than
avg_skip=8
 
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
    temp=`sensors | grep "CPU Temp" | sed 's/.*:\s*+\(.*\)  .*(.*/\1/'`
    temp=${temp::-4}
     
    echo "CPU Temp: $temp"
     
    fan_speed=$((($temp-$temp_min)*($fan_max-$fan_min)/($temp_max-$temp_min)+$fan_min))
     
    res=$(echo "$fan_speed-$fan_speed_old" | bc)
     
    if [[ "$res" -lt 0 ]] ; then
        res=$(echo `expr 0 - $res`)
    fi
     
    if [[ $res -lt $avg_skip ]]; then
        echo " Averaging:"
        cforce=$(echo "scale=2;$force/100" | bc)
        old=$(echo "scale=2;$fan_speed_old*$cforce" | bc -l)
        echo -e "  Old speed $old"
         
        cforce=$(echo "scale=2;1-$cforce" | bc)
        new=$(echo "scale=2;$fan_speed*$cforce" | bc -l)
        echo -e "  New speed $new"
         
        fan_speed=$(echo "scale=0;$old+$new" | bc)
        fan_speed=$(echo "($fan_speed+0.5)/1" | bc )
        echo -e "  Fan speed: $fan_speed"
    fi
     
    fan_speed_old=$fan_speed
     
    if [[ $fan_speed -lt $fan_min ]]; then
        fan_speed=$fan_min
    elif [[ $fan_speed -gt $fan_max ]]; then
        fan_speed=$fan_max
    fi
     
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
