#!/bin/bash

# CleaveLand4 Wrapper Script with Logging and Detailed Progress Updates
# Usage: ./cleaveland_wrapper.sh

# Configuration
CLEAVELAND_PATH="/path/to/your/directory/CleaveLand4.pl"  # <-- ADD THIS LINE to set the path
LOG_FILE="cleaveland_run_$(date +%Y%m%d_%H%M%S).log"
PROGRESS_FILE="cleaveland_progress.tmp"
DEGRADOME_FILE="degradome_reads.fasta"
SMALL_RNA_FILE="Svi_small_reads.fasta"
TRANSCRIPTOME_FILE="transcriptome_reads.fasta"
OUTPUT_DIR="cleaveland_results"  # Directory to store results
OUTPUT_FILE="$OUTPUT_DIR/full_results.txt"  # Consolidated results file
DEBUG=true  # Set to true for additional debugging information

# Clean up any previous progress file
rm -f "$PROGRESS_FILE"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "Starting CleaveLand4 run at $(date)" | tee -a "$LOG_FILE"
echo "Parameters:" | tee -a "$LOG_FILE"
echo "  CleaveLand4 path: $CLEAVELAND_PATH" | tee -a "$LOG_FILE"
echo "  Degradome file: $DEGRADOME_FILE" | tee -a "$LOG_FILE"
echo "  Small RNA file: $SMALL_RNA_FILE" | tee -a "$LOG_FILE"
echo "  Transcriptome file: $TRANSCRIPTOME_FILE" | tee -a "$LOG_FILE"
echo "  Output directory: $OUTPUT_DIR" | tee -a "$LOG_FILE"
echo "  Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

# Verify input files exist
for file in "$CLEAVELAND_PATH" "$DEGRADOME_FILE" "$SMALL_RNA_FILE" "$TRANSCRIPTOME_FILE"; do
    if [ ! -f "$file" ]; then
        echo "ERROR: File not found: $file" | tee -a "$LOG_FILE"
        exit 1
    fi
done

# Verify CleaveLand4 script is executable
if [ ! -x "$CLEAVELAND_PATH" ]; then
    echo "WARNING: CleaveLand4 script is not executable. Attempting to fix..." | tee -a "$LOG_FILE"
    chmod +x "$CLEAVELAND_PATH"
    if [ ! -x "$CLEAVELAND_PATH" ]; then
        echo "ERROR: Could not make CleaveLand4 script executable." | tee -a "$LOG_FILE"
        exit 1
    fi
    echo "Fixed permissions on CleaveLand4 script." | tee -a "$LOG_FILE"
fi

# Count sequences to track progress
TOTAL_SMALL_RNA=$(grep -c "^>" "$SMALL_RNA_FILE")
TOTAL_TRANSCRIPTS=$(grep -c "^>" "$TRANSCRIPTOME_FILE")
echo "Total small RNAs: $TOTAL_SMALL_RNA" | tee -a "$LOG_FILE"
echo "Total transcripts: $TOTAL_TRANSCRIPTS" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

# Debug: Check file formats if debug is enabled
if [ "$DEBUG" = true ]; then
    echo "DEBUG: Checking file formats..." | tee -a "$LOG_FILE"
    echo "First 5 lines of degradome file:" | tee -a "$LOG_FILE"
    head -n 5 "$DEGRADOME_FILE" | tee -a "$LOG_FILE"
    echo "First 5 lines of small RNA file:" | tee -a "$LOG_FILE"
    head -n 5 "$SMALL_RNA_FILE" | tee -a "$LOG_FILE"
    echo "First 5 lines of transcriptome file:" | tee -a "$LOG_FILE"
    head -n 5 "$TRANSCRIPTOME_FILE" | tee -a "$LOG_FILE"
    echo "----------------------------------------" | tee -a "$LOG_FILE"
fi

# Launch CleaveLand4 with progress monitoring
START_TIME=$(date +%s)

