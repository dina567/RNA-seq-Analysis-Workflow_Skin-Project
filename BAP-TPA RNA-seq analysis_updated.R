#---------DESeq2 analysis pipeline-------------
# Author: Hsiao-Chen Kuo
# Email: dina820410@gmail.com

#-------- Install packages ---------
#BiocManager::install("BiocManager")
#BiocManager::install("DESeq2")
#BiocManager::install("airway")
#BiocManager::install("ggplot2")
#BiocManager::install("EnhancedVolcano")
#BiocManager::install("dplyr")
#BiocManager::install("AnnotationDbi")
#BiocManager::install("genefilter")
#BiocManager::install("apeglm")
#BiocManager::install("ashr")
#BiocManager::install("EnhancedVolcano")
#install.packages("pheatmap")
#install.packages("PoiClaClu")

library(DESeq2)
library(RColorBrewer)
library(pheatmap)
library(PoiClaClu)
library(ggplot2)
library(genefilter)
library(EnhancedVolcano)
library(dplyr)
library(AnnotationDbi)
library(apeglm)
library(ashr)

## More info https://www.bioconductor.org/packages/devel/workflows/vignettes/rnaseqGene/inst/doc/rnaseqGene.html


# -----------Prepare feature counts matrix --------
# Load data from a csv file ----------
setwd("C:/Rutgers/Github/BAP-TPA_UA_skin-in vivo")
data <- read.csv("featurecounts.results_20200508-150414_transformed.csv", sep = ",", header = TRUE, row.names=1)
str(data)
head(data)

# only keep the columns with feature counts of each sample
colnames(data)
data <- data[,c(6:35)] 
head(data)

# Match column names from count table with the row names from design table
colnames(data) <- c(1:30)
colnames(data)

# Transform data into a matrix
cts <-as.matrix(data)
head(cts)
str(cts)


# ------- Prepare design table ---------
# design table should include your treatment group, treatment duration, or sample replicates by which you want to compare
# design table can include more than one condition by which you want to compare

coldata <- read.csv("design table_RNA-seq-07-05-22.csv", sep = ",", header = TRUE, row.names = 1)
coldata
coldata <- coldata[,c("trt","wk")] # only keep the columns of conditions by which you want to compare
coldata$trt <- factor(coldata$trt)
coldata$wk <- factor(coldata$wk)
#data$repl <- factor(coldata$repl)

## double check if row names of the design matches the column names of the feature counts matrix ##
all(rownames(coldata) %in% colnames(cts))
all(rownames(coldata) == colnames(cts))

# if not, coerce the row names of the design to match the column names of the feature counts matrix
# cts <- cts[, rownames(coldata)]
# all(rownames(coldata) == colnames(cts))


# Transform data into a matrix
cts <-as.matrix(data)
head(cts)
str(cts)

#Prepare DESeq DataSet by DESeqDataSetFromMatrix ---------
# 1. pre-filterthe row, to keep only rows that: 
# (1) do not have 0 
# (2) row sum has at least 50 reads in total 

dds <- DESeqDataSetFromMatrix(countData = cts,
                              colData = coldata,
                              design = ~ wk + trt)
#(1)
dds <- dds[apply(counts(dds), 1, function(row) all(row !=0)),]
#(2)
dds <- dds[rowSums(counts(dds)) >= 50,]

dds2 <- dds # copy dds to dds2 to set the ref to BAP+TPA

# 2a. explicitly set the factors level and specify the reference level to Control
dds$trt <- factor(dds$trt, levels = c("Control", "BAP+TPA", "BAP+TPA+UA"))
dds$trt <- relevel(dds$trt, ref = "Control")

# 2b. explicitly set the factors level and specify the reference level to BAP+TPA

dds2$trt <- factor(dds2$trt, levels = c("Control", "BAP+TPA", "BAP+TPA+UA"))
dds2$trt <- relevel(dds2$trt, ref = "BAP+TPA")


## -------- Plot the heatmap of Poisson distances between samples -------- 

