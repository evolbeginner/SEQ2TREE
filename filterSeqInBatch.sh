#! /bin/bash


############################################################
indir=''
outdir=''
is_sponge='false'
seq_included_from_str=''
seq_excluded_from_str=''
include_tbl=''
exclude_tbl=''
get_subseq=~/tools/self_bao_cun/basic_process_mini/get_subseq.rb


declare -A include_h
declare -A exclude_h


############################################################
while [ $# -gt 0 ]; do
	case $1 in
		--indir)
			indir=$2
			shift
			;;
		--outdir)
			outdir=$2
			shift
			;;
		--sponge)
			is_sponge=true
			;;
		--include_list)
			seq_included_from_str="--seq_included_from $2"
			shift
			;;
		--exclude_list)
			seq_excluded_from_str="--seq_excluded_from $2"
			shift
			;;
		--include_tbl)
			include_tbl=$2
			shift
			;;
		--exclude_tbl)
			exclude_tbl=$2
			shift
			;;
	esac
	shift
done


############################################################
if [ $is_sponge == true ]; then
	outdir=$indir
else
	[ -d $outdir ] && rm -rf $outdir
	mkdir $outdir
fi


if [ ! -z $include_tbl ]; then
	while read line; do
		k=`cut -d ' ' -f1 <<< $line`;
		v=`cut -d ' ' -f2 <<< $line`;
		include_h[$k]=$v
	done < $include_tbl
fi


if [ ! -z $exclude_tbl ]; then
	while read line; do
		k=`cut -d ' ' -f1 <<< $line`;
		v=`cut -d ' ' -f2 <<< $line`;
		exclude_h[$k]=$v
	done < $exclude_tbl
fi


############################################################
for i in $indir/*; do
	b=`basename $i`;
	c=${b%.*}
	ruby $get_subseq -i $i $seq_included_from_str $seq_excluded_from_str | sponge $outdir/$b
	if [ ! -z ${include_h[$c]} ]; then
		v=${include_h[$c]}
		ruby $get_subseq -i $i --seq_name $v | sponge $outdir/$b
	fi
	if [ ! -z ${exclude_h[$c]} ]; then
		v=${exclude_h[$c]}
		ruby $get_subseq -i $i --seq_excluded $v | sponge $outdir/$b
	fi
done


