# Optimized miRNA ID Replacement Script
# This script replaces chromosome IDs with their corresponding full miRNA names

library(dplyr)
library(readr) # For faster file reading
library(tictoc) # For timing performance

# ===== Configuration =====

# File paths configuration
working_dir <- "path/to/your/directory"
setwd(working_dir)

# Input files
input_files <- list(
  expression_table = file.path(working_dir, "All_samples_edgeR_normcounts.tabular"),
  renamed_mirnas = file.path(working_dir, "Renamed_miRNAs_final_fixed.txt")
)

# Output file
output_file <- file.path(working_dir, "All_samples_edgeR_normcounts.tabular_renamed_FINAL.txt")

# ===== Functions =====

#' Create a mapping dictionary from FASTA file
#' Maps chromosome IDs (e.g., Chr01_1161) to full miRNA names (e.g., novel204_Chr01_1161)
#' 
#' @param fasta_file Path to the FASTA file containing renamed miRNAs
#' @return A named vector mapping chromosome IDs to full miRNA names
create_mapping <- function(fasta_file) {
  # Check if file exists
  if (!file.exists(fasta_file)) {
    stop(paste("File not found:", fasta_file))
  }
  
  # Read the file
  message("Reading miRNA FASTA file...")
  lines <- readLines(fasta_file)
  
  message("Creating ID mapping...")
  
  # Get all header lines (starting with >)
  header_lines <- grep("^>", lines)
  
  # Extract chromosome IDs and full names
  chr_ids <- character()
  full_names <- character()
  
  for (i in header_lines) {
    # Get the full name without the '>' character
    full_name <- substring(lines[i], 2)
    
    # Extract the chromosome ID part (e.g., Chr01_1161)
    # In format like novel204_Chr01_1161, we extract Chr01_1161
    if (grepl("Chr\\d+_\\d+", full_name)) {
      chr_id <- sub(".*?(Chr\\d+_\\d+)$", "\\1", full_name)
      
      chr_ids <- c(chr_ids, chr_id)
      full_names <- c(full_names, full_name)
    }
  }
  
  # Create named vector for faster lookups
  mapping <- setNames(full_names, chr_ids)
  
  # Print some diagnostic information
  if (length(mapping) > 0) {
    message("Sample mappings (first 3):")
    for (i in 1:min(3, length(mapping))) {
      message(names(mapping)[i], " -> ", mapping[i])
    }
  }
  
  message(paste("Created mapping for", length(mapping), "miRNAs"))
  return(mapping)
}

#' Replace chromosome IDs in expression table with full miRNA names
#' 
#' @param expr_file Path to the expression table file
#' @param mapping Named vector mapping chromosome IDs to full miRNA names
#' @return Data frame with replaced IDs
replace_ids <- function(expr_file, mapping) {
  # Check if file exists
  if (!file.exists(expr_file)) {
    stop(paste("File not found:", expr_file))
  }
  
  # Read the expression table
  message("Reading expression table...")
  expr_data <- read_delim(expr_file, delim = "\t", show_col_types = FALSE)
  
  # Ensure GeneID column exists
  if (!"GeneID" %in% colnames(expr_data)) {
    stop("GeneID column not found in expression table")
  }
  
  # Print a sample of expression data IDs for debugging
  message("Sample IDs from expression table (first 5):")
  for (i in 1:min(5, nrow(expr_data))) {
    message(expr_data$GeneID[i])
  }
  
  message("Replacing IDs...")
  
  # Replace each chromosome ID with its full miRNA name if found in mapping
  new_ids <- expr_data$GeneID
  matched_indices <- match(new_ids, names(mapping))
  is_matched <- !is.na(matched_indices)
  
  if (sum(is_matched) > 0) {
    new_ids[is_matched] <- mapping[matched_indices[is_matched]]
    message(paste("Matched and replaced", sum(is_matched), "IDs"))
  } else {
    warning("No IDs matched for replacement! Check the format of your files.")
  }
  
  # Update the data frame with new IDs
  expr_data$GeneID <- new_ids
  
  return(expr_data)
}

#' Generate verification report
#' 
#' @param original_data Original expression data
#' @param new_data Updated expression data with new IDs
#' @param mapping The ID mapping used
#' @return Invisibly returns a list with verification statistics
verification_report <- function(original_data, new_data, mapping) {
  original_ids <- original_data$GeneID
  new_ids <- new_data$GeneID
  
  changed <- sum(new_ids != original_ids)
  total <- length(original_ids)
  
  cat("\n=== VERIFICATION REPORT ===\n")
  cat(paste("Total miRNAs in table:", total, "\n"))
  cat(paste("IDs successfully changed:", changed, "\n"))
  cat(paste("IDs unchanged:", total - changed, "\n"))
  
  if (changed < total && changed > 0) {
    cat("\nSample of changed IDs (max 5):\n")
    changed_indices <- which(new_ids != original_ids)
    for (i in head(changed_indices, 5)) {
      cat(paste(" -", original_ids[i], "->", new_ids[i], "\n"))
    }
  }
  
  if (changed < total) {
    unchanged <- setdiff(original_ids, names(mapping))
    if (length(unchanged) > 0) {
      cat("\nSample of unchanged IDs (max 10):\n")
      print(head(unchanged, 10))
    }
  }
  
  # Return verification stats invisibly
  invisible(list(
    total = total,
    changed = changed,
    unchanged = total - changed,
    unchanged_ids = if (changed < total) setdiff(original_ids, names(mapping)) else character(0)
  ))
}

# ===== Main Execution =====

main <- function() {
  # Start timing
  tic("Total execution time")
  
  # Create the mapping dictionary from FASTA file
  tic("Creating mapping")
  mirna_mapping <- create_mapping(input_files$renamed_mirnas)
  toc()
  
  # Read original data for verification
  original_data <- read_delim(input_files$expression_table, delim = "\t", show_col_types = FALSE)
  
  # Process the expression table
  tic("Replacing IDs")
  result <- replace_ids(input_files$expression_table, mirna_mapping)
  toc()
  
  # Save the results
  tic("Writing output")
  write_delim(result, output_file, delim = "\t")
  toc()
  
  # Verification
  verification_report(original_data, result, mirna_mapping)
  
  cat(paste("\nOutput saved to:", output_file, "\n"))
  
  # End timing
  toc()
}

# Run the main function with error handling
tryCatch({
  main()
}, error = function(e) {
  cat(paste("\nERROR:", e$message, "\n"))
}, warning = function(w) {
  cat(paste("\nWARNING:", w$message, "\n"))
}, finally = {
  cat("\nScript execution completed.\n")
})