# *Background info:
# Poisson distance is used to examine overall similarity between samples
# Poisson distance consider variation between sample counts when calculating distances
# Euclidian distance do NOT consider variation between sample counts when calculating distances
# use Poisson distance for raw (not normalized) count matrix
# use Euclidean distance for data normalized by regularized-logarithm transformation (rlog) or variance stablization transfromation (vst)
# https://www.biostars.org/p/278391/

# 1. transpose the counts and transform the poisson distance into a matrix

poisd <- PoissonDistance(t(counts(dds)))
samplePoisDistMatrix <- as.matrix(poisd$dd)


# 2. set the row names and remove the column names
rownames(samplePoisDistMatrix) <- paste(dds$trt, dds$wk, c("wk"), sep = "." )
colnames(samplePoisDistMatrix) <- NULL

colors = colorRampPalette(rev(brewer.pal(9, "YlGnBu")))(255)


# 3a. Plot without Clustering

pheatmap(samplePoisDistMatrix,
         clustering_distance_rows = poisd$dd,
         clustering_distance_cols = poisd$dd,
         cluster_rows=F, 
         cluster_cols=F,
         col = colors)


# 3b. Plot with Clustering

pheatmap(samplePoisDistMatrix,
         clustering_distance_rows = poisd$dd,
         clustering_distance_cols = poisd$dd,
         cluster_cols=F,
         col = colors)


#----------- Perform DESeq data analysis -----------
dds <- DESeq(dds) # reference is control
dds2 <- DESeq(dds2) # ref is BAP+TPA

res <- results(dds, alpha = 0.05)
summary(res)

res_TPA.vs.C <- results(dds, contrast=c("trt", "BAP+TPA", "Control"), alpha = 0.05)
summary(res_TPA.vs.C)
mcols(res_TPA.vs.C, use.names=TRUE)


res_UA.vs.TPA <- results(dds, contrast=c("trt", "BAP+TPA+UA", "BAP+TPA"), alpha = 0.05)
summary(res_UA.vs.TPA)

# 5 wks
res_TPA.vs.C_5wk <- results(dds[dds$wk == 5], contrast=c("trt", "BAP+TPA", "Control"), alpha = 0.05)
summary(res_TPA.vs.C_5wk)
mcols(res_TPA.vs.C_5wk, use.names=TRUE)

res_UA.vs.TPA_5wk <- results(dds[dds$wk == 5], contrast=c("trt", "BAP+TPA+UA", "BAP+TPA"), alpha = 0.05)
summary(res_UA.vs.TPA_5wk)

# 20 wks
res_TPA.vs.C_20wk <- results(dds[dds$wk == 20], contrast=c("trt", "BAP+TPA", "Control"), alpha = 0.05)
summary(res_TPA.vs.C_5wk)
mcols(res_TPA.vs.C_5wk, use.names=TRUE)

res_UA.vs.TPA_20wk <- results(dds[dds$wk == 20], contrast=c("trt", "BAP+TPA+UA", "BAP+TPA"), alpha = 0.05)
summary(res_UA.vs.TPA_5wk)

write.csv(res_TPA.vs.C, file = "deseq2_results_TPAvsC.csv")
write.csv(res_UA.vs.TPA, file = "deseq2_results_UAvsTPA.csv")




#-------- MA plot -------- 
# *Background info:
# M stands for magnitude and A stands for average
# MA plot visualizes the log2 fold change vs. average of normalized count  
# MA plot points are colored blue if Padj < 0.1 (default) -> can change to 0.05 by alpha = 0.05
# the triangle symbols are the points that outside of the y limit

# 1. MA plot of BAP+TPA vs. Control
plotMA(res_TPA.vs.C, ylim = c(-6, 6), alpha = 0.05, font.lab=2,
       main = "BAP+TPA vs. Control",
       xlab = "Mean of Normalized Counts", ylab = "Log Fold Change")

#5wk#
plotMA(res_TPA.vs.C_5wk, ylim = c(-6, 6), alpha = 0.05, font.lab=2,
       main = "BAP+TPA vs. Control",
       xlab = "Mean of Normalized Counts", ylab = "Log Fold Change")
