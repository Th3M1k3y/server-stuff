import os, time, os.path
from datetime import datetime

#os.system('modprobe ipmi_devintf')
#os.system('modprobe ipmi_si')
os.system('ipmitool raw 0x30 0x30 0x01 0x00') # Manual fan control

temp_min = 45
temp_max = 85

fan_min = 20
fan_max = 100

reading_delay = 2 # Seconds between readings

temp_last = 100

if os.path.exists('/tmp/fanspeed'):
    f=open("/tmp/fanspeed", "r")
    if f.mode == 'r':
        temp_last=int(f.read())

def cpu_temp():
    temps = os.popen('sysctl dev.cpu | grep temperature').read()
    mylist = temps.split("\n")
    l_cpu_temp = 0
    for temp in mylist:
        output = temp.split(" ")
        try:
            core_temp = int(output[1][:-3])
            if core_temp > l_cpu_temp:
                l_cpu_temp = core_temp
        except IndexError:
            continue
            
    if l_cpu_temp < 20:
        l_cpu_temp = 100
    return l_cpu_temp
    
def set_fan(temperature):
    fan_speed = int((temperature-temp_min)*(fan_max-fan_min)/(temp_max-temp_min)+fan_min)
    if fan_speed < fan_min:
        fan_speed = fan_min
    if fan_speed > fan_max:
        fan_speed = fan_max
    os.system('ipmitool raw 0x30 0x30 0x02 0xff ' + hex(fan_speed) + ' > /dev/null 2>&1')

while True:
    temp = cpu_temp()
    print("CPU Temp: " + str(temp))
    set_fan(temp)
       
    curr_time = datetime.now()
    current_second = int(curr_time.strftime('%S'))
    if (current_second >= 60-reading_delay):
        f = open("/tmp/fanspeed","w+")
        f.write(str(temp))
        f.close() 
        exit()
    
    time.sleep(reading_delay)

#os.system('ipmitool raw 0x30 0x30 0x01 0x01') # Auto fan control
