<?php

$temp_min = 45;
$temp_max = 85;

$fan_min = 20;
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
	if (time()-filemtime($temp_speed_file) < $delay)
	{
		die("Script is already running");
	}

	$tmp_file = fopen($temp_speed_file, "r");
	$fan_speed_old = trim(fgets($tmp_file));
	fclose($tmp_file);
}

while (true)
{
	$input = shell_exec("sensors -j");
	
	preg_match_all('/temp\d{1,2}(_input":)\s(\d{2})/msU', $input, $matches);

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

	if ($mode > 0)
	{
		echo "Time: ". date("h:i:s") . PHP_EOL;
		echo "Mode: " . $force_type . PHP_EOL;
		echo "Cores found: " . count($matches[2]) . PHP_EOL;
		echo "Temperature: " . $avg_temp . "c" . PHP_EOL;
		echo "Fan speed: " . $fan_speed_used . "% (" . round($fan_speed, 2) . ")" . PHP_EOL . PHP_EOL;
	}
	sleep($delay);
}
?>
