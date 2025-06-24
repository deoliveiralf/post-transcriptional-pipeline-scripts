#!/bin/bash
#SBATCH --job-name=collapse_reads
#SBATCH --output=collapse_reads_%j.out
#SBATCH --error=collapse_reads_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=4

# Exit on error
set -e

# Load required modules (modify these according to your system)
./seqkit

# Input and output file names - replace these with your actual files
INPUT_FILE="/path/to/your/directory/concatenated_unaligned.fastq.gz"
OUTPUT_FASTQ="/path/to/your/directory/collapsed_reads.fastq"
OUTPUT_FASTA="/path/to/your/directory/collapsed_reads.fasta"
TEMP_DIR="temp_collapse"

# Create temporary directory
mkdir -p $TEMP_DIR

# Print start time and input file
echo "Starting read collapse at $(date)"
echo "Input file: $INPUT_FILE"

# Decompress and collapse reads using seqkit
echo "Decompressing and collapsing reads..."
# First, create the collapsed FASTQ
seqkit rmdup \
    --by-seq \
    --ignore-case \
    --threads $SLURM_CPUS_PER_TASK \
    --dup-num-file $TEMP_DIR/duplicate_stats.txt \
    $INPUT_FILE \
    > $OUTPUT_FASTQ

# Convert collapsed FASTQ to FASTA
echo "Converting to FASTA format..."
seqkit fq2fa $OUTPUT_FASTQ > $OUTPUT_FASTA

# Print statistics
echo "Collapse complete. Statistics:"
cat $TEMP_DIR/duplicate_stats.txt

# Clean up
rm -rf $TEMP_DIR

# Print completion message
echo "Read collapse completed at $(date)"
echo "Output FASTQ file: $OUTPUT_FASTQ"
echo "Output FASTA file: $OUTPUT_FASTA"

# Calculate and print basic statistics
echo "Final read counts:"
echo "FASTQ reads: $(grep -c "^@" $OUTPUT_FASTQ)"
echo "FASTA sequences: $(grep -c "^>" $OUTPUT_FASTA)"
