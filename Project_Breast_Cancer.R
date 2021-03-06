library(matrixStats)
library(tidyverse)
library(caret)
library(dslabs)
library(corrplot)
data(brca)

options(digits = 3)


dim(brca$x)
length(brca$y)

head(brca$x)
head(brca$y)

summary(brca$x)
summary(brca$y)

# proportion
prop.table(table(brca$y))


## we then show some correlation 
corr_mat <- cor(brca$x)
corrplot(corr_mat)


# scaling the matrix

x_centered <- sweep(brca$x,2,colMeans(brca$x))
x_scaled <- sweep(x_centered,2, colSds(brca$x),FUN="/")

# after scaling standar deviation is 1 for all columns
colSds(x_scaled)

summary(x_scaled)

# heatmap of the relationship between features using the scaled matrix
d_features <- dist(t(x_scaled))
heatmap(as.matrix(d_features),labRow=NA,labCol=NA)

# clustering
h <- hclust(d_features)
groups <- cutree(h,k=5)
split(names(groups),groups)

# PCA
pca <- prcomp(x_scaled)
summary(pca)

# Plotting PCs, we can see the benign tumors tend to have smaller values of PC1 and 
# higher values for malignant tumors
data.frame(pca$x[,1:2],type = brca$y) %>%
  ggplot(aes(PC1,PC2,color=type)) + 
  geom_point()


# Plotting PCs, boxplot.  We can see PC1 is significantly different from others
data.frame(type = brca$y ,pca$x[,1:10]) %>%
  gather(key = "PC",value="value", -type) %>%
  ggplot(aes(PC,value,fill = type)) +
  geom_boxplot()
  geom_point()
  
# Creating data partition
set.seed(1,sample.kind = "Rounding")
test_index <- createDataPartition(brca$y, time=1, p=0.2,list=FALSE)
test_x <- x_scaled[test_index,]
test_y <- brca$y[test_index]
train_x <- x_scaled[-test_index,]
train_y <- brca$y[-test_index]


# We can see train and test sets have similar proportions
# proportion test
prop.table(table(test_y))

# proportion train
prop.table(table(train_y))

# K-means Clustering
predict_kmeans <- function(x, k) {
  centers <- k$centers 
  distances <- sapply(1:nrow(x), function(i){
    apply(centers, 1, function(y) dist(rbind(x[i,], y)))
  })
  max.col(-t(distances)) 
}

set.seed(3,sample.kind = "Rounding")
k <- kmeans(train_x, centers = 2)
kmeans_preds <- ifelse(predict_kmeans(test_x, k) == 1, "B", "M")

# K-means overall accuracy
mean(kmeans_preds == test_y)

# Logistic Regression
train_glm <- train(train_x,train_y,method="glm")
glm_preds <- predict(train_glm,test_x)

# Logistic Regression overall accuracy
mean(glm_preds==test_y)


# LDA and QDA models
train_lda <- train(train_x,train_y,method="lda")
lda_preds <- predict(train_lda,test_x)
mean(lda_preds==test_y)

train_qda <- train(train_x,train_y,method="qda")
qda_preds <- predict(train_qda,test_x)
mean(qda_preds==test_y)


# Loess model
set.seed(5, sample.kind = "Rounding")
train_loess <- train(train_x,train_y,method="gamLoess")
 
loess_preds <- predict(train_loess,test_x)
mean(loess_preds==test_y)


# K-nearest neighbors
set.seed(7, sample.kind = "Rounding")
tuning <- data.frame(k=seq(3,21,2))
train_knn <- train(train_x,train_y,method="knn",tuneGrid = tuning)
train_knn$bestTune

knn_preds <- predict(train_knn,test_x)
mean(knn_preds == test_y)


# Random Forest Model
set.seed(9, sample.kind = "Rounding")
tuning <- data.frame(mtry=c(3,5,7,9))
train_rf <- train(train_x,train_y, method="rf",tuneGrid = tuning, importance = TRUE)
train_rf$bestTune

rf_preds <- predict(train_rf, test_x)
mean(rf_preds == test_y)

# Ensemble
ensemble <- cbind(glm=glm_preds=="B",lda=lda_preds=="B",qda=qda_preds=="B",loess=loess_preds=="B",
                  rf=rf_preds=="B",knn=knn_preds=="B",kmeans=kmeans_preds=="B")

ensemble_preds <- ifelse(rowMeans(ensemble) >0.5,"B","M")
mean(ensemble_preds==test_y)



models <- c("K means", "Logistic regression", "LDA", "QDA", "Loess", "K nearest neighbors", "Random fore
st", "Ensemble")
accuracy <- c(mean(kmeans_preds == test_y),
                mean(glm_preds == test_y),
                mean(lda_preds == test_y),
                mean(qda_preds == test_y),
                mean(loess_preds == test_y),
                mean(knn_preds == test_y),
                mean(rf_preds == test_y),
                mean(ensemble_preds == test_y))
data.frame(Model = models, Accuracy = accuracy)

