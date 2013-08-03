nba <- read.csv("RESULTS",sep=",")
row.names(nba) <- nba$Site
nba_matrix <- data.matrix(nba)
nba_heatmap <- heatmap(nba_matrix, Rowv=NA, Colv=NA, col=cm.colors(256), scale="column", margins=c(5,10))
