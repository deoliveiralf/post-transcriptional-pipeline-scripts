#!/bin/bash
#SBATCH --job-name=extract_fastp_logs
#SBATCH --output=extract_fastp_logs.out
#SBATCH --error=extract_fastp_logs.err
#SBATCH --time=1:00:00
#SBATCH --mem=4G

# Define the input directory
INPUT_DIR="/temporario2/8412199/slurm-tools/small-libraries/fastp-data-2/logs"
OUTPUT_FILE="/temporario2/8412199/slurm-tools/small-libraries/fastp-data-2/logs/fastp_summary_with_percentages.txt"

# Initialize the output file with header
echo -e "File\tTotal Reads Before\tTotal Reads After\tAfter %\tPassed Filter\tPassed %\tFailed Low Quality\tLow Quality %\tFailed Too Many N\tToo Many N %\tFailed Too Short\tToo Short %\tFailed Too Long\tToo Long %" > $OUTPUT_FILE

# Process each log file
for log_file in $INPUT_DIR/*.log; do
    if [ -f "$log_file" ]; then
        filename=$(basename "$log_file")

        # Extract raw values using grep and awk
        before=$(grep -A1 "Read1 before filtering:" "$log_file" | grep "total reads:" | awk '{print $3}')
        after=$(grep -A1 "Read1 after filtering:" "$log_file" | grep "total reads:" | awk '{print $3}')

        passed=$(grep "reads passed filter:" "$log_file" | awk '{print $4}')
        failed_quality=$(grep "reads failed due to low quality:" "$log_file" | awk '{print $7}')
        failed_n=$(grep "reads failed due to too many N:" "$log_file" | awk '{print $8}')
        failed_short=$(grep "reads failed due to too short:" "$log_file" | awk '{print $7}')
        failed_long=$(grep "reads failed due to too long:" "$log_file" | awk '{print $7}')

        # Calculate percentages with 4 decimal places (using bc for floating point arithmetic)
        if [ -n "$before" ] && [ "$before" -ne 0 ]; then
            after_pct=$(echo "scale=4; 100 * $after / $before" | bc -l)
            passed_pct=$(echo "scale=4; 100 * $passed / $before" | bc -l)
            quality_pct=$(echo "scale=4; 100 * $failed_quality / $before" | bc -l)
            n_pct=$(echo "scale=4; 100 * $failed_n / $before" | bc -l)
            short_pct=$(echo "scale=4; 100 * $failed_short / $before" | bc -l)
            long_pct=$(echo "scale=4; 100 * $failed_long / $before" | bc -l)
        else
            after_pct="N/A"
            passed_pct="N/A"
            quality_pct="N/A"
            n_pct="N/A"
            short_pct="N/A"
            long_pct="N/A"
        fi

        # Write to output file
        echo -e "$filename\t$before\t$after\t$after_pct\t$passed\t$passed_pct\t$failed_quality\t$quality_pct\t$failed_n\t$n_pct\t$failed_short\t$short_pct\t$failed_long\t$long_pct" >> $OUTPUT_FILE
    fi
done

# Print completion message
echo "Processing complete. Results saved to $OUTPUT_FILE"

# Format the file as a pretty table using column command
if command -v column &> /dev/null; then
    column -t -s $'\t' $OUTPUT_FILE > "${OUTPUT_FILE%.txt}_formatted.txt"
    echo "Formatted table saved to ${OUTPUT_FILE%.txt}_formatted.txt"
fi
