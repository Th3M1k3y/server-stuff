<?php

$temp_min = 60;
$temp_max = 95;

$fan_min = 18;
$fan_max = 100;

$step_skip = 5;

$avg_force = 90;

$delay = 3;

$temp_mode = "max";

$temp_speed_file = "/tmp/fanspeed.txt";

$mode = 1; // 0 = Run, 1 = Debug, 2 = Develop

if ($mode < 2)
{
	shell_exec("modprobe ipmi_devintf");
	shell_exec("modprobe ipmi_si");
	shell_exec("ipmitool raw 0x30 0x30 0x01 0x00"); // Manual fan control
}
//shell_exec("ipmitool raw 0x30 0x30 0x01 0x01"); // Auto fan control

$fan_speed_old = 64;

if (file_exists($temp_speed_file))
{
	if (time()-filemtime($temp_speed_file) < ($delay+2))
	{
		if ($mode < 2)
		{
			die(PHP_EOL . "Script is already running (file)" . PHP_EOL);
		}
		else
		{
			echo PHP_EOL . "Script is already running" . PHP_EOL;
		}
	}
	
	$input = shell_exec("ps -x | grep fanspeed.php");
	$input = explode("\n", $input);
	$matches = 0;
	
	foreach($input as $line)
	{
		$filepath = __FILE__;
		$filepath = str_replace("/", "\/", $filepath);
		
		preg_match_all('/php\s' . $filepath . '/ms', $line, $match);		
		
		if (count($match[0]) > 0)
		{
			$matches++;
		}
	}
	
	if ($matches > 1)
	{
		if ($mode < 2)
		{
			die(PHP_EOL . "Script is already running (ps)" . PHP_EOL);
		}
		else
		{
			echo PHP_EOL . "Script is already running (ps)" . PHP_EOL;
		}
	}
	
	echo $matches;
	$tmp_file = fopen($temp_speed_file, "r");
	$fan_speed_old = trim(fgets($tmp_file));
	fclose($tmp_file);
}

while (true)
{
	$input = shell_exec("sensors -j");
	
	preg_match_all('/Core.*temp\d(_input":)\s(\d{2})/msU', $input, $matches);

	$total_temp = 0;
	
	switch($temp_mode)
	{
		case "avg": // Return an average temperature of all cores
			foreach ($matches[2] as $temp)
			{
				$total_temp += $temp;
			}
			$avg_temp = $total_temp/count($matches[2]);
			break;
		default: // Return the highest core temperature found
			foreach ($matches[2] as $temp)
			{
				if ($total_temp < $temp) $total_temp = $temp;
			}
			$avg_temp = $total_temp;
	}

	// Calculate new fan speed	
	$fan_speed = ($avg_temp-$temp_min)*($fan_max-$fan_min)/($temp_max-$temp_min)+$fan_min;
	
	// Make sure fan speed stay within the set limits
	if ($fan_speed < $fan_min) $fan_speed = $fan_min;
	if ($fan_speed > $fan_max) $fan_speed = $fan_max;
	
	$force_avg = false;
	$force_type = "Step";
	
	if ($fan_speed < $fan_speed_old)
	{
		$force_avg = true;
	}
	
	if (abs($fan_speed - $fan_speed_old) <= $step_skip || $force_avg)
	{
		$force_type = "Averaging";
		
		$c_force = $avg_force/100;		
		$old = ($fan_speed_old*1000)*$c_force;
		
		$c_force = 1-$c_force;
		$new = ($fan_speed*1000)*$c_force;
		
		$fan_speed = ($old+$new)/1000;
	}
	
	$fan_speed = $fan_speed;
	
	// Make sure fan speed stay within the set limits
	if ($fan_speed < $fan_min) $fan_speed = $fan_min;
	if ($fan_speed > $fan_max) $fan_speed = $fan_max;
	
	// Remember the setting we are going to use	
	$fan_speed_old = $fan_speed;
	
	$fan_speed_used = round($fan_speed, 0);

	if ($mode < 2)
	{
		// Set fan speed
		$output = shell_exec("ipmitool raw 0x30 0x30 0x02 0xff 0x" . dechex($fan_speed_used) . " > /dev/null 2>&1"); // Set speed
	}
	
	$tmp_file = fopen($temp_speed_file, "w") or die("Unable to open file!");
	fwrite($tmp_file, $fan_speed_old);
	fclose($tmp_file);
	
	$time_start = microtime(true); 
	$input_rpm = shell_exec("timeout 2 ipmitool sensor");
	$time_end = microtime(true);
	
	$ipmi_time = round($time_end - $time_start, 0);
	
	echo $execution_time;
	
	$input_rpm = explode("\n", $input_rpm);
	
	$input_rpm_count = 0;
	$input_rpm_total = 0;
	
	foreach ($input_rpm as $key=>$value)
	{		
		if (substr($value, 0, 3) == "FAN")
		{
			$input_rpm_count++;
			$input_rpm = explode("|", $value);			
			$input_rpm_total += $input_rpm[1];
		}
	}
	
	if ($input_rpm_count > 0)
	{
		$input_rpm_total /= $input_rpm_count;
	}

	if ($mode > 0)
	{
		echo "Time: ". date("h:i:s") . PHP_EOL;
		echo "Mode: " . $force_type . PHP_EOL;
		echo "Cores found: " . count($matches[2]) . PHP_EOL;
		echo "Temperature: " . $avg_temp . "c" . PHP_EOL;
		echo "Fan speed: " . $fan_speed_used . "% (" . round($fan_speed, 2) . ")" . PHP_EOL;
		echo "Fan RPM: " . $input_rpm_total . PHP_EOL . PHP_EOL;
	}
	sleep($delay-$ipmi_time);
}
?>
