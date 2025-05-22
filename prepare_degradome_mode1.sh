#!/bin/bash
# Script to prepare degradome reads from Illumina sequencing for CleaveLand4 mode 1
# Usage: ./prepare_degradome_mode1.sh <input.fastq> <output.fasta> [min_length]

# Check if arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <input.fastq> <output.fasta> [min_length]"
    echo "  min_length: Minimum read length (default: 18)"
    exit 1
fi

INPUT_FASTQ=$1
OUTPUT_FASTA=$2
MIN_LENGTH=${3:-18}  # Default minimum length is 18nt

# Create output directory if it doesn't exist
OUTPUT_DIR=$(dirname "$OUTPUT_FASTA")
mkdir -p "$OUTPUT_DIR"

echo "=== Processing Illumina degradome reads for CleaveLand4 mode 1 ==="
echo "Input: $INPUT_FASTQ"
echo "Output: $OUTPUT_FASTA"
echo "Minimum read length: $MIN_LENGTH"

# Step 1: Trim adapters using cutadapt (if installed)
# Modify the adapter sequence to match your library prep
if command -v cutadapt &> /dev/null; then
    echo "=== Step 1: Trimming adapters with cutadapt ==="
    TRIMMED_FASTQ="${INPUT_FASTQ%.fastq}_trimmed.fastq"
    # Replace AGATCGGAAGAGC with your actual adapter sequence
    cutadapt -a AGATCGGAAGAGC -q 20 -m "$MIN_LENGTH" -o "$TRIMMED_FASTQ" "$INPUT_FASTQ"
    INPUT_FASTQ="$TRIMMED_FASTQ"
    echo "Adapter trimming complete. Output: $TRIMMED_FASTQ"
else
    echo "cutadapt not found. Skipping adapter trimming."
    echo "If your reads have adapters, please install cutadapt or trim adapters manually."
fi

# Step 2: Convert FASTQ to FASTA format
echo "=== Step 2: Converting FASTQ to FASTA format ==="
# This awk command:
# 1. Processes only sequence lines (every 2nd line out of 4 in FASTQ)
# 2. Keeps only sequences of at least MIN_LENGTH
# 3. Renames headers to "Degradome_read_XXX"
awk -v min="$MIN_LENGTH" '
BEGIN {count = 0}
{
    if (NR % 4 == 1) {
        # Get original header (remove @ symbol)
        header = substr($0, 2)
    } else if (NR % 4 == 2) {
        # Process sequence line
        if (length($0) >= min) {
            count++
            # Print in FASTA format with simplified header
            print ">Degradome_read_" count
            print $0
        }
    }
}' "$INPUT_FASTQ" > "$OUTPUT_FASTA"

# Count number of reads in output
READ_COUNT=$(grep -c "^>" "$OUTPUT_FASTA")
echo "Conversion complete. $READ_COUNT reads written to $OUTPUT_FASTA"

echo "=== Processing complete ==="
echo "You can now use $OUTPUT_FASTA as input for CleaveLand4 mode 1 with:"
echo "CleaveLand4.pl -e $OUTPUT_FASTA -u small_RNA_queries.fasta -n transcriptome.fasta -t > full_results.txt"
                                                                                                                            