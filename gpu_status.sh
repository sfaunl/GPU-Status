#!/bin/sh
nvidia(){
	pciaddr="$1"
	gpuName="$2"
	gpuModel="$3"
	
	GPU_runtime_status=$(<"/sys/bus/pci/devices/$pciaddr/power/runtime_status")
	GPU_power_state=$(</sys/bus/pci/devices/$pciaddr/power_state)

	txtstr=$txtstr"NVIDIA: "
	
	fallback=1
	# check if nvidia gpu is sleeping.
	if [[ $GPU_power_state == "D0" ]]
	then
		# check if nvidia-smi exists
		if command -v nvidia-smi &> /dev/null
		then
			fallback=0
			
			# get nvidia gpu status
			nvidiasmi=`nvidia-smi --format=csv,noheader --query-gpu=name,power.draw,pstate,utilization.gpu,memory.total,memory.used,clocks.max.graphics,clocks.current.graphics,clocks.max.memory,clocks.current.memory,pcie.link.gen.max,pcie.link.gen.current,temperature.gpu`
			# TODO: not handling errors!!!
			arrIN=(${nvidiasmi//,/ })
			gpuname=${arrIN[0]}   
			gpuname1=${arrIN[1]}   
			power=${arrIN[2]}   
			powerunit=${arrIN[3]}   
			pstate=${arrIN[4]}  
			gpuutil=${arrIN[5]}  
			gpuutilunit=${arrIN[6]}  
			memtotal=${arrIN[7]}
			memunit=${arrIN[8]}
			memused=${arrIN[9]}
			memperc=$(($memused * 100 / $memtotal))
			maxgrfreq=${arrIN[11]}
			frequnit=${arrIN[12]}
			curgrfreq=${arrIN[13]}
			maxmemfreq=${arrIN[15]}
			curmemfreq=${arrIN[17]}
			maxpciegen=${arrIN[19]}
			curpciegen=${arrIN[20]}
			gputemp=${arrIN[21]}
			
			# get active processes running on gpu
			nvidiasmipmon=`nvidia-smi pmon -i 0 -s um -c 1`

			IFS=$'\t\n'
			proc_list=($nvidiasmipmon)
			apps=""
			for proc in "${proc_list[@]:2}"
			do  
				IFS=$' '
				arrIN=(${proc})
				name=${arrIN[8]}
				pid=${arrIN[1]}
				type=${arrIN[2]}
				sm=${arrIN[3]}
				mem=${arrIN[4]}
				enc=${arrIN[5]}
				dec=${arrIN[6]}
				fb=${arrIN[7]}
				apps=$apps"$name ($type)|$sm% $mem% $enc% $dec% $fbMB"$'\n'
			done
			
			# print status info
			txtstr=$txtstr"$pstate $power $powerunit"$'\n'
			toolstr=$toolstr"GPU:|$gpuname $gpuname1"$'\n'
			toolstr=$toolstr"PCIe power state:|$GPU_power_state"$'\n'
			toolstr=$toolstr"PCIe gen:|$curpciegen/$maxpciegen"$'\n'
			toolstr=$toolstr"GPU pstate:|$pstate"$'\n'
			toolstr=$toolstr"Power:|$power $powerunit"$'\n'
			toolstr=$toolstr"Temp:|$gputemp C"$'\n'
			toolstr=$toolstr"Utilization:|$gpuutil $gpuutilunit"$'\n'
			toolstr=$toolstr"Memory:|$memused/$memtotal $memunit ($memperc%)"$'\n'
			toolstr=$toolstr"Core:|$curgrfreq/$maxgrfreq $frequnit"$'\n'
			toolstr=$toolstr"Mem:|$curmemfreq/$maxmemfreq $frequnit"$'\n'
			toolstr=$toolstr" | "$'\n'
			toolstr=$toolstr"Active processes:|(sm,mem,enc,dec,fb)"$'\n'
			toolstr=$toolstr"$apps"$'\n'
		fi
	fi

	# nvidia gpu is not running. print pci info
	if [[ $fallback == 1 ]]
	then
		txtstr=$txtstr"$GPU_power_state"$'\n'
		
		toolstr=$toolstr"GPU:|$gpuName"$'\n'
		toolstr=$toolstr"|$gpuModel"$'\n'
		toolstr=$toolstr"Status:|$GPU_runtime_status ($GPU_power_state)"$'\n'
	fi

	toolstr=$toolstr"-----------------|-----------------"$'\n'
}

intel(){
	pciaddr="$1"
	gpuName="$2"
	gpuModel="$3"
	
	GPU_runtime_status=$(</sys/bus/pci/devices/$pciaddr/power/runtime_status)
	GPU_power_state=$(</sys/bus/pci/devices/$pciaddr/power_state)
	
	GPU_curfreq=$(</sys/bus/pci/devices/$pciaddr/drm/card0/gt_cur_freq_mhz)
	GPU_maxfreq=$(</sys/bus/pci/devices/$pciaddr/drm/card0/gt_max_freq_mhz)

	txtstr=$txtstr"INTEL: $GPU_power_state"$'\n'
	
	fallback=1
	# check if intel gpu is running.
	if [[ $GPU_power_state == "D0" ]]
	then
		# check if intel_gpu_top exists
		if command -v intel_gpu_topx &> /dev/null
		then
			fallback=0
			# get intel gpu status
			intelgputop=`intel_gpu_top -h`
			# TODO: intel_gpu_top requires root privileges
		fi
	fi
	
	# intel gpu is not running. print pci info
	if [[ $fallback == 1 ]]
	then
		toolstr=$toolstr"GPU:|$gpuName"$'\n'
		toolstr=$toolstr"|$gpuModel"$'\n'
		toolstr=$toolstr"Status:|$GPU_runtime_status ($GPU_power_state)"$'\n'
		toolstr=$toolstr"Core:|$GPU_curfreq/$GPU_maxfreq MHz"$'\n'
	fi

	toolstr=$toolstr"-----------------|-----------------"$'\n'
}

amd(){
	pciaddr="$1"
	gpuName="$2"
	gpuModel="$3"
	
	GPU_runtime_status=$(</sys/bus/pci/devices/$pciaddr/power/runtime_status)
	GPU_power_state=$(</sys/bus/pci/devices/$pciaddr/power_state)
	
	txtstr=$txtstr"AMD: $GPU_power_state"$'\n'
	
	# TODO: test on an amd hardware to add detailed gpu info
	fallback=1
	
	# print pci info
	if [[ $fallback == 1 ]]
	then
		toolstr=$toolstr"GPU:|$gpuName"$'\n'
		toolstr=$toolstr"|$gpuModel"$'\n'
		toolstr=$toolstr"Status:|$GPU_runtime_status ($GPU_power_state)"$'\n'
	fi

	toolstr=$toolstr"-----------------|-----------------"$'\n'
}

battery(){
	batName="$2"
	batModel="$3"
	
	# TODO: check if other batteries exists and list them

	battery_status=$(</sys/class/power_supply/BAT0/status)
	battery_power=$(</sys/class/power_supply/BAT0/power_now)
	
	txtstr=$txtstr"BAT0: $battery_status"$'\n'
	
	toolstr=$toolstr"BAT0:|$batName"$'\n'
	toolstr=$toolstr"|$batModel"$'\n'
	toolstr=$toolstr"Status:|$battery_status ($battery_power mW)"$'\n'
	toolstr=$toolstr"-----------------|-----------------"$'\n'
}

device_pluggedin=$(</sys/class/power_supply/AC/online)

if [[ $device_pluggedin == "0" ]]
then
	battery
else
	# TODO: running lpci wakes all the pci devices
	# TODO: find a way to check if gpu is sleeping without waking it up
	lspci=$(lspci -Dvnn | grep -e VGA -e 3D)

	oIFS="$IFS"; IFS=$'\t\n'
	GPUlist=($lspci)
	gpus=""
	for gpu in "${GPUlist[@]:0}"
	do  
do  
	do  
		IFS=$' '
		arrIN=(${gpu})
		pciaddr=${arrIN[0]}
		gpuName=`echo $gpu | cut -d "]" -f2 | cut -d "[" -f1`
		gpuName=$''"${gpuName[@]:2}"
		gpuModel=`echo $gpu | cut -d "[" -f3 | cut -d "]" -f1`
		gpuVendorId=`echo $gpu | cut -d "[" -f4 | cut -d ":" -f1`

		# NVIDIA
		if [[ $gpuVendorId == '10de' ]]
		then
		nvidia "$pciaddr" "$gpuName" "$gpuModel"
		# INTEL
		elif [[ $gpuVendorId == '8086' ]]
		then
		intel "$pciaddr" "$gpuName" "$gpuModel"
		# AMD
		elif [[ $gpuVendorId == '1002' ]]
		then
		amd "$pciaddr" "$gpuName" "$gpuModel"
		fi
	done
fi

#nvidia "0000:01:00.0" "NVIDIA Corporation TU117GLM" "Quadro T2000 Mobile / Max-Q"
#intel "0000:00:02.0" "Intel Corporation CoffeeLake-H GT2" "UHD Graphics 630"

IFS=$' '

echo "<tool><span font='monospace' size='small' fgcolor='White'>"
echo $toolstr | column -t -s '|' -d  -N A,B -R A  -c 15 -o ' '
echo "</span></tool>"

echo "<txt><span weight='Bold' fgcolor='White'>$txtstr</span></txt>"

exit 0
