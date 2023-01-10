#! /bin/bash


############################################################################
BMGE="~/software/phylo/BMGE-1.12/BMGE.jar"

indir=''
outdir=''
is_force=false
cpu=2


############################################################################
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
		--force)
			is_force=true
			;;
		--cpu)
			cpu=$2
			shift
			;;
	esac
	shift
done


############################################################################
[ -z $indir ] && echo "$indir not given!" >&2 && exit 1
[ -z $outdir ] && echo "$outdir not given!" >&2 && exit 1
if [ -d "$outdir" -a "$is_force" == true ]; then
	rm -rf $outdir
elif [ -d "$outdir" -a "$is_force" == false ]; then
	echo "Fatal error! outdir $outdir has existed!" >&2 && exit 1
fi
mkdir $outdir


############################################################################
tmp="/tmp/$RANDOM"

for i in `ls $indir/*`; do
	b=`basename $i`
	echo "echo $b; java -jar $BMGE -i $i -h 1 -g 1 -t AA -s fast -of $outdir/$b"
done > $tmp

parallel -j $cpu < $tmp 2>/dev/null

rm $tmp


