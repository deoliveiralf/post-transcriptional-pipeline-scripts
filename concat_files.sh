#!/bin/bash
#SBATCH --job-name=concat_fastq   # Job name
#SBATCH --output=concat_%j.log    # Output file (%j expands to jobID)
#SBATCH --error=concat_%j.err     # Error file
#SBATCH --time=04:00:00          # Time limit hrs:min:sec
#SBATCH --mem=16G                # Memory limit - increased for larger files

# Define source and destination directories
# Replace these with your actual paths
SRC_DIR="/path/to/your/directory/unaligned"
DEST_DIR="/path/to/your/directory"
OUTPUT_FILE="$DEST_DIR/concatenated_output.fastq.gz"

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Navigate to source directory
cd "$SRC_DIR"

# Concatenate all fastq.gz files while maintaining compression
zcat *.fastq.gz | gzip > "$OUTPUT_FILE"

# Print completion message
echo "FastQ files concatenated successfully"
echo "Source directory: $SRC_DIR"
echo "Output file: $OUTPUT_FILE"

# Print file size of resulting concatenated file
ls -lh "$OUTPUT_FILE"

# Optional: Print MD5 checksum of the output file
md5sum "$OUTPUT_FILE"
