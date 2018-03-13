#!/bin/bash

usage(){
echo "
Written by Brian Bushnell
Last modified March 17, 2017

Description:  Converts sam/bam to fasta/fastq rapidly with multiple threads.
bam files still require samtools in the path.

Usage:  streamsam.sh in=<file> out=<file>

Filtering parameters:
minpos=         Ignore alignments not overlapping this range.
maxpos=         Ignore alignments not overlapping this range.
minmapq=        Ignore alignments with mapq below this.
maxmapq=        Ignore alignments with mapq above this.
contigs=        Comma-delimited list of contig names to include. These 
                should have no spaces, or underscores instead of spaces.
mapped=t        Include mapped reads.
unmapped=t      Include unmapped reads.
secondary=f     Include secondary alignments.
supplimentary=t Include supplimentary alignments.
lengthzero=f    Include alignments without bases.
invert=f        Invert sam filters.

Input may be sam or bam.

Please contact Brian Bushnell at bbushnell@lbl.gov if you encounter any problems.
"
}

pushd . > /dev/null
DIR="${BASH_SOURCE[0]}"
while [ -h "$DIR" ]; do
  cd "$(dirname "$DIR")"
  DIR="$(readlink "$(basename "$DIR")")"
done
cd "$(dirname "$DIR")"
DIR="$(pwd)/"
popd > /dev/null

#DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/"
CP="$DIR""current/"

z="-Xmx1g"
EA="-ea"
EOOM=""
set=0

if [ -z "$1" ] || [[ $1 == -h ]] || [[ $1 == --help ]]; then
	usage
	exit
fi

calcXmx () {
	source "$DIR""/calcmem.sh"
	parseXmx "$@"
}
calcXmx "$@"

streamsam() {
	if [[ $NERSC_HOST == genepool ]]; then
		module unload oracle-jdk
		module load oracle-jdk/1.8_144_64bit
		module load pigz
	fi
	local CMD="java $EA $EOOM $z -cp $CP stream.SamStreamerWrapper $@"
	echo $CMD >&2
	eval $CMD
}

streamsam "$@"
