#!/bin/bash

# Function to get list of unprocessed files
get_unprocessed_files() {
    local input_files=($(find "${INPUT_DIR}" -maxdepth 1 \( -name "*.fastq.gz" -o -name "*.fq.gz" \) | sort))
    local unprocessed_files=()

    for file in "${input_files[@]}"; do
        local base_name=$(basename "${file}" .fastq.gz)
        base_name=$(basename "${base_name}" .fq.gz)
        local output_file="${FASTP_DIR}/${base_name}_trimmed.fastq.gz"
        local json_report="${REPORT_DIR}/${base_name}_fastp.json"

        # Check if both output file and report exist and are not empty
        if [ ! -s "${output_file}" ] || [ ! -s "${json_report}" ]; then
            unprocessed_files+=("${file}")
        fi
    done

    # Print the unprocessed files (one per line)
    printf "%s\n" "${unprocessed_files[@]}"
}

# Function to get the number of remaining files
get_remaining_files() {
    get_unprocessed_files | wc -l
}

# Function to check if there are running jobs from this script
check_running_jobs() {
    local running_jobs=$(squeue -u $USER -h -t running,pending -o "%i" | wc -l)
    echo $running_jobs
}

# Function to submit the next batch
submit_next_batch() {
    local remaining_files=$(get_remaining_files)
    if [ ${remaining_files} -gt 0 ]; then
        # Calculate how many jobs we can submit (leaving some buffer)
        local current_jobs=$(check_running_jobs)
        local available_slots=$((19 - current_jobs)) # Leave 1 slot as buffer

        if [ ${available_slots} -le 0 ]; then
            echo "No available job slots. Maximum limit reached."
            return 1
        fi

        # Calculate batch size based on available slots
        local batch_size=${available_slots}
        if [ ${batch_size} -gt ${remaining_files} ]; then
            batch_size=${remaining_files}
        fi

        local max_index=$((batch_size - 1))

        echo "Submitting new batch with array range 0-${max_index} (${batch_size} jobs)"
        # Get the last job ID if exists
        local last_job_id=$(squeue -u $USER -h -o "%i" | tail -n1)

        if [ -n "$last_job_id" ]; then
            sbatch --depend=afterany:${last_job_id} --array=0-${max_index} $0
        else
            sbatch --array=0-${max_index} $0
        fi
    else
        echo "No more files to process"
    fi
}

# SLURM directives
#SBATCH --job-name=fastp_qc
#SBATCH --output=fastp_%A_%a.out
#SBATCH --error=fastp_%A_%a.err
#SBATCH --time=6:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G

# Directory setup - do this early as it's needed for file checking
INPUT_DIR="/temporario2/8412199/small-degradome-seq/degradome-libraries"
OUTPUT_DIR="/temporario2/8412199/small-degradome-seq/degradome-libraries/fastp-data"
FASTP_DIR="${OUTPUT_DIR}/fastp_trimmed"
QC_DIR="${OUTPUT_DIR}/fastqc_results"
LOG_DIR="${OUTPUT_DIR}/logs"
REPORT_DIR="${OUTPUT_DIR}/reports"

# Create necessary directories
mkdir -p ${OUTPUT_DIR} ${FASTP_DIR} ${QC_DIR} ${LOG_DIR} ${REPORT_DIR}

# If this is the initial run (no SLURM_ARRAY_TASK_ID)
if [ -z "$SLURM_ARRAY_TASK_ID" ]; then
    submit_next_batch
    exit 0
fi

# Print job information
echo "Started on: $(date)"
echo "SLURM_JOB_ID = $SLURM_JOB_ID"
echo "SLURM_ARRAY_JOB_ID = $SLURM_ARRAY_JOB_ID"
echo "SLURM_ARRAY_TASK_ID = $SLURM_ARRAY_TASK_ID"
echo "SLURM_ARRAY_TASK_COUNT = $SLURM_ARRAY_TASK_COUNT"
echo "SLURM_ARRAY_TASK_MAX = $SLURM_ARRAY_TASK_MAX"

# Get list of unprocessed files
mapfile -t FILES < <(get_unprocessed_files)

# Print all found files for this batch
echo "Files to be processed in this batch:"
for file in "${FILES[@]}"; do
    echo "  $(basename "$file")"
done

# Check if we have enough files for this task ID
if [ ${SLURM_ARRAY_TASK_ID} -ge ${#FILES[@]} ]; then
    echo "No file to process for task ID ${SLURM_ARRAY_TASK_ID}"
    exit 0
fi

# Get current file
INPUT_FILE="${FILES[${SLURM_ARRAY_TASK_ID}]}"
SAMPLE_NAME=$(basename "${INPUT_FILE}" .fastq.gz)
SAMPLE_NAME=$(basename "${SAMPLE_NAME}" .fq.gz)
echo "Processing file: $SAMPLE_NAME"
echo "Input file: $INPUT_FILE"  # Diagnostic echo statement

# Output file names
TRIMMED_FILE="${FASTP_DIR}/${SAMPLE_NAME}_trimmed.fastq.gz"
HTML_REPORT="${REPORT_DIR}/${SAMPLE_NAME}_fastp.html"
JSON_REPORT="${REPORT_DIR}/${SAMPLE_NAME}_fastp.json"
LOG_FILE="${LOG_DIR}/${SAMPLE_NAME}_fastp.log"

# Load the required modules
module load fastp

# Run fastp
echo "Running fastp on ${SAMPLE_NAME}"
fastp \
    --in1 ${INPUT_FILE} \
    --out1 ${TRIMMED_FILE} \
    --report_title "${SAMPLE_NAME}" \
    --html ${HTML_REPORT} \
    --json ${JSON_REPORT} \
    -q 30 \
    -l 15 \
    --length_limit 40 \
    --adapter_sequence=AGATCGGAAGAGCACACGTCT \
    --trim_poly_g \
    --poly_g_min_len 10 \
    --low_complexity_filter \
    --overrepresentation_analysis \
    -h \
    --thread 4 \
    2>&1 | tee ${LOG_FILE}

# Check if fastp was successful
if [ $? -ne 0 ]; then
    echo "Error in fastp processing for ${SAMPLE_NAME}"
    exit 1
fi

# Run FastQC on trimmed file
echo "Running FastQC on trimmed file"
fastqc \
    --outdir ${QC_DIR} \
    --threads 4 \
    ${TRIMMED_FILE}

# Check if FastQC was successful
if [ $? -ne 0 ]; then
    echo "Error in FastQC processing for ${SAMPLE_NAME}"
    exit 1
fi

echo "All processing completed for ${SAMPLE_NAME}"
echo "Finished on: $(date)"

# If this is the last job in the array, submit next batch
if [ "${SLURM_ARRAY_TASK_ID}" -eq "${SLURM_ARRAY_TASK_MAX}" ]; then
    # Wait a short time to ensure job status is updated
    sleep 30

    remaining_files=$(get_remaining_files)
    if [ ${remaining_files} -gt 0 ]; then
        echo "This was the last job in the current batch. Attempting to submit next batch..."
        submit_next_batch
    else
        echo "All files have been processed."
    fi
fi