#20wk#
plotMA(res_TPA.vs.C_20wk, ylim = c(-6, 6), alpha = 0.05, font.lab=2,
       main = "BAP+TPA vs. Control",
       xlab = "Mean of Normalized Counts", ylab = "Log Fold Change")

# 2. MA plot of BAP+TPA+UA vs. BAP+TPA
plotMA(res_UA.vs.TPA, ylim = c(-4, 4), alpha = 0.05, font.lab=2,
       main = "BAP+TPA+UA vs. BAP+TPA",
       xlab = "Mean of Normalized Counts", ylab = "Log Fold Change")
#5wk#
plotMA(res_UA.vs.TPA_5wk, ylim = c(-4, 4), alpha = 0.05, font.lab=2,
       main = "BAP+TPA+UA vs. BAP+TPA",
       xlab = "Mean of Normalized Counts", ylab = "Log Fold Change")
#20wk#
plotMA(res_UA.vs.TPA_20wk, ylim = c(-4, 4), alpha = 0.05, font.lab=2,
       main = "BAP+TPA+UA vs. BAP+TPA",
       xlab = "Mean of Normalized Counts", ylab = "Log Fold Change")

# 3. Log fold change/effect size shrinkage (for visualization and ranking)

# The shrunken log fold changes are useful for ranking and visualization, without the need for arbitrary filters on low count genes.
# The normal prior can sometimes produce too strong of shrinkage for certain datasets. 
# In DESeq2 (ver1.18): two additional adaptive shrinkage estimators, apeglm and ashr (available via the type argument of lfcShrink). 

# (1) apeglm shrinkage


# BAP+TPA vs Control
resultsNames(dds)
colnames(dds)
resLFC_TPA.vs.C_ape <- lfcShrink(dds, coef="trt_BAP.TPA_vs_Control", type="apeglm")
plotMA(resLFC_TPA.vs.C_ape, ylim = c(-6, 6), alpha = 0.05, font.lab=2,
       main = "BAP+TPA vs. Control",
       xlab = "Mean of Normalized Counts", ylab = "Log Fold Change")

#5wk#
resLFC_TPA.vs.C_ape_5wk <- lfcShrink(dds[dds$wk == 5], coef="trt_BAP.TPA_vs_Control", type="apeglm")
plotMA(resLFC_TPA.vs.C_ape_5wk, ylim = c(-6, 6), alpha = 0.05, font.lab=2,
       main = "BAP+TPA vs. Control",
       xlab = "Mean of Normalized Counts", ylab = "Log Fold Change")

#20wk#
resLFC_TPA.vs.C_ape_20wk <- lfcShrink(dds[dds$wk == 20], coef="trt_BAP.TPA_vs_Control", type="apeglm")
plotMA(resLFC_TPA.vs.C_ape_20wk, ylim = c(-6, 6), alpha = 0.05, font.lab=2,
       main = "BAP+TPA vs. Control",
       xlab = "Mean of Normalized Counts", ylab = "Log Fold Change")

# BAP+TPA+UA vs BAP+TPA
resultsNames(dds2)
resLFC_UA.vs.TPA_ape <- lfcShrink(dds2, coef="trt_BAP.TPA.UA_vs_BAP.TPA", type="apeglm")
plotMA(resLFC_UA.vs.TPA_ape, ylim = c(-4, 4), alpha = 0.05, font.lab=2,
       main = "BAP+TPA+UA vs. BAP+TPA",
       xlab = "Mean of Normalized Counts", ylab = "Log Fold Change")

#5wk#
resLFC_UA.vs.TPA_ape_5wk <- lfcShrink(dds2[dds2$wk == 5], coef="trt_BAP.TPA.UA_vs_BAP.TPA", type="apeglm")
plotMA(resLFC_UA.vs.TPA_ape_5wk, ylim = c(-4, 4), alpha = 0.05, font.lab=2,
       main = "BAP+TPA+UA vs. BAP+TPA",
       xlab = "Mean of Normalized Counts", ylab = "Log Fold Change")

