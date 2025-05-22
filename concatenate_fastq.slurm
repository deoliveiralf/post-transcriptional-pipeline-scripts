#!/bin/bash
#SBATCH --job-name=fastq_concatenate
#SBATCH --output=fastq_concatenate.log
#SBATCH --time=06:00:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=2

# Load modules (adjust as needed)
module load fastqc

# --- USER SETTINGS ---
INPUT_DIR="."                  # Directory containing input FASTQ.gz files
OUTPUT_DIR="./merged_results"  # Where to save outputs (will be created if missing)
# ---------------------

# Create output directory (if missing)
mkdir -p "$OUTPUT_DIR" || { echo "Failed to create $OUTPUT_DIR"; exit 1; }
echo "Output will be saved to: $OUTPUT_DIR"

# 1. Concatenate all FASTQ.gz files
echo "Concatenating files..."
cat "$INPUT_DIR"/*.fastq.gz > "$OUTPUT_DIR/concatenated_unaligned.fastq.gz" || {
    echo "Error: No .fastq.gz files found in $INPUT_DIR or concatenation failed."
    exit 1
}
echo "Saved: $OUTPUT_DIR/concatenated_unaligned.fastq.gz"

# 2. Print first 10 lines (for verification)
echo "First 10 lines of concatenated file:"
zcat "$OUTPUT_DIR/concatenated_unaligned.fastq.gz" | head

# 3. Count reads (lines starting with '@')
echo "Counting reads..."
READ_COUNT=$(zcat "$OUTPUT_DIR/concatenated_unaligned.fastq.gz" | grep -c "^@")
echo "Total reads: $READ_COUNT"

# 4. Create decompressed copy (optional)
echo "Creating decompressed version..."
zcat "$OUTPUT_DIR/concatenated_unaligned.fastq.gz" > "$OUTPUT_DIR/concatenated_unaligned.fastq"
echo "Saved: $OUTPUT_DIR/concatenated_unaligned.fastq"

# 5. Run FastQC
echo "Running FastQC..."
fastqc "$OUTPUT_DIR/concatenated_unaligned.fastq.gz" --outdir="$OUTPUT_DIR/fastqc_report" || {
    echo "Error: FastQC failed. Is the module loaded?"
    exit 1
}
echo "FastQC report saved to: $OUTPUT_DIR/fastqc_report"

echo "All tasks completed. Results in $OUTPUT_DIR"
"concatenate_fastq.slurm" [readonly] 50L, 1753C