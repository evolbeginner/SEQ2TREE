#! /bin/bash

# OLD NAME: wrapper.sh

# -------------------------------------------------- #
# A wrapper script to do tree building starting from fasta sequences
# Last updated: 2019-08-05
# Author: Sishuo Wang @ Luo Haiwei Lab, CUHK
# E-mail: sishuowang@hotmail.ca sishuowang@cuhk.edu.hk
# License: BSD
#
# Version: 1.2
# Major updates:
#	1. PMSF can be used in IQ-Tree
#	2. SR4/dayhoff4 can be used for AA in IQ-Tree
#	3. support '-m LG+G+I+F' by '--uni_model'
#	4. aligner (mafft or muscle) can be specified by '--aligner'
#	5. help message
#
# History versions
# Version: 1.1
# Major updates:
#	1. iqtree is integrated
# v1.0
#	1. RAxML is used as the only program to construt phylogeny
#
# -------------------------------------------------- #


######################################################
source ~/tools/self_bao_cun/packages/bash/color.sh


######################################################
ruby=ruby

dir=`dirname $0`
renameSeqTitle=$dir/renameSeqTitle.rb
runAlign=$dir/runAlign.rb
aligner='mafft'
create_cfg=$dir/create_cfg.rb
catAln=$dir/catAln.rb
doTrimal=$dir/doTrimal.rb
run_alignment_prune=$dir/run_alignment_prune.rb
runCompHomogTest=$dir/runCompHomogTest.rb
runPartitionFinder=$dir/runPartitionFinder.rb
selectScheme=$dir/selectScheme.sh
pmsf_iqtree=$dir/pmsf_iqtree.rb
recodeAA=$dir/recodeAA.rb
bmge=$dir/BMGE.rb
splitAln=$dir/splitAln.rb
iqtree=iqtree
iqtree_version_argu=""


export PATH=$PATH:$dir


######################################################
seq_indir=''
seq_suffix='fas','fasta','faa'
isCompHomogTest=false
compHomogTestPvalue=0.05
construct_tree_cht=iqtree
num=1
bootstrap=0
bb=1000
cpu=1
is_aln=true
is_trimal=true
is_prune=false
is_BMGE=false
RML_argu='--RML'
seqoverlap_argu=''
is_force=false
is_renameFasta=false
is_raxml=false
is_iqtree=false
is_fasttree=false
is_FastTree=false
is_stop_trimal=false
is_stop_prune=false
is_stop_CHT=false
is_stop_partition=false
is_add_gaps=false
is_uni_model=false
is_LG=false
is_lg=false
is_Lg=false
is_recode=false
recode_model=''
combined_model=''
tree_add_cmd=''
guide_tree_argu=''
ft_argu=''
topo_tree=''

aln_outdir=''
mfp="MFP+MERGE"


######################################################
function pf(){
	OLDIFS=$IFS
	IFS=""
	printf "%-30s%-80s\n" $1 $2 >&2
	IFS=$OLDIFS
}