#20wk#
resLFC_UA.vs.TPA_ape_20wk <- lfcShrink(dds2[dds2$wk == 20], coef="trt_BAP.TPA.UA_vs_BAP.TPA", type="apeglm")
plotMA(resLFC_UA.vs.TPA_ape_20wk, ylim = c(-4, 4), alpha = 0.05, font.lab=2,
       main = "BAP+TPA+UA vs. BAP+TPA",
       xlab = "Mean of Normalized Counts", ylab = "Log Fold Change")

# (2) ashr shrinkage

# BAP+TPA vs Control
resultsNames(dds)
resLFC_TPA.vs.C_ash <- lfcShrink(dds, coef="trt_BAP.TPA_vs_Control", type="ashr")
plotMA(resLFC_TPA.vs.C_ash, ylim = c(-6, 6), alpha = 0.05, font.lab=2,
       main = "BAP+TPA vs. Control",
       xlab = "Mean of Normalized Counts", ylab = "Log Fold Change")

# using contrast gives the same results as above
# resultsNames(dds)
# resLFC_TPA.vs.C_ash2 <- lfcShrink(dds, contrast = c("trt", "BAP+TPA", "Control"), type="ashr")
# plotMA(resLFC_TPA.vs.C_ash2, ylim = c(-4, 4), alpha = 0.05)

# BAP+TPA+UA vs BAP+TPA
resultsNames(dds)

resLFC_UA.vs.TPA_ash <- lfcShrink(dds2, coef="trt_BAP.TPA.UA_vs_BAP.TPA", type="ashr")
plotMA(resLFC_UA.vs.TPA_ash, ylim = c(-4, 4), alpha = 0.05, font.lab=2,
       main = "BAP+TPA vs. Control",
       xlab = "Mean of Normalized Counts", ylab = "Log Fold Change")
# this gives the same MA plot
resLFC_UA.vs.TPA_ash2 <- lfcShrink(dds, contrast = c("trt", "BAP+TPA+UA", "BAP+TPA"), type="ashr")
plotMA(resLFC_UA.vs.TPA_ash2, ylim = c(-4, 4), alpha = 0.05, font.lab=2,
       main = "BAP+TPA vs. Control",
       xlab = "Mean of Normalized Counts", ylab = "Log Fold Change")
resultsNames(dds2)


#------ subset genes to find DEGs------

# 1. filter by adjust p value of 0.05 and order by log2 fold change

# (1) sort it by the log2 fold change estimate in "ascending" order
# the significant genes with the strongest down-regulation:

# TPA vs. Control
resSig <- subset(resLFC_TPA.vs.C_ape, padj < 0.05)
head(resSig[ order( resSig$log2FoldChange ), ])

# resSig <- subset(res_TPA.vs.C, padj < 0.05)
# head(resSig[ order( resSig$log2FoldChange ), ])
# 
# resSig <- subset(resLFC_TPA.vs.C_ash, padj < 0.05)
# head(resSig[ order( resSig$log2FoldChange ), ])

# UA vs. TPA
resSig <- subset(resLFC_UA.vs.TPA_ape, padj < 0.05)
head(resSig[ order( resSig$log2FoldChange ), ])

# resSig <- subset(res_UA.vs.TPA, padj < 0.05)
# head(resSig[ order( resSig$log2FoldChange ), ])
# 
# resSig <- subset(resLFC_UA.vs.TPA_ash, padj < 0.05)
# head(resSig[ order( resSig$log2FoldChange ), ])


# (2) sort it by the log2 fold change estimate in "descending" order
# the significant genes with the strongest up-regulation:
# TPA vs. Control
resSig <- subset(resLFC_TPA.vs.C_ape, padj < 0.05)
head(resSig[ order( -resSig$log2FoldChange ), ])

# resSig <- subset(res_TPA.vs.C, padj < 0.05)
# head(resSig[ order( -resSig$log2FoldChange ), ])
# 
# resSig <- subset(resLFC_TPA.vs.C_ash, padj < 0.05)
# head(resSig[ order( -resSig$log2FoldChange ), ])
# UA vs. TPA

