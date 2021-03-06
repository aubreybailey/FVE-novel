#!/bin/bash

#function usage(){
#	echo "CalcMem v1.06"
#	echo "Written by Brian Bushnell, Doug Jacobsen, Alex Copeland, Bryce Foster"
#	echo "Calculates available memory in megabytes"
#	echo "Last modified October 2, 2017"
#}

#Also parses other Java flags
function parseXmx () {
	
	local setxmx=0
	local setxms=0
	
	for arg in "$@"
	do
		if [[ "$arg" == "Xmx="* ]] || [[ "$arg" == "xmx="* ]]; then
			z="-Xmx"${arg:4}
			setxmx=1
		elif [[ "$arg" == "-Xmx="* ]] || [[ "$arg" == "-xmx="* ]]; then
			z="-Xmx"${arg:5}
			setxmx=1
		elif [[ "$arg" == -Xmx* ]] || [[ "$arg" == -xmx* ]]; then
			#z="$arg"
			z="-X"${arg:2}
			setxmx=1
		elif [[ "$arg" == Xmx* ]] || [[ "$arg" == xmx* ]]; then
			#z="-$arg"
			z="-X"${arg:1}
			setxmx=1
		elif [[ "$arg" == -Xms* ]]; then
			z2="$arg"
			setxms=1
		elif [[ "$arg" == Xms* ]]; then
			z2="-$arg"
			setxms=1
		elif [[ "$arg" == -da ]] || [[ "$arg" == -ea ]]; then
			EA="$arg"
		elif [[ "$arg" == da ]] || [[ "$arg" == ea ]]; then
			EA="-$arg"
		elif [[ "$arg" == ExitOnOutOfMemoryError ]] || [[ "$arg" == exitonoutofmemoryerror ]] || [[ "$arg" == eoom ]]; then
			EOOM="-XX:+ExitOnOutOfMemoryError"
		elif [[ "$arg" == -ExitOnOutOfMemoryError ]] || [[ "$arg" == -exitonoutofmemoryerror ]] || [[ "$arg" == -eoom ]]; then
			EOOM="-XX:+ExitOnOutOfMemoryError"
		fi
	done
	
	if [[ $setxmx == 1 ]] && [[ $setxms == 0 ]]; then
		local substring=`echo $z| cut -d'x' -f 2`
		z2="-Xms$substring"
		setxms=1
	elif [[ $setxmx == 0 ]] && [[ $setxms == 1 ]]; then
		local substring=`echo $z2| cut -d's' -f 2`
		z="-Xmx$substring"
		setxmx=1
	fi
	
	set=$setxmx
	
}


RAM=0;

function freeRam(){
	#Memory is in kilobytes.
	local defaultMem=3200000
	if [ $# -gt 0 ]; then
		defaultMem=$1;
		case $defaultMem in
			*g)
			defaultMem=`echo $defaultMem| cut -d'g' -f 1`
			defaultMem=$(( $defaultMem * $(( 1024 * 1024 )) ))
			;;
			*m)
			defaultMem=`echo $defaultMem| cut -d'm' -f 1`
			defaultMem=$(( $defaultMem * 1024 ))
			;;
			*k)
			defaultMem=`echo $defaultMem| cut -d'k' -f 1`
			;;
		esac
	fi

	local mult=84
	if [ $# -gt 1 ]; then
		mult=$2;
	fi
	
	#echo "mult =    $mult" # percent of memory to allocate
	#echo "default = $defaultMem"
	
	local ulimit=$(ulimit -v)
	ulimit="${ulimit:-0}"
	if [ "$ulimit" = "unlimited" ]; then ulimit=0; fi
	local x=$ulimit
	#echo "x = ${x}" # normally ulimit -v
	
	local HOSTNAME=`hostname`
	local sge_x=0
	
	if [[ $HOSTNAME == genepool* ]]; then
		# get cluster memory var: 2016-02-22 Bhupender says use SGE_HGR_RAMC
		sge_x=$(env | grep -i sge_hgr_ramc | perl -ne '$_ =~ s/[^0-9\.]//g; print $_ * 1024*1024')
		
		if [ "$sge_x" = "" ]; then sge_x=0; fi
		#echo "sge = ${sge_x}"
	fi
    
	if [[ $RQCMEM -gt 0 ]]; then
		#echo "branch for manual memory"
		x=$(( RQCMEM * 1024 ));
	elif [ -e /proc/meminfo ]; then
		local vfree=$(cat /proc/meminfo | awk -F: 'BEGIN{total=-1;used=-1} /^CommitLimit:/ { total=$2 }; /^Committed_AS:/ { used=$2 } END{ print (total-used) }')
		local pfree=$(cat /proc/meminfo | awk -F: 'BEGIN{free=-1;cached=-1;buffers=-1} /^MemFree:/ { free=$2 }; /^Cached:/ { cached=$2}; /^Buffers:/ { buffers=$2} END{ print (free+cached+buffers) }')
		
		#echo "vfree =   $vfree"
		#echo "pfree =   $pfree"
		#echo "ulimit =  $ulimit"

		local x2=0;

		
		if [ $vfree -gt 0 ] && [ $pfree -gt 0 ]; then
			if [ $vfree -gt $pfree ]; then x2=$pfree; 
			else x2=$vfree; fi
		elif [ $vfree -gt 0 ]; then x2=$vfree;
		elif [ $pfree -gt 0 ]; then x2=$pfree;
		fi

		
		# set to SGE_HGR_RAMC value
		if [ $sge_x -gt 0 ]; then 
			if [ $x2 -gt $sge_x ] || [ $x2 -eq 0 ]; then 
				x=$sge_x;
				x2=$x; 
			fi
		fi

		
		#echo "x = ${x}"
		#echo "x2 = ${x2}"
		#echo $vfree
		#echo $pfree
		
		if [ "$x" = "unlimited" ] || (("$x" > $x2)); then x=$x2; fi
		if [ $x -lt 1 ]; then x=$x2; fi
	fi

	if [ $x -lt 1 ] || [[ $HOSTNAME == genepool* ]]; then
		#echo "branch for unknown memory"
		#echo $x
		#echo "ram is unlimited"
		RAM=$((defaultMem/1024))
		echo "Max memory cannot be determined.  Attempting to use $RAM MB." 1>&2
		echo "If this fails, please add the -Xmx flag (e.g. -Xmx24g) to your command, " 1>&2
		echo "or run this program qsubbed or from a qlogin session on Genepool, or set ulimit to an appropriate value." 1>&2
	else
		#echo "branch for known memory"
		#echo "x = ${x}"
		#echo "m = ${mult}"
		
		# available (ram - 500k) * 85% / 1024kb = megs of ram to use
		# not sure where this formula came from
		RAM=$(( ((x-500000)*mult/100)/1024 ))
		#echo $RAM
	fi
	#local z="-Xmx${RAM}m"
	#echo $RAM
	return 0
}

#freeRam "$@"