function usage(){
	echo -e "bash\tSEQ2TREE.sh" >&2
	echo "A wrapper script to do tree building starting from fasta sequences. It may need IQ-Tree, raxml, trimAl, mafft, muscle, and bioruby. Please make sure they are correctly installed and cite corresponding references when using SEQ2TREE.sh for publication." >&2
	echo "This script is distributed under the BSD licence and in the hope that it can be useful, but WITHOUT ANY WARRANTY." >&2
	echo >&2
	pf "--seq_indir" "sequence indir"
	pf "--outdir" "outdir"
	pf "--seq_suffix" "suffix of seqs"
	pf "--CHT" "do compositional homogeneity test using p4 (default: off)"
	pf "--CHT_P" "the p-value used to filter seqs in CHT (default: 0.05)."
	pf "-c" "the method in tree construction in CHT (default: iqtree). must be used with --CHT"
	pf "-n" "min no. of seqs included in any output alignment"
	pf "-b" "no. of bootstrap replicates"
	pf "--bb" "no. of ultrafast bootstrap replicates"
	pf "--aligner" "the aligner to use (default: mafft)"
	pf "--no_aln|--no_align" "do not do sequence alignment (default: off)"
	pf "--no_trimal|--noTrimal|--nt" "do not do trimming with trimAl (default: off)"
	pf "--trim" "what trimming method do you want to use (default: trimal --RML)?"
	pf "--prune" "do alignment_pruner to remove compositionally biased seqs/sites (default: off)"
	pf "--BMGE|bmge" "do BMGE compositionally biased sites trimming with BMGE (default: off)"
	pf "--cpu" "no. of cpus (default: 1)"
	pf "--force" "remove the outdir if it exists (default: off)"
	pf "--renameFasta" "DISABLED"
	pf "--raxml" "use raxml (default: off)"
	pf "--iqtree" "use IQ-Tree (default: off)"
	pf "--fasttree" "use FastTree in IQ-Tree (default: off)"
	pf "--FastTree" "use FastTreeMP (default: off)"
	pf "--RML" "additional arguments for trimal"
	pf "--seqoverlap" "--seqoverlap 80 for trimal"
	pf "--st" "stop at trimal"
	pf "--stop_prune" "stop at alignment_pruner"
	pf "--sc" "stop at CHT"
	pf "--sp" "stop at partitioning"
	pf "--add_gap" "use gaps for the seqs absent in an alignment. will acitive --sp if specified"
	pf "--uni_model" "use a simple model (i.e. -m LG+G+I+F) instead of finding the best-fit one (default: off)"
	pf "--LG" "use a -m LG+G (default: off)"
	pf "--tree_add_cmd" "additional commands for tree search"
	pf "--pmsf_model|--pmsf" "the model for PMSF in IQ-Tree (default: off)"
	pf "--combined_model" "the model for model in IQ-Tree (default: off)"
	pf "--recode" "the way to recode the alignments (default: off)"
	pf "-h" "print this message"
	echo
	echo "Please contact Sishuo Wang (sishuowang@hotmail.ca) if you have any questions. Your help is highly appreciated." >&2
	exit 1
}



######################################################
function createFasta(){
	echo "Fasta renaming ......"
	ruby $renameSeqTitle --indir $seq_indir --outdir $fasta_dir --cpu $cpu --force
	seq_indir=$fasta_dir
}


function errorMessage(){
	local message=$1
	echo "$message" >&2
	echo "Exiting ......" >&2
	usage
	exit 1
}


function isEmptyGoodAlnIndir(){
	if [ "`ls -A $1`" == "" ]; then
		echo "No alignments pass CHT" >&2
		exit 1
	fi
}


