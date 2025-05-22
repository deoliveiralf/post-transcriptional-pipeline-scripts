#!/bin/bash

# Set paths and parameters
INDEX="/home/lfdeoliveira/bioinfo/CleaveLand4-master/peanut-degradome/bowtie-data"
INPUT_DIR="/home/lfdeoliveira/bioinfo/CleaveLand4-master/peanut-degradome/bowtie-data"
OUTPUT_DIR="/home/lfdeoliveira/bioinfo/CleaveLand4-master/peanut-degradome/bowtie-data/results"

# Create output directory if it doesn't exist
mkdir -p $OUTPUT_DIR

# Ensure paths are correct before running
if [ ! -d "$INPUT_DIR" ] || [ ! -d "$OUTPUT_DIR" ] || [ ! -d "$INDEX" ]; then
    echo "Index, Input or output directory does not exist!"
    exit 1
fi



# Loop through all FASTQ files in input directory
for QUERY_FILE in $INPUT_DIR/*.fastq.gz
do
    # Extract base filename without extension
    filename=$(basename "$QUERY_FILE" .fastq.gz)

    # Run Bowtie alignment
    bowtie \
        -q \               # Input is FASTQ format
        $INDEX/index_name* \ # Path to Bowtie index
        $QUERY_FILE \      # Input FASTQ file
        $OUTPUT_DIR/${filename}_aligned.sam \
        2> $OUTPUT_DIR/${filename}_bowtie.log

    # Optional: Extract unmapped reads
    samtools view -f 4 $OUTPUT_DIR/${filename}_aligned.sam > $OUTPUT_DIR/${filename}_unmapped.sam
done

echo "Bowtie alignment completed for all files."