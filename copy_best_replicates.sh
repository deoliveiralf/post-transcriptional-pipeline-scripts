#!/bin/bash
#SBATCH --job-name=copy_best_replicates
#SBATCH --output=copy_best_replicates.out
#SBATCH --error=copy_best_replicates.err
#SBATCH --time=1:00:00
#SBATCH --mem=4G

# Define the directories and input file
SOURCE_DIR="/temporario2/8412199/small-degradome-seq/small-libraries/fastp-data-2/fastp_trimmed"
DEST_DIR="/temporario2/8412199/small-degradome-seq/small-libraries/fastp-best_replicates"
SUMMARY_FILE="/temporario2/8412199/slurm-tools/small-libraries/fastp-data-2/logs/best_replicates_summary.txt"

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Check if summary file exists
if [ ! -f "$SUMMARY_FILE" ]; then
    echo "Error: Best replicates summary file not found at $SUMMARY_FILE"
    exit 1
fi

# Print the operation being performed
echo "Copying best replicate files to: $DEST_DIR"
echo "Based on summary from: $SUMMARY_FILE"
echo ""

# Create a report file
REPORT_FILE="$DEST_DIR/copied_files_report.txt"
echo "Files copied based on best replicate selection:" > "$REPORT_FILE"
echo "Original File | Source Path | Destination Path" >> "$REPORT_FILE"
echo "--------------|--------------|-----------------" >> "$REPORT_FILE"

# Count variables
total_selected=0
total_copied=0
total_missing=0

# Skip the header line and process each selected file
tail -n +2 "$SUMMARY_FILE" | while read -r line; do
    # Extract filename from the first column
    file_name=$(echo "$line" | awk '{print $1}')
    ((total_selected++))

    # Extract basename (remove _fastp.log if present)
    if [[ "$file_name" == *_fastp.log ]]; then
        base_name=${file_name%_fastp.log}
    else
        # If no _fastp.log suffix, use as is (should not happen with expected format)
        base_name=$file_name
    fi

    # Look for corresponding trimmed file
    source_file="${SOURCE_DIR}/${base_name}_trimmed.fastq.gz"

    if [ -f "$source_file" ]; then
        # Copy file to destination
        cp "$source_file" "$DEST_DIR/"
        dest_file="$DEST_DIR/$(basename "$source_file")"

        echo "$file_name | $source_file | $dest_file" >> "$REPORT_FILE"
        echo "Copied: $source_file"
        ((total_copied++))
    else
        echo "Warning: Source file not found: $source_file"
        echo "$file_name | NOT FOUND | N/A" >> "$REPORT_FILE"
        ((total_missing++))
    fi
done

# Format the report as a table
if command -v column &> /dev/null; then
    column -t -s'|' "$REPORT_FILE" > "${REPORT_FILE%.txt}_formatted.txt"
    mv "${REPORT_FILE%.txt}_formatted.txt" "$REPORT_FILE"
fi

# Summarize the results
echo -e "\nCopy operation complete."
echo "Total files selected from summary: $total_selected"
echo "Files successfully copied: $total_copied"
echo "Files not found: $total_missing"
echo "Report saved to: $REPORT_FILE"