# Progress monitoring function (run in background)
monitor_progress() {
    local current_srna=0
    local current_transcript=0
    local percent=0

    # Create empty progress file
    touch "$PROGRESS_FILE"

    # Monitor progress while the process runs
    while [ -f "$PROGRESS_FILE" ]; do
        # Check for new progress info in the log
        if grep -q "Processing sRNA" "$LOG_FILE"; then
            current_srna=$(grep -c "Processing sRNA" "$LOG_FILE")
            percent=$((current_srna * 100 / TOTAL_SMALL_RNA))

            # Update progress display
            printf "\rProcessing small RNA: %d/%d (%d%%) " "$current_srna" "$TOTAL_SMALL_RNA" "$percent"

            # Also check for transcript processing if we're in that phase
            if grep -q "Processing transcript" "$LOG_FILE"; then
                current_transcript=$(grep -c "Processing transcript" "$LOG_FILE")
                echo -n "| Transcripts: $current_transcript/$TOTAL_TRANSCRIPTS"
            fi
        elif grep -q "Processing transcript" "$LOG_FILE"; then
            # If we're only processing transcripts (different CleaveLand modes)
            current_transcript=$(grep -c "Processing transcript" "$LOG_FILE")
            percent=$((current_transcript * 100 / TOTAL_TRANSCRIPTS))
            printf "\rProcessing transcripts: %d/%d (%d%%) " "$current_transcript" "$TOTAL_TRANSCRIPTS" "$percent"
        else
            echo -n "."
        fi

        # Show elapsed time
        current_time=$(date +%s)
        elapsed=$((current_time - START_TIME))
        printf "| Elapsed: %02d:%02d:%02d" $((elapsed/3600)) $(((elapsed%3600)/60)) $((elapsed%60))

        sleep 2
    done
    echo # Final newline
}

# Start the progress monitor in background
monitor_progress &
MONITOR_PID=$!

# Build the CleaveLand4 command with all necessary parameters
CLEAVELAND_CMD=(
    "$CLEAVELAND_PATH"
    -e "$DEGRADOME_FILE"
    -u "$SMALL_RNA_FILE"
    -n "$TRANSCRIPTOME_FILE"
    -p 1  # P-value cutoff
    -c 4  # Category cutoff
    -o "$OUTPUT_DIR"  # Output directory
)

# Run CleaveLand4 with proper parameters
echo "Running CleaveLand4 with command:" | tee -a "$LOG_FILE"
echo "${CLEAVELAND_CMD[@]}" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

# Run the command and capture output to log AND to a results file
("${CLEAVELAND_CMD[@]}" 2>&1) | tee -a "$LOG_FILE" > "$OUTPUT_DIR/cleaveland_output.txt"

# Signal end of monitoring
rm -f "$PROGRESS_FILE"

# Allow the monitor thread to print final stats and terminate
sleep 1
kill $MONITOR_PID &>/dev/null

END_TIME=$(date +%s)
RUNTIME=$((END_TIME - START_TIME))
HOURS=$((RUNTIME / 3600))
MINUTES=$(( (RUNTIME % 3600) / 60 ))
SECONDS=$((RUNTIME % 60))

echo
echo "----------------------------------------" | tee -a "$LOG_FILE"
echo "CleaveLand4 run completed at $(date)" | tee -a "$LOG_FILE"
echo "Total runtime: ${HOURS}h ${MINUTES}m ${SECONDS}s" | tee -a "$LOG_FILE"

