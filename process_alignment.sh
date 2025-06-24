#!/bin/bash
#SBATCH --job-name=final_alignment_summary
#SBATCH --output=final_alignment_summary_%j.out
#SBATCH --error=final_alignment_summary_%j.err
#SBATCH --time=2:00:00
#SBATCH --mem=8G

# Define directories
BASE_DIR="/path/to/your/directory/"
OUTPUT_DIR="/path/to/your/directory/alignment_summaries"
TOTAL_READS_FILE="/path/to/your/directory/logs/best_replicates_summary.txt"
SUBDIRS=("bowtie-01-rRNA" "bowtie-02-tRNA" "bowtie-03-snRNA" "bowtie-04-snoRNA" "bowtie-05-tmRNA" "bowtie-06-scRNA")

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Output files
OUTPUT_FILE="$OUTPUT_DIR/final_alignment_summary.tsv"
FORMATTED_FILE="$OUTPUT_DIR/final_alignment_summary_formatted.tsv"

# Function to calculate percentage
calculate_percentage() {
    local part=$1
    local total=$2
    if [[ "$part" =~ ^[0-9]+$ ]] && [[ "$total" =~ ^[0-9]+$ ]] && [[ $total -ne 0 ]]; then
        echo $(awk -v p="$part" -v t="$total" 'BEGIN {printf "%.2f", (p/t)*100}')
    else
        echo ""
    fi
}

# Step 1: Get sample order and total reads
declare -A TOTAL_READS
declare -A SAMPLE_GROUPS
SAMPLE_ORDER=()

while IFS=$'\t' read -r sample total_before total_after rest; do
    sample_name=${sample%_R1_001_fastp.log}
    TOTAL_READS["$sample_name"]=$total_after
    SAMPLE_ORDER+=("$sample_name")
    group=${sample_name:0:2}
    SAMPLE_GROUPS["$group"]=1
done < <(tail -n +2 "$TOTAL_READS_FILE")

SAMPLE_GROUP_LIST=($(printf "%s\n" "${!SAMPLE_GROUPS[@]}" | sort))

# Step 2: Create header
{
    echo -ne "Sample\tTotal_reads\tInitial_percentage"
    for subdir in "${SUBDIRS[@]}"; do
        echo -ne "\t${subdir}_alignments\t${subdir}_%"
    done
    echo -ne "\tTotal_alignments\tTotal_alignments_%\tUnmatched_reads\tUnmatched_%\n"
} > "$OUTPUT_FILE"

# Initialize group totals
declare -A GROUP_TOTALS
declare -A GROUP_ALIGNMENTS
declare -A GROUP_UNMATCHED
declare -A GROUP_BOWTIE_TOTALS

