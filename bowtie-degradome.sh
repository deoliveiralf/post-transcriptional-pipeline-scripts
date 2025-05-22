#!/bin/bash
#SBATCH --job-name=bowtie_alignment
#SBATCH --output=bowtie_alignment_%j.log
#SBATCH --error=bowtie_alignment_%j.err
#SBATCH --time=24:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G

# Load required modules (modify according to your system)
module load samtools/1.21

# Define paths
INPUT_FILE=/temporario2/8412199/small-degradome-seq/degradome-libraries/trimmed-data/P_18.fq.gz
OUTPUT_DIR=/temporario2/8412199/small-degradome-seq/degradome-libraries/bowtie-trimmed-results/
GENOME_INDEX=/temporario2/8412199/slurm-tools/reference-to-bowtie/01-rRNA-index/index_base_name
REPORT_DIR=${OUTPUT_DIR}/reports
LOGS_DIR=${OUTPUT_DIR}/logs
ALIGNMENT_DIR=${OUTPUT_DIR}/alignments
UNALIGNED_DIR=${OUTPUT_DIR}/unaligned

# Create output directories
mkdir -p ${OUTPUT_DIR}
mkdir -p ${REPORT_DIR}
mkdir -p ${LOGS_DIR}
mkdir -p ${ALIGNMENT_DIR}
mkdir -p ${UNALIGNED_DIR}

# Get sample name (remove file extension)
FILE=$(basename "${INPUT_FILE}")
SAMPLE_NAME=$(basename "${FILE}" .fq.gz)

echo "Processing sample: ${SAMPLE_NAME}"

# Create unaligned fastq output paths
UNALIGNED_FASTQ="${UNALIGNED_DIR}/${SAMPLE_NAME}_unaligned.fastq"

# Run bowtie alignment with --un to keep unaligned reads
bowtie \
    -q \
    -p 8 \
    --phred33-quals \
    -m 1 \
    --best \
    --strata \
    -e 70 \
    -l 28 \
    -n 2 \
    --un ${UNALIGNED_FASTQ} \
    --sam \
    ${GENOME_INDEX} \
    <(zcat ${INPUT_FILE}) \
    ${ALIGNMENT_DIR}/${SAMPLE_NAME}.sam \
    2> ${LOGS_DIR}/${SAMPLE_NAME}_bowtie.log

# Compress unaligned reads
gzip ${UNALIGNED_FASTQ}

# Convert SAM to BAM
samtools view -bS ${ALIGNMENT_DIR}/${SAMPLE_NAME}.sam > ${ALIGNMENT_DIR}/${SAMPLE_NAME}.bam

# Sort BAM file
samtools sort ${ALIGNMENT_DIR}/${SAMPLE_NAME}.bam -o ${ALIGNMENT_DIR}/${SAMPLE_NAME}.sorted.bam

# Index BAM file
samtools index ${ALIGNMENT_DIR}/${SAMPLE_NAME}.sorted.bam

# Generate alignment statistics
samtools flagstat ${ALIGNMENT_DIR}/${SAMPLE_NAME}.sorted.bam > ${REPORT_DIR}/${SAMPLE_NAME}_flagstat.txt

# Count unaligned reads
UNALIGNED_COUNT=$(zcat ${UNALIGNED_FASTQ}.gz | awk 'NR%4==1' | wc -l)
echo "Unaligned reads for ${SAMPLE_NAME}: ${UNALIGNED_COUNT}" >> ${REPORT_DIR}/${SAMPLE_NAME}_alignment_summary.txt

# Append alignment rate to summary file
grep "overall alignment rate" ${LOGS_DIR}/${SAMPLE_NAME}_bowtie.log >> ${REPORT_DIR}/${SAMPLE_NAME}_alignment_summary.txt

# Optional: Remove SAM and unsorted BAM to save space
rm ${ALIGNMENT_DIR}/${SAMPLE_NAME}.sam
rm ${ALIGNMENT_DIR}/${SAMPLE_NAME}.bam

echo "Sample ${SAMPLE_NAME} processed successfully!"