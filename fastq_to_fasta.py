#!/usr/bin/env python3
import sys

def fastq_to_fasta(input_file, output_file):
    with open(input_file, 'r') as fin, open(output_file, 'w') as fout:
        line_count = 0
        for line in fin:
            line_count += 1
            if line_count % 4 == 1:  # Header line in FASTQ
                fout.write('>' + line[1:])  # Replace @ with > for FASTA
            elif line_count % 4 == 2:  # Sequence line in FASTQ
                fout.write(line)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python fastq_to_fasta.py input.fastq output.fasta")
        sys.exit(1)
    fastq_to_fasta(sys.argv[1], sys.argv[2])