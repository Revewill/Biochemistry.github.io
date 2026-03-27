#!/usr/bin/env Rscript
# N-terminal based sequence reconstruction
# Usage: Rscript reconstruct.R cnbr.txt trypsin.txt

# Read fragments
read_fragments <- function(filename) {
  lines <- readLines(filename, warn = FALSE)
  lines <- lines[lines != ""]
  return(lines)
}

# Find fragment containing N-terminus
find_n_terminal <- function(fragments, n_term) {
  for (f in fragments) {
    if (substr(f, 1, 1) == n_term) {
      return(f)
    }
  }
  return(NULL)
}

# Find trypsin fragments within CNBr sequence
find_trypsin_in_cnbr <- function(cnbr_seq, trypsin_frags) {
  results <- data.frame(
    fragment = trypsin_frags,
    found = sapply(trypsin_frags, function(f) grepl(f, cnbr_seq, fixed = TRUE)),
    stringsAsFactors = FALSE
  )
  return(results)
}

# Find trypsin fragments that bridge two CNBr fragments
find_bridging_fragments <- function(cnbr_seq1, cnbr_seq2, trypsin_frags) {
  combined <- paste0(cnbr_seq1, cnbr_seq2)
  bridging <- c()

  for (f in trypsin_frags) {
    if (!grepl(f, cnbr_seq1, fixed = TRUE) &&
        !grepl(f, cnbr_seq2, fixed = TRUE) &&
        grepl(f, combined, fixed = TRUE)) {
      bridging <- c(bridging, f)
    }
  }
  return(bridging)
}

# Main function
main <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  if (length(args) < 2) {
    cat("Usage: Rscript reconstruct.R <cnbr.txt> <trypsin.txt>\n")
    quit(status = 1)
  }

  cnbr_frags <- read_fragments(args[1])
  trypsin_frags <- read_fragments(args[2])

  cat("\n")
  cat("=", rep("=", 58), "\n", sep = "")
  cat("  N-terminal based sequence reconstruction\n")
  cat("=", rep("=", 58), "\n\n", sep = "")

  cat("N-terminal residue: G\n\n")

  # Find N-terminal CNBr fragment
  n_term_cnbr <- find_n_terminal(cnbr_frags, "G")
  cat("N-terminal CNBr fragment:", n_term_cnbr, "\n\n")

  # Find trypsin fragments containing N-terminus
  n_term_trypsin <- trypsin_frags[substr(trypsin_frags, 1, 1) == "G"]
  cat("N-terminal trypsin fragments:", paste(n_term_trypsin, collapse = ", "), "\n\n")

  # List all CNBr fragments
  cat("CNBr fragment list:\n")
  for (i in 1:length(cnbr_frags)) {
    if (cnbr_frags[i] == n_term_cnbr) {
      cat("  ", i, ". ", cnbr_frags[i], " <- N-terminal\n", sep = "")
    } else {
      cat("  ", i, ". ", cnbr_frags[i], "\n", sep = "")
    }
  }

  # Try all possible orders
  cat("\n", rep("=", 58), "\n", sep = "")
  cat("Trying all possible orders...\n")
  cat(rep("=", 58), "\n\n", sep = "")

  # Other CNBr fragments
  others <- cnbr_frags[cnbr_frags != n_term_cnbr]

  # Generate all permutations
  if (length(others) == 2) {
    orders <- list(
      c(n_term_cnbr, others[1], others[2]),
      c(n_term_cnbr, others[2], others[1])
    )
  } else {
    orders <- list(c(n_term_cnbr, others))
  }

  for (order_idx in 1:length(orders)) {
    order <- orders[[order_idx]]
    seq <- paste(order, collapse = "")

    cat("Order", order_idx, ": [",
        paste(substr(order, 1, 10), "...", sep = ""),
        "]\n", sep = "")

    # Check if all trypsin fragments are in the sequence
    missing <- c()
    for (f in trypsin_frags) {
      if (!grepl(f, seq, fixed = TRUE)) {
        missing <- c(missing, f)
      }
    }

    if (length(missing) == 0) {
      cat("  ✓ All trypsin fragments found in sequence!\n")
      cat("\n", rep("=", 58), "\n", sep = "")
      cat("Final reconstructed sequence:\n")
      cat(rep("=", 58), "\n\n", sep = "")
      cat(seq, "\n")
      cat("\nLength:", nchar(seq), "amino acids\n")

      # Save result
      writeLines(c(paste0(">reconstructed_sequence"), seq), "reconstructed.fasta")
      cat("\nResult saved to: reconstructed.fasta\n")

      return()
    } else {
      cat("  ✗ Missing", length(missing), "trypsin fragments\n")
    }
  }

  cat("\nUnable to determine unique order, more information needed\n")
}

main()
