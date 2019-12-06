#! /bin/bash

mkdir pep-sep;
cd pep-sep;

for i in ../pep-dupli/*; do
	b=`basename $i`
	c=${b%.fas}
	mkdir -p $c/pep
	cp $i $c/pep
done
cd -