# Check if the output directory exists and contains files
if [ -d "$OUTPUT_DIR" ]; then
    # Look for any result files (PDFs or text files)
    OUTPUT_FILES=$(find "$OUTPUT_DIR" -type f | wc -l)
    echo "Output directory created with $OUTPUT_FILES files." | tee -a "$LOG_FILE"

    # List the output files
    echo "Output files:" | tee -a "$LOG_FILE"
    find "$OUTPUT_DIR" -type f -name "*" | sort | tee -a "$LOG_FILE"

    # Look for result files - including both TXT and PDF files
    RESULT_FILES=$(find "$OUTPUT_DIR" -type f \( -name "*.txt" -o -name "*.pdf" \) | wc -l)
    if [ "$RESULT_FILES" -gt 0 ]; then
        echo "Found $RESULT_FILES result files." | tee -a "$LOG_FILE"

        # Create a results summary file that includes the command output
        echo "# CleaveLand4 Combined Results" > "$OUTPUT_FILE"
        echo "# Generated on $(date)" >> "$OUTPUT_FILE"
        echo "# Original files in $OUTPUT_DIR" >> "$OUTPUT_FILE"
        echo "----------------------------------------" >> "$OUTPUT_FILE"

        # Add the main output file if it exists
        if [ -f "$OUTPUT_DIR/cleaveland_output.txt" ]; then
            echo "Adding contents from CleaveLand4 standard output" | tee -a "$LOG_FILE"
            echo "# CleaveLand4 Standard Output" >> "$OUTPUT_FILE"
            cat "$OUTPUT_DIR/cleaveland_output.txt" >> "$OUTPUT_FILE"
            echo "----------------------------------------" >> "$OUTPUT_FILE"
        fi

        # Add any other text files that might contain results
        for file in $(find "$OUTPUT_DIR" -type f -name "*.txt" -not -name "cleaveland_output.txt" | sort); do
            echo "Adding contents from $file" | tee -a "$LOG_FILE"
            echo "# File: $(basename "$file")" >> "$OUTPUT_FILE"
            cat "$file" >> "$OUTPUT_FILE"
            echo "----------------------------------------" >> "$OUTPUT_FILE"
        done

        # List PDF files
        echo "# PDF T-Plot files (not included in this text file):" >> "$OUTPUT_FILE"
        find "$OUTPUT_DIR" -type f -name "*.pdf" | sort | while read -r pdf_file; do
            echo "# - $(basename "$pdf_file")" >> "$OUTPUT_FILE"
        done

        echo "Combined results saved to $OUTPUT_FILE" | tee -a "$LOG_FILE"

        # Count cleavage sites in the output file
        if [ -f "$OUTPUT_DIR/cleaveland_output.txt" ]; then
            HITS=$(grep -c "^-\{5,\}" "$OUTPUT_DIR/cleaveland_output.txt" || echo "0")
            SLICES=$(grep -c "Slice Site:" "$OUTPUT_DIR/cleaveland_output.txt" || echo "0")

            if [ "$HITS" -gt 0 ] || [ "$SLICES" -gt 0 ]; then
                echo "Total predicted cleavage sites: $HITS" | tee -a "$LOG_FILE"
                echo "Total slice sites found: $SLICES" | tee -a "$LOG_FILE"
                echo "Run completed successfully with results!" | tee -a "$LOG_FILE"
            else
                echo "No cleavage sites were found in the output files." | tee -a "$LOG_FILE"
                echo "This may be expected if there are no matches between your sequences." | tee -a "$LOG_FILE"
            fi
        fi

        # Check for PDF T-plots
        PDF_FILES=$(find "$OUTPUT_DIR" -type f -name "*TPlot.pdf" | wc -l)
        if [ "$PDF_FILES" -gt 0 ]; then
            echo "Found $PDF_FILES T-Plot PDF files." | tee -a "$LOG_FILE"
            echo "These files contain visual representations of cleavage sites." | tee -a "$LOG_FILE"
        fi
    else
        echo "No result files were found in the output directory." | tee -a "$LOG_FILE"
        echo "Check the log file for errors." | tee -a "$LOG_FILE"
    fi
else
    echo "Output directory was not created or is empty." | tee -a "$LOG_FILE"
    echo "Check the log file for errors." | tee -a "$LOG_FILE"

    # Check for common error patterns in the log
    if grep -q "Error\|Failed\|Cannot\|Could not" "$LOG_FILE"; then
        echo "Found potential errors in the log file:" | tee -a "$LOG_FILE"
        grep -i "Error\|Failed\|Cannot\|Could not" "$LOG_FILE" | tail -10 | tee -a "$LOG_FILE"
    fi
fi

echo "----------------------------------------" | tee -a "$LOG_FILE"
echo "Complete log available in: $LOG_FILE"

# Summarize key findings
if [ -f "$OUTPUT_DIR/cleaveland_output.txt" ]; then
    echo "----------------------------------------" | tee -a "$LOG_FILE"
    echo "SUMMARY OF RESULTS:" | tee -a "$LOG_FILE"

    # Extract and display cleavage sites
    if grep -q "SiteID:" "$OUTPUT_DIR/cleaveland_output.txt"; then
        echo "Cleavage sites detected:" | tee -a "$LOG_FILE"
        grep "SiteID:" "$OUTPUT_DIR/cleaveland_output.txt" | tee -a "$LOG_FILE"

        # Count categories
        for cat in 0 1 2 3 4; do
            CAT_COUNT=$(grep -c "Degardome Category: $cat" "$OUTPUT_DIR/cleaveland_output.txt" || echo "0")
            if [ "$CAT_COUNT" -gt 0 ]; then
                echo "Category $cat sites: $CAT_COUNT" | tee -a "$LOG_FILE"
            fi
        done
    else
        echo "No cleavage sites were detected in the analysis." | tee -a "$LOG_FILE"
    fi
fi

echo "Analysis complete. Check $OUTPUT_FILE for detailed results."
