his <- read.csv("RESULTS",sep=",")
row.names(his) <- his$Site
his_matrix <- data.matrix(his)
his_heatmap <- heatmap(his_matrix, Rowv=NA, Colv=NA, col=cm.colors(256), scale="column", margins=c(5,10))
