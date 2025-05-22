#!/usr/bin/env Rscript

# Script to filter EdgeR normalized counts using significant IDs from EdgeR analysis results

### File Path Configuration -----------------------------------------
# Set your working directory here
working_dir <- "C:/Users/Leandro/OneDrive - usp.br/LIGNINLAB/Projeto FAPESP CNPq - Setaria miRNAs/R analysis"
setwd(working_dir)

# Input files
edger_results_file <- file.path(working_dir, "5thx3th_DEGs.txt")  # Your EdgeR results table
norm_counts_file <- file.path(working_dir, "5thx3th.txt")  # Your EdgeR normalized counts table

# Output file
output_file <- file.path(working_dir, "5thx3th_DEGs_filtered_norm_counts.txt")  # Output file name
### End of Configuration -------------------------------------------

# Load required packages
if (!requireNamespace("tidyverse", quietly = TRUE)) {
  install.packages("tidyverse")
}
library(tidyverse)

# Display the file paths being used
cat("\nUsing file paths:\n")
cat("  Working directory: ", working_dir, "\n")
cat("  EdgeR results file: ", edger_results_file, "\n")
cat("  EdgeR norm counts file: ", norm_counts_file, "\n")
cat("  Output file: ", output_file, "\n\n")

# Check if files exist
if (!file.exists(edger_results_file)) {
  stop("Error: EdgeR results file not found: ", edger_results_file)
}
if (!file.exists(norm_counts_file)) {
  stop("Error: EdgeR normalized counts file not found: ", norm_counts_file)
}

# Read the EdgeR results table (assuming tab-delimited since it's a .txt file)
cat("Reading EdgeR results table...\n")
edger_results <- read.delim(edger_results_file, header = TRUE, stringsAsFactors = FALSE, sep = "\t")

# Print structure to check
cat("Structure of EdgeR results table:\n")
str(edger_results)
cat("\nFirst few rows of EdgeR results:\n")
print(head(edger_results))

# Extract IDs from the first column
id_col_name_results <- colnames(edger_results)[1]
sig_ids <- edger_results[[id_col_name_results]]
cat("Extracted", length(sig_ids), "IDs from EdgeR results table\n")
cat("First few IDs:", paste(head(sig_ids), collapse = ", "), "\n")

# Read the normalized counts table (assuming tab-delimited since it's a .txt file)
cat("Reading EdgeR normalized counts table...\n")
norm_counts <- read.delim(norm_counts_file, header = TRUE, stringsAsFactors = FALSE, sep = "\t")

# Check column names
cat("Column names in normalized counts table:\n")
print(colnames(norm_counts))

# Determine the ID column in normalized counts table
# Assuming it's the first column
id_col_name_counts <- colnames(norm_counts)[1]
cat("Using column '", id_col_name_counts, "' as ID column in normalized counts table\n", sep = "")

# Compare ID formats
cat("\nSample IDs from results table:", paste(head(sig_ids), collapse = ", "), "\n")
cat("Sample IDs from counts table:", paste(head(norm_counts[[id_col_name_counts]]), collapse = ", "), "\n")

# Check for any IDs in both tables
matching_ids_count <- sum(norm_counts[[id_col_name_counts]] %in% sig_ids)
cat("Number of matching IDs found:", matching_ids_count, "\n")

# Filter normalized counts table to keep only rows with IDs in the sig_ids list
filtered_counts <- norm_counts[norm_counts[[id_col_name_counts]] %in% sig_ids, ]
cat("Filtered normalized counts table: retained", nrow(filtered_counts), "out of", nrow(norm_counts), "rows\n")

# Check if any rows were retained
if (nrow(filtered_counts) == 0) {
  cat("\nWARNING: No matching IDs found between the two tables!\n")
  cat("Please check if the ID formats match between the two files.\n")
  
  # Save empty result but continue execution
  write.table(filtered_counts, file = output_file, sep = "\t", row.names = FALSE, quote = FALSE)
  cat("Empty filtered table saved to", output_file, "\n")
} else {
  # Save the filtered normalized counts table (tab-delimited to match input format)
  write.table(filtered_counts, file = output_file, sep = "\t", row.names = FALSE, quote = FALSE)
  cat("Filtered normalized counts table saved to", output_file, "\n")
  
  # Print a small preview of the filtered data
  cat("\nPreview of filtered normalized counts:\n")
  print(head(filtered_counts))
}

cat("\nDone!\n")