function do_recode(){
	mkdir $recoded_fas_outdir
	for suffix in `echo $seq_suffix | sed 's/,/\n/g'`; do cp $seq_indir/*$suffix $recoded_fas_outdir 2>/dev/null; done
	for i in $recoded_fas_outdir/*; do
		ruby $recodeAA -i $i -m $recode_model | sponge $i
	done
	seq_indir=$recoded_fas_outdir
}


function runAlign(){
	echo "Aligning ......"
	aligner=$1
	$ruby $runAlign --aligner $aligner --indir $seq_indir --suffix $seq_suffix --outdir $aln_outdir --other_outdir $bsub_etc_outdir --cpu $cpu --force
}


function doTrimal(){
	echo "Trimal running ......"
	$ruby $doTrimal --indir $aln_outdir --outdir $trimal_outdir --cpu $cpu --force $RML_argu $seqoverlap_argu
}


function doBMGE(){
	echo "BMGE running ......"
	ruby $bmge --indir $trimal_outdir --sponge --cpu $cpu
	echo "ruby $bmge --indir $trimal_outdir --sponge --cpu $cpu"
}


function doCompHomogTest(){
	if [ $isCompHomogTest == true ]; then
		echo "Compositional heterogeneity test running ......"
		#echo $ruby $runCompHomogTest --indir $trimal_outdir --outdir $compHomogTest_outdir --cpu $cpu -n 2 -p sim:$compHomogTestPvalue,chi2:$compHomogTestPvalue --arg "-c iqtree --nSims 1000"; exit
		$ruby $runCompHomogTest --indir $trimal_outdir --outdir $compHomogTest_outdir --cpu $cpu -n 2 -p sim:$compHomogTestPvalue,chi2:$compHomogTestPvalue --arg "-c $construct_tree_cht --nSims 100 --type protein" --force
		good_aln_indir=$compHomogTest_outdir/aln
	fi
}


function runPartitionFinder(){
	echo "PartitionFinder running ......"
	$ruby $create_cfg --indir $good_aln_indir --suffix aln --aln $combined_aln --mfa2phy --cfg $cfg_outfile -n $num
	mv $outdir/*.phy $partition_outdir
	$ruby $runPartitionFinder --type protein --argu "--force-restart -v --raxml -p $cpu $partition_outdir"
}


# for topo constraint
function create_topo(){
	if [ "$topo_tree" != '' ]; then
		topo_outdir=$outdir/topo
		mkdir $topo_outdir
		cp $topo_tree $outdir/topo/topo.tre
		grep "^>" $combined_aln | sed 's/>//' > $outdir/topo/species.topo.list
		nw_prune -vf $outdir/topo/topo.tre $outdir/topo/species.topo.list | sponge $outdir/topo/topo.tre
		tree_add_cmd=$tree_add_cmd" -g $outdir/topo/topo.tre"
	fi
}


######################################################
params=$@

 
######################################################
while [ $# -gt 0 ]; do
	case $1 in
		--seq_indir)
			seq_indir=$2
			shift
			;;
		--outdir)
			outdir=$2
			shift
			;;
		--seq_suffix)
			seq_suffix=$2
			shift
			;;
		--compHomogTest|--compHomogtest|--CHT)
			isCompHomogTest=true
			;;
		--cht_pvalue|--cht_p|--CHT_pvalue|--CHT_p|--CHT_P)
			compHomogTestPvalue=$2
			isCompHomogTest=true
			shift
			;;
		-c)
			construct_tree_cht=$2
			shift
			;;
		-n)
			num=$2
			shift
			;;
		--bootstrap|-b)
			bootstrap=$2
			shift
			;;
		--bb)
			bb=$2
			shift
			;;
		--aligner)
			aligner=$2
			shift
			;;
		--no_aln|--no_align|--noAlign|--noAln)
			is_aln=false
			;;
		--no_trimal|--noTrimal|--nt)
			is_trimal=false
			echo -e "${Red}--noTrimal|--nt specified!${NC}"
			;;
		--trim)
			if [ $2 == "trimal" ]; then
				is_trimal=true
			elif [ $2 == "RML" -o $2 == "rml" -o $2 == "trim" ]; then
				RML_argu='--RML'
			elif [ $2 == "seqoverlap" ]; then
				seqoverlap_argu="--seqoverlap"
			elif [ $2 == "no" ]; then
				is_trimal=false
			fi
			shift
			;;
		--RML|--rml)
			RML_argu='--RML'
			;;
		--prune)
			is_prune=true
			;;
		--BMGE|--bmge)
			is_BMGE=true
			;;
		--cpu)
			cpu=$2
			shift
			;;
		--force)
			is_force=true
			;;
		--renameFasta|--rename_fasta)
			is_renameFasta=true
			;;
		--raxml)
			is_raxml=true
			;;
		--iqtree)
			is_iqtree=true
			;;
		--fasttree|--ft|--fast)
			is_iqtree=true
			is_fasttree=true
			;;
		--FastTree|--FT|--FAST)
			is_FastTree=true
			;;
		--st|--stop_trimal)
			is_stop_trimal=true
			;;
		--stop_prune)
			is_stop_prune=true
			;;
		--sc|--stop_CHT)
			is_stop_CHT=true
			;;
		--sp|--stop_partition)
			is_stop_partition=true
			;;
		--add_gap|--add_gaps)
			is_add_gaps=true
			is_stop_partition=true
			echo -e "${Red}--is_add_gaps specified, so no phylo is performed!${NC}"
			;;
		--tree_add_cmd)
			tree_add_cmd=$2
			shift
			;;
		--uni_model|--uniModel)
			is_uni_model=true
			;;
		-m|--model)
			model=$2
			shift
			;;
		--LG)
			is_LG=true
			;;
		--lg)
			is_lg=true
			mfp='MFP'
			;;
		--Lg)
			is_Lg=true
			;;
		--model_TEST)
			tree_add_cmd=$tree_add_cmd' '"-m TEST"
			;;
		--model3|--tree_model3)
			tree_add_cmd=$tree_add_cmd' '"-mset LG,JTT,WAG -mrate E,I,G,I+G"
			;;
		--model3FU|--tree_model3FU)
			tree_add_cmd=$tree_add_cmd' '"-mset LG,JTT,WAG -mrate E,I,G,I+G -mfreq FU"
			;;
		--model3-LG|--model-LG3)
			tree_add_cmd=$tree_add_cmd' '"-mset LG -mrate E,I,G,I+G"
			;;
		--mfp|--MFP|--spp)
			mfp="MFP"
			;;
		--combined_model)
			combined_model=$2
			shift
			;;
		--pmsf_model|--PMSF_model|--pmsf|--PMSF)
			pmsf_model=$2
			shift
			;;
		--guide_tree)
			guide_tree_argu="--guide_tree $2"
			shift
			;;
		--recode)
			recode_model=$2
			is_recode=true
			shift
			;;
		--iqtree2)
			iqtree=""
			export iqtree=iqtree2
			;;
		--iqtree1.6)
			iqtree=""
			export iqtree=iqtree1.6
			iqtree_version_argu="--iqtree1.6"
			is_iqtree=true
			;;
		--topo)
			topo_tree=$2
			shift
			;;
		-h)
			usage
			;;
		*)
			errorMessage "Wrong argu $1!"
			;;
	esac
	shift
done


######################################################
if [ "$is_lg" == false -a "$is_LG" == false -a "$is_Lg" == false -a \
	"$is_uni_model" = false -a \
	"$tree_add_cmd" == '' -a \
	-z "$model" ]; then
	errorMessage "Sub model must be specified! Exiting ......"
fi


######################################################
num_seqs_in_pep=`ls -1 $seq_indir/*$suffix|wc -l`
[ "$num" == "auto" ] && num=$num_seqs_in_pep
if [ $num -gt $num_seqs_in_pep ]; then echo "-n $num greater than seq # in pep/. Exiting ......"; exit 1; fi
echo -e "${Green}Minimum No. of seqs is:\t$num${NC}" >&2
echo ""

echo -e "${Blue}tree_add_cmd: $tree_add_cmd${NC}"


######################################################
# check arguments
if [ $is_raxml == false -a $is_iqtree == false -a $is_fasttree == false -a $is_FastTree == false ]; then
	errorMessage "Wrong! The program used in phylogeny reconstruction has to be specified!"
fi

if [ -z $outdir ]; then
	errorMessage "seq_indir not given!"
elif [ -z $seq_indir ]; then
	errorMessage "seq_indir not given!"
fi

if [ -e $outdir ]; then
	if [ $is_force == true ]; then
		rm -rf $outdir
	else
		errorMessage "Outdir $outdir has existed! Please specify another one or use --force"
	fi
fi


######################################################
fasta_dir=$outdir/fasta
recoded_fas_outdir=$outdir/recoded_fasta
aln_outdir=$outdir/aln
trimal_outdir=$outdir/trimal
prune_outdir=$outdir/prune
gap_aln_outdir=$outdir/gap_aln
compHomogTest_outdir=$outdir/compHomogTest
bsub_etc_outdir=$outdir/bsub_etc
combined_aln=$outdir/combined.aln
recoded_aln=$outdir/recoded.aln
partition_outdir=$outdir/partition
cfg_outfile=$partition_outdir/partition_finder.cfg
phylo_outdir=$outdir/phylo
raxml_outdir=$phylo_outdir/raxml
iqtree_outdir=$phylo_outdir/iqtree
FastTree_outdir=$outdir
#FastTree_outdir=$phylo_outdir/FastTree
scheme_file=$raxml_outdir/raxml.scheme

mkdir -p $fasta_dir $recoded_fas_outdir $aln_outdir $trimal_outdir $bsub_etc_outdir $partition_outdir

echo ${params[@]} > $outdir/params


######################################################
[ $is_renameFasta == true ] && createFasta

# inactivated as it performs aln on recoded seqs
#[ $is_recode == true ] && do_recode

# mafft
if [ $is_aln == true ]; then
	runAlign $aligner
else
	for suffix in `echo $seq_suffix | sed 's/,/\n/g'`; do cp $seq_indir/*$suffix $aln_outdir 2>/dev/null; done
	for i in $aln_outdir/*; do mv $i ${i%.*}.aln 2>/dev/null; done
fi
for i in $aln_outdir/*; do sed -i 's/\*/\-/g' $i; done


# trimal
if [ $is_trimal == true ]; then
	doTrimal
else
	cd $trimal_outdir >/dev/null
	ln -s ../aln/* ./
	cd - >/dev/null
fi
good_aln_indir=$trimal_outdir
[ $is_stop_trimal == true ] && exit 0


# alignment_pruner
if [ $is_prune == true ]; then
	echo "Prunning ......"
	ruby $run_alignment_prune --indir $trimal_outdir --outdir $prune_outdir --force --cpu $cpu
fi
[ $is_stop_prune == true ] && exit 0

# do BMGE
[ $is_BMGE == true ] && doBMGE

# CHT
doCompHomogTest
[ $is_stop_CHT == true ] && exit 0

isEmptyGoodAlnIndir $good_aln_indir


######################################################
# RAxML
if [ $is_raxml == true ]; then
	echo "Constructing phylogenetic tree using RAxML ......"
	mkdir -p $raxml_outdir

	runPartitionFinder
	bash $selectScheme -i $partition_outdir/analysis/best_scheme.txt > $scheme_file

	cd $PWD/$raxml_outdir >/dev/null
	$LHW/software/RAxML/latest/raxmlHPC-PTHREADS-SSE3 -k -f a -m PROTGAMMAJTT -n raxml -s ../../combined.aln -q raxml.scheme -T $cpu -w $PWD -# $bootstrap -p 123 -x 123
	cd - >/dev/null
fi


# IQ-Tree
if [ $is_iqtree == true ]; then
	echo "Constructing phylogenetic tree using iqtree ......"
	mkdir -p $iqtree_outdir

	
	$ruby $create_cfg --indir $good_aln_indir --suffix aln --aln $combined_aln --mfa2phy --cfg $cfg_outfile -n $num
	sed '/\[data_blocks\]/,/#/!d' $cfg_outfile | sed '1d'| sed '$d' |awk '{print "NR, ",$0}' > $iqtree_outdir/iqtree.partition
	[ $is_add_gaps == true ] && ruby $splitAln -p $cfg_outfile --aln $combined_aln --outdir $gap_aln_outdir --force
	[ $is_stop_partition == true ] && exit 0 # i.e. --sp, exit


	if [ $bootstrap == 0 ]; then
		b_str=""
	else
		b_str="-b $bootstrap"
		bb=0
	fi

	if [ $bb == 0 ]; then
		bb_str=""
	else
		bb_str="-bb $bb"
	fi

	# create_topo
	create_topo

	if [ $is_recode == true ]; then
		ruby $recodeAA -i $combined_aln -m $recode_model > $recoded_aln
		if [ $is_recode == true ]; then
			if ! grep 'dayhoff4\|SR4$' <<< $pmsf_model >/dev/null; then pmsf_model=$pmsf_model$recode_model; fi
		fi
		if grep '[a-zA-Z0-9]' <<< $combined_model > /dev/null; then
			$iqtree -s $recoded_aln -m $combined_model -pre $iqtree_outdir/iqtree $b_str $bb_str -nt $cpu -wbtl -wsl -quiet $tree_add_cmd -keep-ident
		else
			# pmsf
			ruby $pmsf_iqtree -i $recoded_aln --outdir $iqtree_outdir --force --cpu $cpu -m $pmsf_model "$tree_add_cmd" $iqtree_version_argu $guide_tree_argu
		fi

	else
		if [ $is_fasttree == true ]; then
			bb_str=''
			ft_argu='-fast'
		fi
		if [ ! -z "$model" ]; then
			$iqtree -s $combined_aln -m $model -pre $iqtree_outdir/iqtree $b_str $bb_str -nt $cpu -redo -wbtl -wsl -quiet -keep-ident $tree_add_cmd $ft_argu
		elif [ $is_uni_model == true -o $is_LG == true ]; then
			#cd $iqtree_outdir # enter iqtree_outdir
			$iqtree -s $combined_aln -m LG+G{0.5}+F -pre $iqtree_outdir/iqtree $b_str $bb_str -nt $cpu -redo -wbtl -wsl -quiet -keep-ident $tree_add_cmd $ft_argu
		elif [ $is_lg == true ]; then
			$iqtree -s $combined_aln -m $mfp -mset LG -mrate G -mfreq F -pre $iqtree_outdir/iqtree $b_str $bb_str -nt $cpu -redo -wbtl -wsl -quiet -keep-ident $tree_add_cmd $ft_argu
		elif [ $is_Lg == true ]; then
			$iqtree -s $combined_aln -m LG+G -pre $iqtree_outdir/iqtree $b_str $bb_str -nt $cpu -redo -wbtl -wsl -quiet -keep-ident $tree_add_cmd $ft_argu

		# pmsf
		elif grep '[a-zA-Z0-9]' <<< $pmsf_model > /dev/null; then
			ruby $pmsf_iqtree -i $combined_aln --outdir $iqtree_outdir --force --cpu $cpu -m $pmsf_model --tree_add_cmd "$tree_add_cmd" $iqtree_version_argu $guide_tree_argu
		elif grep '[a-zA-Z0-9]' <<< $combined_model > /dev/null; then
			$iqtree -s $combined_aln -m $combined_model -pre $iqtree_outdir/iqtree $b_str $bb_str -nt $cpu -redo -wbtl -wsl -quiet -keep-ident $tree_add_cmd
		elif [ $is_FastTree == false ]; then
			$iqtree -s $combined_aln -spp $iqtree_outdir/iqtree.partition -m $mfp -pre $iqtree_outdir/iqtree $b_str $bb_str -nt $cpu -redo -wbtl -wsl -quiet -keep-ident $tree_add_cmd $ft_argu
		fi
	fi
fi


#FastTree
if [ $is_FastTree == true ]; then
	echo "Constructing phylogenetic tree using FastTree"
	$ruby $create_cfg --indir $good_aln_indir --suffix aln --aln $combined_aln --mfa2phy --cfg $cfg_outfile -n $num
	FastTreeMP -lg -quiet -gamma < $combined_aln > $FastTree_outdir/combined.FastTree.tre
fi


if [ $? == 0 ]; then
	echo "Done!"
else
	echo "There seemed to be a problem!" >&2
fi

