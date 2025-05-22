#!/bin/bash
# Simple script to convert pre-processed FASTQ degradome reads to FASTA for CleaveLand4 mode 1
# Usage: ./fastq_to_fasta.sh <input.fastq> <output.fasta>

# Check if arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <input.fastq> <output.fasta>"
    exit 1
fi

INPUT_FASTQ=$1
OUTPUT_FASTA=$2

echo "Converting $INPUT_FASTQ to FASTA format..."

# Simple conversion from FASTQ to FASTA
# This awk command:
# 1. Processes only header and sequence lines from FASTQ
# 2. Converts FASTQ headers (starting with @) to FASTA headers (starting with >)
# 3. Keeps the original read IDs
awk '
{
    if (NR % 4 == 1) {
        # Convert @ to > for FASTA format
        print ">" substr($0, 2)
    }
    else if (NR % 4 == 2) {
        # Print sequence line as is
        print $0
    }
}' "$INPUT_FASTQ" > "$OUTPUT_FASTA"

# Count number of reads in output
READ_COUNT=$(grep -c "^>" "$OUTPUT_FASTA")
echo "Conversion complete. $READ_COUNT reads written to $OUTPUT_FASTA"
echo ""
echo "You can now use $OUTPUT_FASTA as input for CleaveLand4 mode 1 with:"
echo "CleaveLand4.pl -e $OUTPUT_FASTA -u small_RNA_queries.fasta -n transcriptome.fasta -t > full_results.txt"