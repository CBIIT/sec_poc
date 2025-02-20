p <- installed.packages()
df <- data.frame(p, stringsAsFactors = FALSE)
sub <- df[, c("Package", "Version")]
rownames(sub) <- NULL
sub <- sub[order(sub$Package), ]
write.csv(sub, file = "installed.packages.csv", row.names = FALSE)