resSig <- subset(resLFC_UA.vs.TPA_ape, padj < 0.05)
head(resSig[ order( -resSig$log2FoldChange ), ])

# resSig <- subset(res_UA.vs.TPA, padj < 0.05)
# head(resSig[ order( -resSig$log2FoldChange ), ])
# 
# resSig <- subset(resLFC_UA.vs.TPA_ash, padj < 0.05)
# head(resSig[ order( -resSig$log2FoldChange ), ])



# 2. filter by adjust p value of 0.05, log2 fold change of 1, baseMean >= 20
resultsSig <- res[which(res$padj < 0.05 & abs(res$log2FoldChange) >= 1 & res$baseMean >= 20), ]
resultsSig <- na.omit(resultsSig)


resultsSig <- resLFC_TPA.vs.C_ash[which(resLFC_TPA.vs.C_ash$padj < 0.05 & abs(resLFC_TPA.vs.C_ash$log2FoldChange) >= 1 & resLFC_TPA.vs.C_ash$baseMean >= 20), ]
resultsSig <- na.omit(resultsSig)
resultsSig


resultsSig <- resLFC_UA.vs.TPA_ash[which(resLFC_UA.vs.TPA_ash$padj < 0.05 & abs(resLFC_UA.vs.TPA_ash$log2FoldChange) >= 1 & resLFC_UA.vs.TPA_ash$baseMean >= 20), ]
resultsSig <- na.omit(resultsSig)
resultsSig


# -----------volcano plot ----------------
# x axis is the how much the genes differ from the control
# y axis means how statistically significant the change as compared to control


library(EnhancedVolcano)

# Default thresholds are log2FC > |2| and adjusted P-value < 0.05
# TPA+BAP vs. Control
summary(resLFC_TPA.vs.C_ape)

EnhancedVolcano(resLFC_TPA.vs.C_ape, lab = rownames(resLFC_TPA.vs.C_ape), 
                x = "log2FoldChange", y="padj",
                pCutoff = 0.05, FCcutoff = 2,
                xlim = c(-8, 8),
                border = "full", borderWidth = 1.5, borderColour = "black", 
                gridlines.major = FALSE, gridlines.minor = FALSE, 
                title = "BAP+TPA versus Control", subtitle = "Volcano Plot",
                drawConnectors = TRUE, widthConnectors = 0.75,
                legendPosition = 'bottom', 
                shape = 19)

EnhancedVolcano(resLFC_TPA.vs.C_ape_5wk, lab = rownames(resLFC_TPA.vs.C_ape_5wk), 
                x = "log2FoldChange", y="padj",
                pCutoff = 0.05, FCcutoff = 2,
                xlim = c(-8, 8),
                border = "full", borderWidth = 1.5, borderColour = "black", 
                gridlines.major = FALSE, gridlines.minor = FALSE, 
                title = "BAP+TPA versus Control", subtitle = "Volcano Plot",
                drawConnectors = TRUE, widthConnectors = 0.75,
                legendPosition = 'bottom', 
                shape = 19)
EnhancedVolcano(resLFC_TPA.vs.C_ape_20wk, lab = rownames(resLFC_TPA.vs.C_ape_20wk), 
                x = "log2FoldChange", y="padj",
                pCutoff = 0.05, FCcutoff = 2,
                xlim = c(-8, 8),
                border = "full", borderWidth = 1.5, borderColour = "black", 
                gridlines.major = FALSE, gridlines.minor = FALSE, 
                title = "BAP+TPA versus Control", subtitle = "Volcano Plot",
                drawConnectors = TRUE, widthConnectors = 0.75,
                legendPosition = 'bottom', 
                shape = 19)
# UA vs. TPA+BAP
EnhancedVolcano(resLFC_UA.vs.TPA_ape, lab = rownames(resLFC_TPA.vs.C_ape), 
                x = "log2FoldChange", y="padj",
                pCutoff = 0.05, FCcutoff = 2,
                xlim = c(-2, 2),
                border = "full", borderWidth = 1.5, borderColour = "black", 
                gridlines.major = FALSE, gridlines.minor = FALSE, 
                title = "BAP+TPA+UA versus BAP+TPA", subtitle = "Volcano Plot",
                drawConnectors = TRUE, widthConnectors = 0.75,
                legendPosition = 'bottom', 
                shape = 19)
