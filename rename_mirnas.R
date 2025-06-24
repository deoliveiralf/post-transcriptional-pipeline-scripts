# miRNA Renaming Script - Fixed NA Issue
library(stringr)
library(dplyr)

### File Path Configuration -----------------------------------------
working_dir <- "/path/to/your/directory/"
setwd(working_dir)

input_file <- file.path(working_dir, "Entire_list_conserved and novel miRNAs.txt")
conserved_file <- file.path(working_dir, "Conserved_miRNAs.txt")
output_file <- file.path(working_dir, "Renamed_miRNAs_final_fixed.txt")

### Improved Functions ---------------------------------------------
load_conserved_mirnas <- function(conserved_file) {
  lines <- readLines(conserved_file)
  conserved <- data.frame(sequence = character(), name = character(), stringsAsFactors = FALSE)
  
  current_name <- NULL
  for (line in lines) {
    if (str_starts(line, ">")) {
      current_name <- str_sub(line, 2)
    } else if (!is.null(current_name) && line != "") {
      conserved <- rbind(conserved, data.frame(
        sequence = toupper(line),
        name = current_name,
        stringsAsFactors = FALSE
      ))
      current_name <- NULL
    }
  }
  return(conserved)
}

get_mirna_name <- function(conserved_name, original_id) {
  # Try to extract miRXXX pattern first
  mir_family <- str_extract(conserved_name, "miR[0-9a-zA-Z]+")
  
  if (!is.na(mir_family)) {
    return(paste0(mir_family, "_", original_id))
  } else {
    # If no miRXXX found, use everything before first hyphen
    base_name <- str_split(conserved_name, "-", simplify = TRUE)[1]
    return(paste0(base_name, "_", original_id))
  }
}

rename_mirnas_final_fixed <- function(input_file, conserved_file, output_file) {
  conserved <- load_conserved_mirnas(conserved_file)
  lines <- readLines(input_file)
  
  output <- character()
  novel_count <- 1
  current_id <- NULL
  current_seq <- NULL
  
  for (line in lines) {
    if (str_starts(line, ">")) {
      # Process previous entry
      if (!is.null(current_seq)) {
        match <- conserved %>% filter(sequence == toupper(current_seq))
        
        if (nrow(match) > 0) {
          new_name <- get_mirna_name(match$name[1], current_id)
        } else {
          new_name <- paste0("novel", novel_count, "_", current_id)
          novel_count <- novel_count + 1
        }
        
        output <- c(output, paste0(">", new_name), current_seq)
      }
      
      # Start new entry
      current_id <- str_sub(line, 2)
      current_seq <- NULL
    } else if (!is.null(current_id) && line != "") {
      current_seq <- line
    }
  }
  
  # Process last entry
  if (!is.null(current_seq)) {
    match <- conserved %>% filter(sequence == toupper(current_seq))
    
    if (nrow(match) > 0) {
      new_name <- get_mirna_name(match$name[1], current_id)
    } else {
      new_name <- paste0("novel", novel_count, "_", current_id)
    }
    
    output <- c(output, paste0(">", new_name), current_seq)
  }
  
  writeLines(output, output_file)
  message(paste("Final fixed renaming completed. Output saved to:", output_file))
  message(paste("Total miRNAs processed:", length(grep("^>", output))))
  message(paste("Conserved miRNAs:", sum(grepl("^>miR|^>[^-]+_", output))))
  message(paste("Novel miRNAs:", sum(grepl("^>novel", output))))
}

### Execute ---------------------------------------------------------
message("\nStarting final fixed miRNA renaming...")
rename_mirnas_final_fixed(input_file, conserved_file, output_file)
message("Done! Check the output file.")
