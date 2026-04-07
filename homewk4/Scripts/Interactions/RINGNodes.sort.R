# Load the node table
df <- read.table("P02753.cif_ringNodes", header = TRUE, sep = "\t", fill = TRUE)

# Residues of interest
res <- c(42, 54, 55, 63, 80, 107, 114, 115, 119, 134, 136, 138, 153)
ring_res <- res + 1

# Subset
df_sub <- df[df$Position %in% ring_res, c("Position", "Residue", "Degree")]

# Sort by Degree descending
df_sorted <- df_sub[order(-df_sub$Degree), ]

# Switch to original indexes
df_sorted$Position <- df_sorted$Position - 1

# Top 7
head(df_sorted, 7)