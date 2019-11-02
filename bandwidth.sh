#!/bin/bash

## FIBER
echo "Fiber"
TIME=10
IP="192.168.1.167"
COMMUNITY="public"
PORT=1

# NETGEAR
#INSTRING="snmpget -v2c -c $COMMUNITY $IP 1.3.6.1.2.1.31.1.1.1.6.$PORT"
#OUTSTRING="snmpget -v2c -c $COMMUNITY $IP 1.3.6.1.2.1.31.1.1.1.10.$PORT"

#UNIFI Switch 8
OUTSTRING="snmpget -v2c -c $COMMUNITY $IP iso.3.6.1.2.1.2.2.1.16.$PORT"
INSTRING="snmpget -v2c -c $COMMUNITY $IP iso.3.6.1.2.1.2.2.1.10.$PORT"

#USG
#INSTRING="snmpget -v2c -c $COMMUNITY 192.168.1.1 iso.3.6.1.2.1.2.2.1.10.2"
#OUTSTRING="snmpget -v2c -c $COMMUNITY 192.168.1.1 iso.3.6.1.2.1.2.2.1.10.3"

OUTTOTAL=0
INTOTAL=0
SAMPLES=0

for i in {1..5}
do
	OUT=$($OUTSTRING | awk '{print $4}')
	IN=$($INSTRING | awk '{print $4}')

	if [ -z "$OUT" ] || [ -z "$IN" ]; then
		echo "Unable to retrieve SNMP info."
		exit 2
	else
		#wait $TIME before running the same check, this way we can confirm how much the data has changed in two periods.
		sleep $TIME
		OUT2=$($OUTSTRING | awk '{print $4}')
		IN2=$($INSTRING | awk '{print $4}')
		DELTAOUT=$(($OUT2-$OUT))
		DELTAIN=$(($IN2-$IN))
		#Value is in octets so will need to be multiplied by 8 to get bytes, this is then divided by 1000 to give kilobytes.
		INPUTBW=$(((($DELTAIN)/$TIME)*8/1000))
		OUTPUTBW=$(((($DELTAOUT)/$TIME)*8/1000))
		#Convert kbps into Mbps
		INPUTBW=$(echo "scale=2; $INPUTBW/1000" | bc)
		OUTPUTBW=$(echo "scale=2; $OUTPUTBW/1000" | bc)

		if [ "$OUT" -ge "$OUT2" ] || [ "$IN" -ge "$IN2" ]; then
			echo "Overflow of a counter - Inbound: $INPUTBW"Mbps", Outbound: $OUTPUTBW"Mbps
		else
			OUTTOTAL=$(echo "scale=2; $OUTTOTAL+$OUTPUTBW" | bc)
			INTOTAL=$(echo "scale=2; $INTOTAL+$INPUTBW" | bc)
			SAMPLES=$(($SAMPLES+1))
			echo "Sample $SAMPLES": Inbound: $INPUTBW"Mbps", Outbound: $OUTPUTBW"Mbps"
		fi
	fi
done

if [ "$SAMPLES" -gt 0 ]; then
	OUTPUTBW=$(echo "scale=2; $OUTTOTAL/$SAMPLES" | bc)
	INPUTBW=$(echo "scale=2; $INTOTAL/$SAMPLES" | bc)
	echo "Total: Inbound: $INPUTBW"Mbps", Outbound: $OUTPUTBW"Mbps based on $SAMPLES samples.

	resultin=$(echo "$INPUTBW * 100" |bc -l)
	resultout=$(echo "$OUTPUTBW * 100" |bc -l)

	resultin=${resultin/.*}
	resultout=${resultout/.*}

	if [ "$resultin" -ge 0 ] && [ "$resultout" -ge 0 ]; then
		echo "Publishing..."
    
    # Send result over MQTT
		#mosquitto_pub -t '/lan/wan/in' -m $INPUTBW
		#mosquitto_pub -t '/lan/wan/out' -m $OUTPUTBW
		
    # Post result to influxdb
		#curl -i -XPOST 'http://192.168.1.100:8086/write?db=netstat' --data-binary "bw,direction=in value=$INPUTBW"
		#curl -i -XPOST 'http://192.168.1.100:8086/write?db=netstat' --data-binary "bw,direction=out value=$OUTPUTBW"
	else
		echo "Error calculating bandwidth."
	fi
else
	echo "No usable samples."
fi
