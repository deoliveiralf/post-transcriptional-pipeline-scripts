#!/bin/bash
#SBATCH --job-name=sequential_bowtie
#SBATCH --output=sequential_bowtie_%j.log
#SBATCH --error=sequential_bowtie_%j.err
#SBATCH --time=48:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G

# Load required modules
module load samtools/1.21

# Define base paths
BASE_INPUT_DIR=/temporario2/8412199/small-degradome-seq/small-libraries/fastp-best_replicates
BASE_OUTPUT_DIR=/temporario2/8412199/small-degradome-seq/small-libraries/fastp-bowtie-remade
REFERENCE_BASE_DIR=/temporario2/8412199/slurm-tools/reference-to-bowtie/

# Define reference genome indices in order
REFERENCES=(
    "01-rRNA-index"
    "02-tRNA-index"
    "03-snRNA-index"
    "04-snoRNA-index"
    "05-tmRNA-index"
    "06-scRNA-index"
)

echo "Starting sequential RNA filtering workflow..."

for ((i=0; i<${#REFERENCES[@]}; i++)); do
    CURRENT_REF=${REFERENCES[$i]}

    echo "===================================="
    echo "Processing round $((i+1)): ${CURRENT_REF}"
    echo "===================================="

    # Set up input and output directories for this round
    if [ $i -eq 0 ]; then
        # First round: use trimmed fastq files
        INPUT_DIR=${BASE_INPUT_DIR}
        FILE_PATTERN="*_trimmed.fastq.gz"
        FILE_SUFFIX="_R1_001_trimmed.fastq.gz"
    else
        # Subsequent rounds: use unaligned files from previous round
        PREV_REF=${REFERENCES[$((i-1))]}
        INPUT_DIR=${BASE_OUTPUT_DIR}/bowtie-${PREV_REF}/unaligned/
        FILE_PATTERN="*_unaligned.fastq.gz"
        FILE_SUFFIX="_unaligned.fastq.gz"
    fi

    # Set up output directory for this round
    OUTPUT_DIR=${BASE_OUTPUT_DIR}/bowtie-${CURRENT_REF}
    GENOME_INDEX=${REFERENCE_BASE_DIR}/${CURRENT_REF}/index_base_name
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

    # Find input files
    echo "Searching for ${FILE_PATTERN} files in ${INPUT_DIR}..."
    FILES=($(find ${INPUT_DIR} -name "${FILE_PATTERN}" | sort))

    if [ ${#FILES[@]} -eq 0 ]; then
        echo "Error: No ${FILE_PATTERN} files found in ${INPUT_DIR}"
        exit 1
    fi

    echo "Found ${#FILES[@]} files for processing in round $((i+1))."

   # Process each file
    for FILE_PATH in "${FILES[@]}"; do
        # Get the filename without the path
        FILE=$(basename "${FILE_PATH}")

        # Get sample name (remove file extension)
        SAMPLE_NAME=$(basename "${FILE}" ${FILE_SUFFIX})

        echo "Processing sample: ${SAMPLE_NAME}"

        # Create unaligned fastq output path
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
            <(zcat ${FILE_PATH}) \
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

        # Remove SAM and unsorted BAM to save space
        rm ${ALIGNMENT_DIR}/${SAMPLE_NAME}.sam
        rm ${ALIGNMENT_DIR}/${SAMPLE_NAME}.bam
    done

    echo "Round $((i+1)) (${CURRENT_REF}) completed successfully!"
done

echo "All sequential alignment rounds completed successfully!"
echo "Workflow summary:"
for ((i=0; i<${#REFERENCES[@]}; i++)); do
    echo "Round $((i+1)): ${REFERENCES[$i]}"
done
