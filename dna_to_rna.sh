#!/bin/bash

# Script to convert DNA sequences to RNA sequences (replacing T with U)
# Usage: ./dna_to_rna.sh input_file [output_file]

# Check if input file was provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 input_file [output_file]"
    echo "If output_file is not specified, output will be printed to stdout"
    exit 1
fi

input_file="$1"

# Check if input file exists
if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' not found"
    exit 1
fi

# Determine output destination
if [ $# -ge 2 ]; then
    output_file="$2"
    # Convert DNA to RNA (replacing T with U) and write to output file
    sed 's/[Tt]/U/g' "$input_file" > "$output_file"
    echo "Conversion complete. RNA sequence saved to '$output_file'"
else
    # Convert DNA to RNA (replacing T with U) and print to stdout
    echo "RNA sequence:"
    sed 's/[Tt]/U/g' "$input_file"
fi