#5wk#
EnhancedVolcano(resLFC_UA.vs.TPA_ape_5wk, lab = rownames(resLFC_UA.vs.TPA_ape_5wk), 
                x = "log2FoldChange", y="padj",
                pCutoff = 0.05, FCcutoff = 2,
                xlim = c(-2, 2),
                border = "full", borderWidth = 1.5, borderColour = "black", 
                gridlines.major = FALSE, gridlines.minor = FALSE, 
                title = "BAP+TPA+UA versus BAP+TPA", subtitle = "Volcano Plot",
                drawConnectors = TRUE, widthConnectors = 0.75,
                legendPosition = 'bottom', 
                shape = 19)
#20wk#
EnhancedVolcano(resLFC_UA.vs.TPA_ape_20wk, lab = rownames(resLFC_UA.vs.TPA_ape_20wk), 
                x = "log2FoldChange", y="padj",
                pCutoff = 0.05, FCcutoff = 2,
                xlim = c(-2, 2),
                border = "full", borderWidth = 1.5, borderColour = "black", 
                gridlines.major = FALSE, gridlines.minor = FALSE, 
                title = "BAP+TPA+UA versus BAP+TPA", subtitle = "Volcano Plot",
                drawConnectors = TRUE, widthConnectors = 0.75,
                legendPosition = 'bottom', 
                shape = 19)

EnhancedVolcano(res_TPA.vs.C, lab = rownames(res_TPA.vs.C), x = "log2FoldChange", y="padj")

#Add custom log2FC and adjusted P-value cutoffs and size of points and labels
EnhancedVolcano(res_TPA.vs.C, lab = rownames(res_TPA.vs.C), x = "log2FoldChange", y="padj", pCutoff = 10e-5, FCcutoff = 2, pointSize = 1.5, labSize = 3.0, title = "Untreated versus treated")

#Adjust axis limits
EnhancedVolcano(res, lab = rownames(res_TPA.vs.C), x = "log2FoldChange", y="padj", xlim = c(-5, 5), ylim = c(0, -log10(10e-10)), title = "Untreated versus treated")

#Modify border and remove gridlines
EnhancedVolcano(resLFC_TPA.vs.C_ape, lab = rownames(res_TPA.vs.C), x = "log2FoldChange", y="padj", xlim = c(-10, 10), 
                border = "full", borderWidth = 1.5, borderColour = "black", 
                gridlines.major = FALSE, gridlines.minor = FALSE, title = "Untreated versus treated",
                selectLab = c('Nfe2l2','Nqo1','Hmox1','Tnfrsf1b'),
                drawConnectors = TRUE,
                widthConnectors = 0.75)

EnhancedVolcano(resLFC_TPA.vs.C_ape, lab = rownames(resLFC_TPA.vs.C_ape), x = "log2FoldChange", y="padj", xlim = c(-10, 10), 
                pCutoff = 0.05, FCcutoff = 4, 
                border = "full", borderWidth = 1.5, borderColour = "black", 
                gridlines.major = FALSE, gridlines.minor = FALSE, title = "Untreated versus treated",
                drawConnectors = TRUE,
                widthConnectors = 0.75)


# gene of interest: genes whcih shows high log2 fold change or low p value
# the upregulation and downregulation really depends on the threshold you set
##

# --------rlog or vst transformation--------

# sample >30 use vst (variance stabilizing transformation) transformation
# vsdata <- vst(dds, blind = FALSE)
# smaller samples use rlog transformation

# vst takes two things into account while normalization, one is size factor(depth normalization) and another is mean dispersion across the sample. 
# while rld only accounts for size factor.

