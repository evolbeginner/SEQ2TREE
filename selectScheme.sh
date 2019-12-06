#! /bin/bash


#######################################################
infile=''
type=raxml


#######################################################
while [ $# -gt 0 ]; do
	case $1 in
		-i)
			infile=$2
			shift
			;;
		--type)
			type=$2
			shift
			;;
	esac
	shift
done


#######################################################
if [ $type == 'raxml' ]; then
	sed '/^RaxML-style partition definitions/,/^MrBayes block for partition definitions/!d' $infile | sed '/^$/,$!d;$d'
fi


