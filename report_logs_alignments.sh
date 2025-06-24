#!/bin/bash
#SBATCH --job-name=alignment_counts
#SBATCH --output=alignment_counts_%j.out
#SBATCH --error=alignment_counts_%j.err
#SBATCH --time=0:30:00
#SBATCH --mem=2G

# Define directories
BASE_DIR="/path/to/your/directory/"
OUTPUT_DIR="/path/to/your/directory/alignment_summaries"
SUBDIRS=("bowtie-01-rRNA-index" "bowtie-02-tRNA-index" "bowtie-03-snRNA-index" "bowtie-04-snoRNA-index" "bowtie-05-tmRNA-index" "bowtie-06-scRNA-index")

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Output file
OUTPUT_FILE="$OUTPUT_DIR/alignment_counts.tsv"

# Create header
echo -n "Sample" > "$OUTPUT_FILE"
for subdir in "${SUBDIRS[@]}"; do
    echo -ne "\t${subdir}_alignments" >> "$OUTPUT_FILE"
done
echo "" >> "$OUTPUT_FILE"

# Get all unique sample names from log files
declare -A SAMPLE_MAP
for subdir in "${SUBDIRS[@]}"; do
    if [ -d "$BASE_DIR/$subdir/logs" ]; then
        while IFS= read -r file; do
            sample=$(basename "$file" | cut -d'_' -f1)
            SAMPLE_MAP["$sample"]=1
        done < <(find "$BASE_DIR/$subdir/logs" -name "*.log")
    fi
done

# Process each sample
for sample in "${!SAMPLE_MAP[@]}"; do
    echo -n "$sample" >> "$OUTPUT_FILE"

    # Process each subdirectory
    for subdir in "${SUBDIRS[@]}"; do
        LOG_FILE="$BASE_DIR/$subdir/logs/${sample}_bowtie.log"
        ALIGNMENTS="NA"

        if [ -f "$LOG_FILE" ]; then
            # Try multiple patterns to extract alignment count
            ALIGNMENTS=$(grep -E "Reported [0-9]+ alignments" "$LOG_FILE" | awk '{print $2}')
            if [ -z "$ALIGNMENTS" ]; then
                ALIGNMENTS=$(grep -E "[0-9]+ alignments" "$LOG_FILE" | awk '{print $1}')
            fi
            if [ -z "$ALIGNMENTS" ]; then
                ALIGNMENTS=$(grep "alignments" "$LOG_FILE" | grep -oE "[0-9]+" | head -1)
            fi
        fi

        echo -ne "\t$ALIGNMENTS" >> "$OUTPUT_FILE"
    done
    echo "" >> "$OUTPUT_FILE"
done

# Format as pretty table
if command -v column &> /dev/null; then
    column -t -s $'\t' "$OUTPUT_FILE" > "${OUTPUT_FILE%.tsv}_formatted.tsv"
    echo "Alignment counts saved to:"
    echo "  ${OUTPUT_FILE%.tsv}_formatted.tsv"
else
    echo "Alignment counts saved to:"
    echo "  $OUTPUT_FILE"
fi
