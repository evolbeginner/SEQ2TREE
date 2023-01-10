#! /bin/bash


################################################
indir=$1


################################################
mkdir phylip; for i in $indir/*; do cp $i phylip; done

for i in phylip/*; do MFAtoPHY.pl $i; done

cat phylip/*phy > combined.phy

