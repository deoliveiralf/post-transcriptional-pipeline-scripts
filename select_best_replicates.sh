#!/bin/bash
#SBATCH --job-name=select_best_replicates
#SBATCH --output=select_best_replicates.out
#SBATCH --error=select_best_replicates.err
#SBATCH --time=1:00:00
#SBATCH --mem=4G

# Input file from previous script
INPUT_FILE="/path/to/your/directory/logs/fastp_summary_with_percentages.txt"
OUTPUT_FILE="/path/to/your/directory/logs/best_replicates_summary.txt"

# Debug: Check if input file exists and has content
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

echo "Input file line count: $(wc -l < "$INPUT_FILE")"

# Temporary files
SORTED_FILE=$(mktemp)
BASENAMES_FILE=$(mktemp)
HEADER=$(head -n 1 "$INPUT_FILE")

# Copy header to output file
echo "$HEADER" > "$OUTPUT_FILE"

# Skip header and process the data rows
tail -n +2 "$INPUT_FILE" > "$SORTED_FILE"

# Extract unique basenames with correct pattern matching and no trailing underscore
awk -F'\t' '
{
    filename = $1;
    if (match(filename, /_R[12]/)) {
        print substr(filename, 1, RSTART-1);
    } else {
        sub(/\.[^.]+$/, "", filename);
        print filename;
    }
}' "$SORTED_FILE" | sort -u > "$BASENAMES_FILE"

echo "Debug: Found $(wc -l < "$BASENAMES_FILE") unique basenames"
echo "First few basenames:"
head -n 3 "$BASENAMES_FILE"

# For each unique basename, find the row with highest After %
while read basename; do
    awk -F'\t' -v basename="$basename" '
    $1 ~ "^" basename "_R[12]" {
        # Convert After % to numeric value for comparison
        after_pct = $4;
        gsub(/%/, "", after_pct);  # Remove % sign if present
        if (after_pct != "N/A") {
            val = after_pct + 0;   # Convert to number
            if (val > max_val || !max_set) {
                max_val = val;
                max_line = $0;
                max_set = 1;
            }
        } else if (!max_set) {
            max_line = $0;  # Keep at least one line even if N/A
            max_set = 1;
        }
    }
    END {
        if (max_line) print max_line;
        else print "No matching rows found for " basename > "/dev/stderr";
    }' "$SORTED_FILE" >> "$OUTPUT_FILE"
done <"$BASENAMES_FILE"

echo "Output file line count: $(wc -l < "$OUTPUT_FILE")"

# Format the file as a pretty table using column command
if command -v column &> /dev/null; then
    column -t -s $'\t' "$OUTPUT_FILE" > "${OUTPUT_FILE%.txt}_formatted.txt"
    echo "Formatted table saved to ${OUTPUT_FILE%.txt}_formatted.txt"
fi

# Clean up temporary files
rm -f "$SORTED_FILE" "$BASENAMES_FILE"

echo "Processing complete. Best replicates saved to $OUTPUT_FILE"