# perform regularized-logarithm transformation (rlog)-----
rld <- rlog(dds)
colnames(dds)
rld_TPA.vs.C <- rlog(dds[,1:18])
rld_UA.vs.TPA <- rlog(dds[,7:30])
rld_w5 <- rlog(dds[,dds$wk == 5])
rld_w15 <- rlog(dds[,dds$wk == 15])
rld_w20 <- rlog(dds[,dds$wk == 20])
rld_w26 <- rlog(dds[,dds$wk == 26])


#------Plot Principal Component Analysis based on rlog-transformed results-------
# project variation in the data into 2D format
# it explain the variation of data by components

plotPCA(rld_TPA.vs.C, intgroup = c("trt"))
plotPCA(rld_UA.vs.TPA, intgroup = c("trt"))
plotPCA(rld_w5, intgroup = c("trt"))
plotPCA(rld_w15, intgroup = c("trt"))
plotPCA(rld_w20, intgroup = c("trt"))
plotPCA(rld_w26, intgroup = c("trt"))

plotPCA(rld, intgroup = c("trt"))
plotPCA(rld, intgroup = c("wk"))
plotPCA(rld, intgroup = c("repl"))

plotPCA(rld, intgroup = c("trt","repl"))
plotPCA(rld, intgroup = c("trt","wk"))


# visualization using ggplot-------
pcaData <- plotPCA(rld, intgroup=c("trt", "wk"), returnData=TRUE)
percentVar <- round(100 * attr(pcaData, "percentVar"))
pcaData$trt <- factor(pcaData$trt, levels = c("Control","BAP+TPA", "BAP+TPA+UA"))

ggplot(pcaData, aes(PC1, PC2, color=trt, shape=wk)) +
  geom_point(size=3) +
  xlab(paste0("PC1: ",percentVar[1],"% variance")) +
  ylab(paste0("PC2: ",percentVar[2],"% variance")) + 
  coord_fixed()+
  theme(aspect.ratio=1,
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.background = element_blank(),
        panel.border = element_rect(colour = "black", fill=NA, size =1.5),
        axis.title = element_text(size = 12, face = "bold"),
        axis.text = element_text(size =10, face = "bold")) +
  scale_shape_manual(values = c(16, 17, 15, 10)) +
  stat_ellipse(aes(PC1, PC2, group = trt),type = "norm")



#-------plot dispersion of dds: variability between replicates as function of normalized read count--------
# as read counts gets higher, there is less variation
# red line below 1 is preferred, and the lower the better

plotDispEsts(dds)
plotDispEsts(dds[dds$wk == 5])
plotDispEsts(dds[dds$wk == 20])


#-------subset genes by filters ------
# padjust less than 0.05 and log2FC of 1 and base mean count of a least 20

resultsSig <- res[which(res$padj < 0.05 & abs(res$log2FoldChange) >= 2 & res$baseMean >= 20), ]
resultsSig <- na.omit(resultsSig)

# print DE genes with strongest downregulation (head) and upregulation (tail)
# cannot tell the reference group from here
head(resultsSig[order(resultsSig$log2FoldChange ), ] ) # downregulated compared to reference group
tail(resultsSig[order(resultsSig$log2FoldChange ), ] ) # upregulated compared to reference group

#--------plot expression of a top gene or gene of interest------------

# gene with largest positive log2 Fold Change 
plotCounts(dds, gene=which.max(res$log2FoldChange), intgroup="trt", normalized = TRUE)
plotCounts(dds, gene=which.max(res$log2FoldChange), intgroup="wk")

# specific gene of interest: Nrf2
plotCounts(dds, gene="Nfe2l2", intgroup="trt")

# (1) extract gene counts

geneCounts <- plotCounts(dds, gene = "Nfe2l2", intgroup = c("trt","wk"), returnData = TRUE)
geneCounts
text <- element_text(size = 14)

# (2-1) visualization by scatterplot
ggplot(geneCounts, aes(x = trt, y = count, color = wk, group = wk)) + 
  geom_point(size = 4) + 
  theme_classic() +
  scale_color_manual(name = "Treatment Weeks", values=c("orangered", "limegreen", "deepskyblue", "deeppink")) + 
  theme(axis.title = text) + 
  theme(axis.text.x = element_text(color="black", size = 12), axis.text.y = element_text(color="black", size = 12)) + 
  scale_x_discrete(name="Treatment", limits=c("Control", "BAP+TPA", "BAP+TPA+UA"), labels=c("Control", "BAP+TPA", "BAP+TPA+UA")) + 
  scale_y_log10(name="Normalized Count") + 
  ggtitle("Nrf2") + 
  facet_wrap(vars(wk))


