#!/bin/bash -v
#SBATCH --job-name=fastqc_analysis    # Job name
#SBATCH --partition=SP2
#SBATCH --ntasks=1                    # Run a single task
#SBATCH --cpus-per-task=4            # Number of CPU cores
#SBATCH --time=100:00:00              # Time limit hrs:min:sec
#SBATCH --output=fastqc_%j.log       # Standard output and error log

#OpenMP settings:
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OMP_PLACES=threads
export OMP_PROC_BIND=spread

# Print some information about the job
echo "SLURM_Job_ID = $SLURM_JOB_ID"
echo $SLURM_JOB_ID              #ID of job allocation
echo $SLURM_SUBMIT_DIR          #Directory job where was submitted
echo $SLURM_JOB_NODELIST        #File containing allocated hostnames
echo $SLURM_NTASKS              #Total number of cores for job
echo "Started on: $(date)"

# Load the required modules (modify according to your system)
module load fastqc/0.12.1

# Create output directory
OUTPUT_DIR="/temporario2/8412199/small-degradome-seq/degradome-libraries/fastqc-results"
mkdir -p $OUTPUT_DIR

# Directory containing your FASTQ files
INPUT_DIR="/temporario2/8412199/small-degradome-seq/degradome-libraries"

# Run FastQC on all FASTQ files in the input directory
./fastqc \
    --outdir $OUTPUT_DIR \
    --threads $SLURM_CPUS_PER_TASK \
    --noextract \
    ${INPUT_DIR}/*.{fq,fastq,fq.*}.gz

# Create a multiqc report if you have it installed
# module load multiqc
# multiqc $OUTPUT_DIR -o $OUTPUT_DIR/multiqc

echo "Finished on: $(date)"
~                                 