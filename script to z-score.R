# Load required libraries
library(tidyverse)
library(ComplexHeatmap)

### 1. File Reading & Data Preparation -----------------------------------------
input_file <- "/path/to/your/directory/file"  # Replace with your actual file path
output_dir <- "/path/to/your/directory/"

# Read data with proper formatting
counts_data <- read.delim(
  file = input_file,
  header = TRUE,
  row.names = "GeneID",
  check.names = FALSE  # Preserve column names with spaces
)

# Convert to matrix
counts_matrix <- as.matrix(counts_data)

### 2. Z-Score Calculation ----------------------------------------------------
z_scores <- t(scale(t(counts_matrix)))

# Clean NaN rows and convert to tidy format
z_scores_clean <- as.data.frame(z_scores) %>% 
  rownames_to_column("GeneID") %>% 
  filter(if_any(-GeneID, ~ !is.nan(.x)))

### 3. Save Z-Score Results ---------------------------------------------------
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

write.table(
  z_scores_clean,
  file = file.path(output_dir, "z_scores_results.txt"),
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

### 4. Heatmap Generation -----------------------------------------------------
# Prepare matrix
z_matrix <- as.matrix(z_scores_clean[, -1])
rownames(z_matrix) <- z_scores_clean$GeneID

# Annotation setup
annotation_df <- data.frame(
  Group = rep(c("Fifth", "Thirdth"), each = 3),
  row.names = colnames(z_matrix)
)

# Create optimized heatmap
ht <- Heatmap(
  z_matrix,
  name = "Z-Score",
  col = circlize::colorRamp2(c(-2, 0, 2), c("blue", "white", "red")),
  
  # Clustering
  row_km = 3,
  column_km = 2,
  
  # Appearance
  show_row_names = TRUE,
  show_column_names = FALSE,
  row_names_gp = gpar(fontsize = 6),
  column_title = "DEMs: Fifth vs. Thirdth Internodes",
  column_title_gp = gpar(fontsize = 12, fontface = "bold"),
  
  # Cell dimensions
  width = ncol(z_matrix) * unit(20, "mm"),
  height = nrow(z_matrix) * unit(3, "mm"),
  
  # Annotations
  top_annotation = HeatmapAnnotation(
    Group = annotation_df$Group,
    col = list(Group = c(Fifth = "darkgreen", Thirdth = "orange")),
    annotation_legend_param = list(
      Group = list(title = "Sample group", title_gp = gpar(fontsize = 8))
    )
  )
)

### 5. Save Heatmaps ----------------------------------------------------------
# PDF version
pdf(
  file.path(output_dir, "Setaria_miRNAs_heatmap_5thx3th_DEGs_renamed.pdf"),
  width = max(10, ncol(z_matrix) * 0.5),
  height = max(10, nrow(z_matrix) * 0.05)
)
draw(ht)
dev.off()

# High-res PNG
png(
  file.path(output_dir, "Setaria_miRNAs_heatmap_5thx3th_DEGs_renamed.png"),
  width = 5000, 
  height = 2300, 
  res = 600
)
draw(ht)
dev.off()
