args <- commandArgs(trailingOnly = TRUE)
fileName <- args[1]
if (is.na(fileName)) {
  fileName <- "installed.packages.csv"
  cat("No file name supplied. Writing to", fileName, "\n")
}
# get installed packages and write to CSV file
p <- installed.packages()
df <- data.frame(p, stringsAsFactors = FALSE)
sub <- df[, c("Package", "Version")]
rownames(sub) <- NULL
# order the subset by Package and Version
sub <- sub[order(sub$Package, sub$Version), ]
write.csv(sub, file = fileName, row.names = FALSE)
