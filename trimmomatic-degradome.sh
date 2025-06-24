#!/bin/bash
#SBATCH --job-name=trimmomatic_trim
#SBATCH --output=trimmomatic_trim_%j.log
#SBATCH --error=trimmomatic_trim_%j.err
#SBATCH --time=24:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G

# Define paths
INPUT_FILE=/path/to/your/directory/*.fq.gz
OUTPUT_DIR=/path/to/your/directory/trimmed-data
ADAPTERS_DIR=/path/to/your/directory/Trimmomatic-0.39/adapters
TRIMMOMATIC_JAR=/path/to/your/directory/Trimmomatic-0.39/trimmomatic-0.39.jar
REPORT_DIR=${OUTPUT_DIR}/reports
LOGS_DIR=${OUTPUT_DIR}/logs

# Create output directories
mkdir -p ${OUTPUT_DIR}
mkdir -p ${REPORT_DIR}
mkdir -p ${LOGS_DIR}

# Get sample name (remove file extension)
FILE=$(basename "${INPUT_FILE}")
SAMPLE_NAME=$(basename "${FILE}" .fq.gz)

echo "Processing sample: ${SAMPLE_NAME}"

# Define output file paths
OUTPUT_FILE="${OUTPUT_DIR}/${SAMPLE_NAME}_trimmed.fq.gz"
TRIMMOMATIC_LOG="${LOGS_DIR}/${SAMPLE_NAME}_trimmomatic.log"

# Run Trimmomatic
java -jar ${TRIMMOMATIC_JAR} SE -threads 8 \
    ${INPUT_FILE} ${OUTPUT_FILE} \
    ILLUMINACLIP:${ADAPTERS_DIR}/TruSeq3-SE.fa:2:30:10 \
    LEADING:3 \
    TRAILING:3 \
    SLIDINGWINDOW:4:15 \
    MINLEN:36 \
    2> ${TRIMMOMATIC_LOG}

# Generate a summary report
echo "Trimmomatic Summary for ${SAMPLE_NAME}" > ${REPORT_DIR}/${SAMPLE_NAME}_trimmomatic_summary.txt
echo "------------------------------------------------" >> ${REPORT_DIR}/${SAMPLE_NAME}_trimmomatic_summary.txt
grep "Input Read Pairs" ${TRIMMOMATIC_LOG} >> ${REPORT_DIR}/${SAMPLE_NAME}_trimmomatic_summary.txt
grep "Both Surviving" ${TRIMMOMATIC_LOG} >> ${REPORT_DIR}/${SAMPLE_NAME}_trimmomatic_summary.txt
grep "Forward Only Surviving" ${TRIMMOMATIC_LOG} >> ${REPORT_DIR}/${SAMPLE_NAME}_trimmomatic_summary.txt
grep "Dropped" ${TRIMMOMATIC_LOG} >> ${REPORT_DIR}/${SAMPLE_NAME}_trimmomatic_summary.txt

echo "Sample ${SAMPLE_NAME} processed successfully!"