ggsave(file="paired_dots.png", height=5, width=5)
dev.off()

# (2-2) visualization by boxplot

geneCounts
geneCounts %>% 
  ggplot(mapping = aes(x = trt, y = count, group = trt, fill = trt)) +
  geom_boxplot() +
  geom_jitter(position=position_jitterdodge(), color = "black", size = 4, alpha = 0.5) +
  xlab("Treatment") +
  ylab("Normalized count") +
  labs(title = "Nrf2")+
  scale_x_discrete(name="Treatment", limits=c("Control", "BAP+TPA", "BAP+TPA+UA"), labels=c("Control", "BAP+TPA", "BAP+TPA+UA")) + 
  scale_y_continuous(trans = "log10")+
  theme(text = element_text(size=15),
        axis.text.x = element_text(size = 13, color = "black"),
        axis.text.y = element_text(size = 13, color = "black"),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.background = element_rect(fill = "white")) +
  theme_classic() + 
  facet_wrap(vars(wk))

#-------plot heatmap of all DE genes-------

# (1) DE genes data preparation 
mat <- assay(rld)
mat_w5 <- assay(rld_w5)

head(mat)
colnames(resSig)
rownames(resSig)
DEgenes <- mat[rownames(resSig),]

colData(rld)
annotation <- as.data.frame(colData(rld)[, c("trt","wk")])
annotation

DEgenes_w5 <- mat_w5[rownames(resultsSig), ]
annotation_w5 <- as.data.frame(colData(rld_w5)[, c("trt")])


# (2) scale by "row" to help visualize the relative difference between groups
# otherwise (if set scale to "none"), you will only see absolute individual gene expression levels 

pheatmap(DEgenes_w5, scale = "row", show_rownames = FALSE, clustering_distance_rows = "correlation", annotation_col = annotation_w5, main="Differentially Expressed genes")

pheatmap(DEgenes, scale = "row", show_rownames = FALSE, 
         clustering_distance_rows = "correlation", 
         annotation_col = annotation, 
         main="Differentially Expressed genes", 
         cluster_cols = F,
         show_colnames=F
)

#-------plot heatmap of DE genes with filters-----
# top 20 with smallest padj

orderedSig <- resSig[order(-resSig$padj), ]
orderedSig
head(orderedSig, n = 20)
id1 <- mat[rownames(orderedSig),]
topDE <- mat[id1,]

top20DE <- head(id1, n=20)

pheatmap(top20DE, scale = "row", clustering_distance_rows = "correlation", annotation_col = annotation, main="Top 20 Differentially Expressed genes")
pheatmap(top20DE, scale = "row", clustering_distance_rows = "correlation", annotation_col = annotation, main="Top 20 Differentially Expressed genes", cluster_cols = F)


# genes with padj less than 0.05 in TPA vs. C comparison

orderedSig <- res_TPA.vs.C[order(res_TPA.vs.C$padj),]

DGEgenes <- rownames(subset(orderedSig, padj <0.05))

rlog.dge <- rld[DGEgenes,] %>% assay

pheatmap(rlog.dge, scale = "row", annotation_col = annotation, show_rownames = F, show_colnames = F, cluster_cols = F, treeheight_row = 0)

# genes with padj less than 0.05 in UA vs. TPA comparison
orderedSig2 <- res_TPA.vs.C[order(res_UA.vs.TPA$padj),]

DGEgenes2 <- rownames(subset(orderedSig2, padj <0.05))

rlog.dge2 <- rld[DGEgenes2,] %>% assay

pheatmap(rlog.dge2, scale = "row", annotation_col = annotation, show_rownames = F, show_colnames = F, cluster_cols = F, treeheight_row = 0)
