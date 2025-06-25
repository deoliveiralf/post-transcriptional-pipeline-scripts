#!/usr/bin/env python3

import csv
import sys

def process_files(mirna_file, annotation_file, output_file):
    # Read miRNA data
    mirna_data = []

    with open(mirna_file, 'r') as f:
        reader = csv.reader(f, delimiter='\t')

        # Read header and print it to debug
        header = next(reader)
        print("miRNA file headers:", header)

        # Find the indices of the columns we need
        # Use case-insensitive matching and handle potential whitespace
        mirna_id_index = None
        gene_index = None

        for i, col in enumerate(header):
            if col.strip().lower() == "mirna id":
                mirna_id_index = i
            elif col.strip().lower() == "gene":
                gene_index = i

        if mirna_id_index is None or gene_index is None:
            print("Error: Could not find 'miRNA ID' or 'Gene' columns in miRNA file")
            print("Available columns:", header)
            return

        print(f"Found miRNA ID at index {mirna_id_index} and Gene at index {gene_index}")

        # Read data rows
        for row in reader:
            print(f"Processing miRNA row: {row}")
            if len(row) > max(mirna_id_index, gene_index):
                mirna_id = row[mirna_id_index].strip()
                gene = row[gene_index].strip()
                # Extract the gene part (without version number) if present
                gene_base = gene.split('.')[0] if '.' in gene else gene
                mirna_data.append((mirna_id, gene, gene_base))

    print(f"Loaded {len(mirna_data)} miRNA entries")

    # Read annotation data
    annotation_data = {}

    with open(annotation_file, 'r') as f:
        reader = csv.reader(f, delimiter='\t')

        # Read header and print it to debug
        header = next(reader)
        print("Annotation file headers:", header)

        # Find the indices of the columns we need
        # Use case-insensitive matching and handle potential whitespace
        setaria_id_index = None
        function_index = None

        for i, col in enumerate(header):
            if col.strip().lower() == "setaria viridis id":
                setaria_id_index = i
            elif col.strip().lower() == "function":
                function_index = i

        if setaria_id_index is None or function_index is None:
            print("Error: Could not find 'Setaria viridis ID' or 'Function' columns in annotation file")
            print("Available columns:", header)
            return

        print(f"Found Setaria ID at index {setaria_id_index} and Function at index {function_index}")

        # Read data rows
        for row in reader:
            print(f"Processing annotation row: {row}")
            if len(row) > max(setaria_id_index, function_index):
                setaria_id = row[setaria_id_index].strip()
                function = row[function_index].strip()

                # Store function for each gene ID
                annotation_data[setaria_id] = function

    print(f"Loaded {len(annotation_data)} annotation entries")
    print(f"Annotation data: {annotation_data}")

    # Generate output
    output_rows = []
    with open(output_file, 'w') as f:
        writer = csv.writer(f, delimiter='\t')
        writer.writerow(["miRNA ID", "Gene", "Function"])

        for mirna_id, original_gene, gene_base in mirna_data:
            print(f"Looking up gene: {gene_base}")
            # Try exact match first
            function = annotation_data.get(gene_base, "")

            # If no match, try without version number
            if not function and '.' in original_gene:
                base_gene = original_gene.split('.')[0]
                function = annotation_data.get(base_gene, "")
                print(f"Trying base gene: {base_gene}, found function: {function}")

            if function:  # Only output if function is found
                print(f"Match found: {mirna_id}, {gene_base}, {function}")
                writer.writerow([mirna_id, gene_base, function])
                output_rows.append([mirna_id, gene_base, function])

    print(f"Generated {len(output_rows)} output rows")
    return output_rows

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python filter_script.py <mirna_file.tsv> <annotation_file.tsv> <output_file.tsv>")
        sys.exit(1)

    mirna_file = sys.argv[1]
    annotation_file = sys.argv[2]
    output_file = sys.argv[3]

    print(f"Processing files: {mirna_file}, {annotation_file}, {output_file}")
    results = process_files(mirna_file, annotation_file, output_file)

    if not results or len(results) == 0:
        print("Warning: No matching entries found!")
        print("Please check that:")
        print("1. The column names exactly match 'miRNA ID', 'Gene', 'Setaria viridis ID', and 'Function'")
        print("2. The gene IDs in the miRNA file match the Setaria viridis IDs in the annotation file")
        print("3. There are no extra spaces or special characters in the data")