for group in "${SAMPLE_GROUP_LIST[@]}"; do
    GROUP_TOTALS["$group"]=0
    GROUP_ALIGNMENTS["$group"]=0
    GROUP_UNMATCHED["$group"]=0
    for ((i=0; i<${#SUBDIRS[@]}; i++)); do
        GROUP_BOWTIE_TOTALS["${group}_${i}"]=0
    done
done

# Step 3: Process samples
for sample in "${SAMPLE_ORDER[@]}"; do
    group=${sample:0:2}
    LINE="$sample"
    TOTAL_READS_VALUE=${TOTAL_READS[$sample]}

    # Add total reads and initial percentage
    if [[ "$TOTAL_READS_VALUE" =~ ^[0-9]+$ ]]; then
        LINE+="\t$TOTAL_READS_VALUE\t100.00"
        GROUP_TOTALS["$group"]=$((GROUP_TOTALS["$group"] + TOTAL_READS_VALUE))
    else
        LINE+="\t\t"
    fi

    # Process each bowtie step
    TOTAL_ALIGNMENTS=0
    for ((i=0; i<${#SUBDIRS[@]}; i++)); do
        subdir="${SUBDIRS[$i]}"
        LOG_FILE="$BASE_DIR/$subdir/logs/${sample}_bowtie.log"
        ALIGNMENTS=""

        if [ -f "$LOG_FILE" ]; then
            ALIGNMENTS=$(grep -E "Reported [0-9]+ alignments" "$LOG_FILE" | awk '{print $2}')
            [ -z "$ALIGNMENTS" ] && ALIGNMENTS=$(grep -E "[0-9]+ alignments" "$LOG_FILE" | awk '{print $1}')
            [ -z "$ALIGNMENTS" ] && ALIGNMENTS=$(grep "alignments" "$LOG_FILE" | grep -oE "[0-9]+" | head -1)
        fi

        LINE+="\t$ALIGNMENTS"

        # Calculate percentage
        if [[ -n "$ALIGNMENTS" ]] && [[ "$ALIGNMENTS" =~ ^[0-9]+$ ]] && [[ "$TOTAL_READS_VALUE" =~ ^[0-9]+$ ]]; then
            PERCENTAGE=$(calculate_percentage "$ALIGNMENTS" "$TOTAL_READS_VALUE")
            LINE+="\t$PERCENTAGE"
            GROUP_BOWTIE_TOTALS["${group}_${i}"]=$((GROUP_BOWTIE_TOTALS["${group}_${i}"] + ALIGNMENTS))
            TOTAL_ALIGNMENTS=$((TOTAL_ALIGNMENTS + ALIGNMENTS))
        else
            LINE+="\t"
        fi
    done

    # Calculate totals
    if [[ "$TOTAL_ALIGNMENTS" -gt 0 ]]; then
        LINE+="\t$TOTAL_ALIGNMENTS"
        GROUP_ALIGNMENTS["$group"]=$((GROUP_ALIGNMENTS["$group"] + TOTAL_ALIGNMENTS))

        if [[ "$TOTAL_READS_VALUE" =~ ^[0-9]+$ ]]; then
            PERCENTAGE=$(calculate_percentage "$TOTAL_ALIGNMENTS" "$TOTAL_READS_VALUE")
            LINE+="\t$PERCENTAGE"
        else
            LINE+="\t"
        fi
    else
        LINE+="\t\t"
    fi

    # Calculate unmatched reads
    if [[ "$TOTAL_READS_VALUE" =~ ^[0-9]+$ ]]; then
        UNMATCHED=$((TOTAL_READS_VALUE - TOTAL_ALIGNMENTS))
        LINE+="\t$UNMATCHED"
        GROUP_UNMATCHED["$group"]=$((GROUP_UNMATCHED["$group"] + UNMATCHED))

        PERCENTAGE=$(calculate_percentage "$UNMATCHED" "$TOTAL_READS_VALUE")
        LINE+="\t$PERCENTAGE"
    else
        LINE+="\t\t"
    fi

    echo -e "$LINE" >> "$OUTPUT_FILE"
done

# Step 4: Add group totals
for group in "${SAMPLE_GROUP_LIST[@]}"; do
    GROUP_LINE="${group}_total"
    GROUP_TOTAL=${GROUP_TOTALS[$group]}
    GROUP_ALIGN=${GROUP_ALIGNMENTS[$group]}
    GROUP_UNM=${GROUP_UNMATCHED[$group]}

    GROUP_LINE+="\t$GROUP_TOTAL\t100.00"

    # Add bowtie step totals
    for ((i=0; i<${#SUBDIRS[@]}; i++)); do
        BOWTIE_TOTAL=${GROUP_BOWTIE_TOTALS["${group}_${i}"]}
        GROUP_LINE+="\t$BOWTIE_TOTAL"

        PERCENTAGE=$(calculate_percentage "$BOWTIE_TOTAL" "$GROUP_TOTAL")
        GROUP_LINE+="\t$PERCENTAGE"
    done

    # Add group totals for alignments and unmatched
    GROUP_ALIGN_PERC=$(calculate_percentage "$GROUP_ALIGN" "$GROUP_TOTAL")
    GROUP_UNM_PERC=$(calculate_percentage "$GROUP_UNM" "$GROUP_TOTAL")

    GROUP_LINE+="\t$GROUP_ALIGN\t$GROUP_ALIGN_PERC\t$GROUP_UNM\t$GROUP_UNM_PERC"

    echo -e "$GROUP_LINE" >> "$OUTPUT_FILE"
done

# Step 5: Add grand total
GRAND_TOTAL=0
GRAND_ALIGN=0
GRAND_UNM=0
declare -a GRAND_BOWTIE_TOTALS
for ((i=0; i<${#SUBDIRS[@]}; i++)); do
    GRAND_BOWTIE_TOTALS[$i]=0
done

for group in "${SAMPLE_GROUP_LIST[@]}"; do
    GRAND_TOTAL=$((GRAND_TOTAL + ${GROUP_TOTALS[$group]}))
    GRAND_ALIGN=$((GRAND_ALIGN + ${GROUP_ALIGNMENTS[$group]}))
    GRAND_UNM=$((GRAND_UNM + ${GROUP_UNMATCHED[$group]}))

    for ((i=0; i<${#SUBDIRS[@]}; i++)); do
        GRAND_BOWTIE_TOTALS[$i]=$((GRAND_BOWTIE_TOTALS[$i] + ${GROUP_BOWTIE_TOTALS["${group}_${i}"]}))
    done
done

GRAND_LINE="Grand_total\t$GRAND_TOTAL\t100.00"

# Add grand totals for each bowtie step
for ((i=0; i<${#SUBDIRS[@]}; i++)); do
    GRAND_LINE+="\t${GRAND_BOWTIE_TOTALS[$i]}"
    PERCENTAGE=$(calculate_percentage "${GRAND_BOWTIE_TOTALS[$i]}" "$GRAND_TOTAL")
    GRAND_LINE+="\t$PERCENTAGE"
done

# Add grand totals for alignments and unmatched
GRAND_ALIGN_PERC=$(calculate_percentage "$GRAND_ALIGN" "$GRAND_TOTAL")
GRAND_UNM_PERC=$(calculate_percentage "$GRAND_UNM" "$GRAND_TOTAL")

GRAND_LINE+="\t$GRAND_ALIGN\t$GRAND_ALIGN_PERC\t$GRAND_UNM\t$GRAND_UNM_PERC"

echo -e "$GRAND_LINE" >> "$OUTPUT_FILE"

# Step 6: Format the table
if command -v column &> /dev/null; then
    column -t -s $'\t' "$OUTPUT_FILE" > "$FORMATTED_FILE"
    echo "Final alignment summary saved to:"
    echo "  $FORMATTED_FILE"
else
    echo "Final alignment summary saved to:"
    echo "  $OUTPUT_FILE"
fi
