lines <- readLines("alignment.fa")

# Extract sequences with gaps preserved
seq_apod_full <- ""
seq_c8g_full <- ""
seq_rbp4_full <- ""

current_seq <- NULL
for (line in lines) {
  if (grepl("apolipoprotein D", line, ignore.case = TRUE)) {
    current_seq <- "apod"
  } else if (grepl("2QOS", line, ignore.case = TRUE)) {
    current_seq <- "c8g"
  } else if (grepl("Retinol-binding protein 4", line, ignore.case = TRUE)) {
    current_seq <- "rbp4"
  } else if (!grepl("^>", line) && nchar(trimws(line)) > 0) {
    seq_line <- trimws(line)
    if (current_seq == "apod") {
      seq_apod_full <- paste0(seq_apod_full, seq_line)
    } else if (current_seq == "c8g") {
      seq_c8g_full <- paste0(seq_c8g_full, seq_line)
    } else if (current_seq == "rbp4") {
      seq_rbp4_full <- paste0(seq_rbp4_full, seq_line)
    }
  }
}

# Split into characters (including gaps)
apod_vec <- strsplit(seq_apod_full, "")[[1]]
c8g_vec <- strsplit(seq_c8g_full, "")[[1]]
rbp4_vec <- strsplit(seq_rbp4_full, "")[[1]]

# Get RBP4 sequence without gaps (for position reference)
rbp4_no_gap <- rbp4_vec[rbp4_vec != "-"]
rbp4_seq <- paste(rbp4_no_gap, collapse = "")

cat("\n=== RBP4 SEQUENCE (no gaps) ===\n")
cat(rbp4_seq, "\n")
cat(paste0("Length: ", nchar(rbp4_seq), "\n\n"))

# LigPlot+ interaction residues (mature numbering)
interaction_ligplot <- c(42, 54, 55, 63, 80, 107, 114, 115, 119, 134, 136, 138, 153)

# Convert to original sequence numbering (LigPlot+ + 1)
interaction_positions <- interaction_ligplot + 1

# Function to classify amino acid properties
get_property <- function(aa) {
  hydrophobic <- c("A", "V", "L", "I", "M", "F", "W", "Y", "P", "G")
  positive <- c("R", "K", "H")
  negative <- c("D", "E")
  polar <- c("S", "T", "N", "Q", "C")
  
  if (aa %in% hydrophobic) return("hydrophobic")
  else if (aa %in% positive) return("positive")
  else if (aa %in% negative) return("negative")
  else if (aa %in% polar) return("polar")
  else return("unknown")
}

# Find alignment positions for each interaction residue
results <- data.frame()

for (pos in interaction_positions) {
  # Get the actual amino acid at this position in RBP4 (no-gap sequence)
  if (pos > nchar(rbp4_seq)) {
    next
  }
  rbp4_aa <- substr(rbp4_seq, pos, pos)
  
  # Find where this position is in the alignment (accounting for gaps)
  non_gap_count <- 0
  align_idx <- NA
  for (i in 1:length(rbp4_vec)) {
    if (rbp4_vec[i] != "-") {
      non_gap_count <- non_gap_count + 1
      if (non_gap_count == pos) {
        align_idx <- i
        break
      }
    }
  }
  
  if (is.na(align_idx)) {
    next
  }
  
  apod_aa <- ifelse(apod_vec[align_idx] == "-", "gap", apod_vec[align_idx])
  c8g_aa <- ifelse(c8g_vec[align_idx] == "-", "gap", c8g_vec[align_idx])
  
  rbp4_prop <- get_property(rbp4_aa)
  apod_prop <- ifelse(apod_aa == "gap", "gap", get_property(apod_aa))
  c8g_prop <- ifelse(c8g_aa == "gap", "gap", get_property(c8g_aa))
  
  # Calculate uniqueness score
  score <- 0
  if (rbp4_aa != apod_aa) score <- score + 1
  if (rbp4_aa != c8g_aa) score <- score + 1
  if (rbp4_prop != apod_prop) score <- score + 1
  if (rbp4_prop != c8g_prop) score <- score + 1
  if (apod_prop == c8g_prop & rbp4_prop != apod_prop) score <- score + 1
  
  # Find original LigPlot+ number (pos - 1)
  ligplot_num <- pos - 1
  
  results <- rbind(results, data.frame(
    Num = ligplot_num,
    Original_Num = pos,
    RBP4 = rbp4_aa,
    RBP4_Prop = rbp4_prop,
    APOD = apod_aa,
    APOD_Prop = apod_prop,
    C8G = c8g_aa,
    C8G_Prop = c8g_prop,
    Score = score
  ))
}

# Sort by score descending
results <- results[order(-results$Score), ][1:5,]

cat("\n=== INTERACTION RESIDUES SORTED BY UNIQUENESS SCORE ===\n")
print(results)