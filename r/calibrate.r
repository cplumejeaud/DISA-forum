######################################################################
## Christine PLUMEJEAUD, 25/07/2017, 7/09/2017, 13/11/2017, 22/11/2017
##
## Calibration des indicateurs C6, C7 et D9 sur la France entière
## 1. Ouverture des sources de données : lire la base de données
## 2. Transformation des quantitatives en facteur 
## 3. Sauvegarde dans la base de données
##
######################################################################

#####################################################
### 0. Installer et charger des bibliothèques
#####################################################

.libPaths()
 "C:/Users/cplume01/R/win-library/3.0" "C:/Program Files/R/R-3.0.0/library"

## Rajouter le chemin vers les librairies dans le path
.libPaths(c( .libPaths(), "C:/Tools/R") )

#Installer au boulot
install.packages("RPostgreSQL", "C:/Tools/R/")
install.packages("ade4", "C:/Tools/R/")
install.packages("cluster", "C:/Tools/R/")
install.packages("corrplot", "C:/Tools/R/")
install.packages("caret", "C:/Tools/R/")
install.packages("colorspace", "C:/Tools/R/")
install.packages("ggplot2", "C:/Tools/R/")
install.packages("Amelia", "C:/Tools/R/")
install.packages("lsr", "C:/Tools/R/")


## Charger les libraries
library(lsr)
library(RPostgreSQL)

library(ade4)
library(cluster)
library(corrplot)
library(caret)
library(colorspace)
library(ggplot2)
library(Amelia)



######################################################################################################
##
## 1. Ouverture des sources de données : lire la base de données
## 
#####################################################################################################

## Quel est le répertoire de travail courant ?
getwd()

##  Spécifier mon répertoire de travail courant
setwd("F:/Dev/Forum/DISA-forum/r")
setwd("D:/CNRS/Travail_LIENSs/Projets/Forum_des_marais/DISA-forum/r")

###  Accès distant SSH (après avoir ouvert la connexion SSH avec PUTTY, voir PPTX)
######## ATTENTION : AJOUTER LE MOT DE PASSE ########
system('ssh -f forum@134.158.33.178  -L 8005:localhost:5432 -N')

## Ouverture de la connexion sur la base de données
con <- dbConnect(dbDriver("PostgreSQL"), host='localhost', port='8005', dbname='forum', user='forum', password='*******')

## Tester la connexion
test <- dbGetQuery(con, paste("select count(*) from indicateurs.indicateur"))
#46 indicateurs
print(test)


####################################################################################################################
####################################################################################################################
### Travail sur l'indicateur C6 - diversité des habitats
####################################################################################################################
####################################################################################################################

## Initialiser à 2 toutes les notes calibrées. Pour éviter plus tard une grosse requete
## Comme cela, seulement les notes à 1 et 3 seront à modifier dans la table
dbGetQuery(con, paste("update indicateurs.note set i_calibre = 2 where code_ind = 'C6'"))
-- long : 5 min


## Récupérer les notes sur toutes les zhu en France, non nulles. 
notes <- dbGetQuery(con, paste("select * from indicateurs.note where missing is false and code_ind = 'C6'
 "))


#liste des variables présentes 
colnames(notes)
[1] "zhu_gid"   "code_ind"  "i_brut"    "missing"   "i_calibre"

summary(notes$i_calibre)
Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
      2       2       2       2       2       2 


## Sauver les données dans votre répertoire local sous la forme d'un fichier CSV (importable facilement sous Excel)
## Encodage : UTF8
write.table(notes, "./notesC6.csv", sep = "\t")

## Plus tard, vous pourrez rechargez depuis ces fichiers vos données (si pas d'accès à la BD par exemple)
test <- read.delim("notesC6.csv", header = TRUE, sep = "\t", encoding="UTF8")
colnames(test)


######################################################################################################
##
## 2. Transformation des quantitatives en facteur 
## 
#####################################################################################################

## Quelques stats de base
summary(notes$i_brut)
     Min.   1st Qu.    Median      Mean   3rd Qu.      Max. 
0.000e+00 1.410e+02 3.690e+02 6.199e+05 1.050e+03 5.560e+10 
min(notes$i_brut)
0.01710295
max(notes$i_brut)
55595088321
median(notes$i_brut)
368.9124

length(notes[notes$i_brut >= 10000,]$i_brut)

## Au fait, visualiser la distribution
dev.off()
hist(notes[notes$i_brut < 10000,]$i_brut, breaks = 50, main="Distribution des notes brutes C6 sur la France entière \n élaguant les 14789 valeurs > 10000")
dev.copy(png,'./figures/C6_histogramme.png')
dev.off()

########################
## Option 1 : par quantiles
########################

y <- quantile(notes$i_brut,  probs = c(0, 0.33, 0.66, 1), type = 4, na.rm = "TRUE")
i_brut_classes <- cut(notes$i_brut, y)
levels(i_brut_classes)
"(0.0171,195]"   "(195,692]"      "(692,5.56e+10]"

## Graphique montrant le découpage
dev.off()
par(mar=c(5, 10, 5, 0.5)) 
barplot(table(i_brut_classes), main="Découpage de C6 par quantiles \n [0 / 33% / 66% / 100%] ", xlab="cardinalite", horiz="TRUE", las=2 ) ; 
dev.copy(png,'./figures/C6_classee_par_quantiles.png')
dev.off()


## Note, on peut aussi choisir de prendre une discrétisation sur un vecteur de quantiles adapté à nos idées
## Exemple : 0-25% des premiers effectifs, 25-75% des effectifs intermédiaires, 75% et au dela des effectifs 
## probs = c(0, 0.25, 0.75, 1), donc 3 classes
## y <- quantile(notes$i_brut,  probs = c(0, 0.25, 0.75, 1), type = 4, na.rm = "TRUE")
## donc etc.


########################
## Option 2 : si la distribution est gaussienne ou student
########################

## Dans ce cas, non, mais il semble qu'en log10 elle prennne une allure student
## visualiser la distribution en log10
dev.off()
hist(log10(notes$i_brut), breaks = 50, main="Distribution des notes brutes C6 sur la France entière")
dev.copy(png,'./figures/C6_log10_histogramme.png')
dev.off()

############################################################################################
## Si le coefficient de dispersion autour de la moyenne est faible, <0.5
## ou si l'écart-type est au moins plus petit que l'intervalle interquartile et la moyenne est dans l'intervalle interquartile
## Si la moyenne a du sens, (petit intervalle de confiance devant la largeur de l'intervalle de la classe centrale),
## alors on s'autorise à choisir une discrétisation centrée sur la moyenne,
## qui permet de faire une classe centrale regroupant les valeurs les plus moyennes, nombreuse
## et 2 classes par ailleurs pour des valeurs exceptionnellement faibles ou fortes
## Cette discrétisation sera considérée comme adéquate pour décrire les zones humides
############################################################################################

## Calcul du coefficient de variation
cv <-  abs(sd(log10(notes$i_brut)) / mean(log10(notes$i_brut)))
print(cv)
0.2798449

## Intervalle de confiance autour de la moyenne
n<- length(notes$i_brut) #438112
moyenne <- mean(log10(notes$i_brut)) #2.622589
ecartype <- sd(log10(notes$i_brut)) #0.7339181

error <- qt(0.975,df=n-1)*ecartype/sqrt(n)
inf <- moyenne  - error 
sup <- moyenne  + error 
2.620416,2.624762


## si la largeur de l'intervalle de confiance est très petite devant la largeur de l'intervalle de bornage
## alors la méthode vaut le coup. 
ratio <- (sup-inf)/(2 * ecartype) 
print(ratio)
0.002961125
if (ratio < 0.05) { print('ok pour utiliser la méthode moyenne +/- écart-type')} else {print('utiliser la méthode des quantiles')}

# dans ce cas
b1 <- mean(log10(notes$i_brut)) - sd(log10(notes$i_brut))
b2 <- mean(log10(notes$i_brut)) + sd(log10(notes$i_brut))
y <- c(min(notes$i_brut), 10^b1, 10^b2, max(notes$i_brut))
[1] 1.710295e-02 7.738753e+01 2.272517e+03 5.559509e+10


i_brut_classes <- cut(notes$i_brut, y)
levels(i_brut_classes)
[1] "(0.0171,77.4]"       "(77.4,2.27e+03]"     "(2.27e+03,5.56e+10]"

# Pour connaitre les effectifs de chaque classe
table(i_brut_classes)
i_brut_classes
      "(0.0171,77.4]"       "(77.4,2.27e+03]"     "(2.27e+03,5.56e+10]"
              57951              323182               56978 

## Graphique montrant le découpage
dev.off()
par(mar=c(5, 10, 5, 0.5)) 
barplot(table(i_brut_classes), main="Découpage de C6 par moyenne +- écart-type \n [0 / 77.4 / 2270 / 55595088321] ", xlab="cardinalite", horiz="TRUE", las=2 ) ; 
dev.copy(png,'./figures/C6_classee_par_gauss.png')
dev.off()



######################################################################################################
##
## 3. Sauvegarder la discrétisation dans la BDD
## 
#####################################################################################################

# On renomme correctement les classes
levels(i_brut_classes) <- c(1, 2, 3)

## On n'enregistre que 1 et 3 (beaucoup moins de lignes à mettre à jour)
table(i_brut_classes)
     1      2      3 
 57951 323182  56978

length(i_brut_classes)
438112


dim(notes)
438112      5

colnames(i_brut_classes)
notes<- cbind(notes, i_brut_classes)


length(notes[i_brut_classes==1,]$zhu_gid)
57952
head(paste(notes[i_brut_classes==1,]$zhu_gid, collapse=", "))
paste(head(notes[i_brut_classes==1,]$zhu_gid), collapse=", ")

sum(is.na(notes[i_brut_classes==1,]$zhu_gid)==TRUE)
#1
sum(is.na(notes[i_brut_classes==2,]$zhu_gid)==TRUE)
#1
sum(is.na(notes[i_brut_classes==3,]$zhu_gid)==TRUE)
#1

paste(na.omit(notes[i_brut_classes==1,]$zhu_gid), collapse=", ")

## Pour tester
dbGetQuery(con, paste("update indicateurs.note set i_calibre = '",1,"' where code_ind = 'C6' and  zhu_gid in (",paste(head(notes[i_brut_classes==1,]$zhu_gid), collapse=", "),")"));

## Toutes les valeurs
dbGetQuery(con, paste("update indicateurs.note set i_calibre = '",1,"' where code_ind = 'C6' and  zhu_gid in (",paste(na.omit(notes[i_brut_classes==1,]$zhu_gid), collapse=", "),")"));
dbGetQuery(con, paste("update indicateurs.note set i_calibre = '",3,"' where code_ind = 'C6' and  zhu_gid in (",paste(na.omit(notes[i_brut_classes==3,]$zhu_gid), collapse=", "),")"));

## Moins d'1 min pour chaque requete.

## Vérification : vous devez récupérer i_brut_classe 
test <- dbGetQuery(con, paste("select i_calibre  from indicateurs.note where code_ind = 'C6' and missing is false"))
colnames(test) # "i_calibre"

## La requete renvoie une colonne que R voit comme une variable numerique
is.numeric(test$i_calibre)
#[1] TRUE
## Pour convertir en variable factorielle (en classe)
verif <- as.factor(test$i_calibre)
is.factor(verif )
# TRUE

## OK, vérifions ce qui a été enregistré en BDD
table(verif)
verif
     1      2      3 
 57951 323183  56978

test <- dbGetQuery(con, paste("select *  from indicateurs.note where code_ind = 'C6' and i_calibre is null"))
data frame with 0 columns and 0 rows

####################################################################################################################
####################################################################################################################
### Travail sur l'indicateur C7 - diversité des habitants
####################################################################################################################
####################################################################################################################

## Récupérer les notes sur toutes les zhu en France, non nulles. 
notes <- dbGetQuery(con, paste("select * from indicateurs.note where missing is false and code_ind = 'C7'"))

#liste des variables présentes 
colnames(notes)
[1] "zhu_gid"   "code_ind"  "i_brut"    "missing"   "i_calibre"

######################################################################################################
##
## 2. Transformation des quantitatives en facteur 
## 
#####################################################################################################

## Quelques stats de base
summary(notes$i_brut)
    Min.  1st Qu.   Median     Mean  3rd Qu.     Max. 
0.000000 0.008081 0.013950 0.023270 0.024010 0.780400


## Au fait, visualiser la distribution
dev.off()
hist(notes$i_brut, breaks = 50, main="Distribution des notes brutes C7 sur la France entière ")
dev.copy(png,'./figures/C7_histogramme.png')
dev.off()

dev.off()
hist(notes[notes$i_brut<0.2,]$i_brut, breaks = 50, main="Distribution des notes brutes C7 sur la France entière \n élaguant les valeurs > 0.2")
dev.copy(png,'./figures/C7_histogramme_cut.png')
dev.off()

########################
## Option 1 : par quantiles
########################

y <- quantile(notes$i_brut,  probs = c(0, 0.33, 0.66, 1), type = 4, na.rm = "TRUE")
i_brut_classes <- cut(notes$i_brut, y)
levels(i_brut_classes)
[1] "(1.34e-08,0.00982]" "(0.00982,0.0194]"   "(0.0194,0.78]"

## Graphique montrant le découpage
dev.off()
par(mar=c(5, 10, 5, 0.5)) 
barplot(table(i_brut_classes), main="Découpage de C7 par quantiles \n [0 / 33% / 66% / 100%] ", xlab="cardinalite", horiz="TRUE", las=2 ) ; 
dev.copy(png,'./figures/C7_classee_par_quantiles.png')
dev.off()



########################
## Option 2 : si la distribution est gaussienne ou student
########################

## Dans ce cas, non normale, mais il semble qu'en log10 elle prennne une allure student
## visualiser la distribution en log10
dev.off()
hist(log10(notes$i_brut), breaks = 50, main="Distribution des notes brutes C7 en log10 sur la France entière")
dev.copy(png,'./figures/C7_log10_histogramme.png')
dev.off()

############################################################################################
## Si le coefficient de dispersion autour de la moyenne est faible, <0.5
## ou si l'écart-type est au moins plus petit que l'intervalle interquartile et la moyenne est dans l'intervalle interquartile
## Si la moyenne a du sens, (petit intervalle de confiance devant la largeur de l'intervalle de la classe centrale),
## alors on s'autorise à choisir une discrétisation centrée sur la moyenne,
## qui permet de faire une classe centrale regroupant les valeurs les plus moyennes, nombreuse
## et 2 classes par ailleurs pour des valeurs exceptionnellement faibles ou fortes
## Cette discrétisation sera considérée comme adéquate pour décrire les zones humides
############################################################################################

## Calcul du coefficient de variation
cv <-  abs(sd(log10(notes$i_brut)) / mean(log10(notes$i_brut)))
print(cv)
0.2255481

## Intervalle de confiance autour de la moyenne
n<- length(notes$i_brut) #573298
moyenne <- mean(log10(notes$i_brut)) #-1.855818
ecartype <- sd(log10(notes$i_brut)) #0.4185763

error <- qt(0.975,df=n-1)*ecartype/sqrt(n)
inf <- moyenne  - error 
sup <- moyenne  + error 

#Intervalle de confiance à 95 % [-1.856902,-1.854735]


## si la largeur de l'intervalle de confiance est très petite devant la largeur de l'intervalle de bornage
## alors la méthode vaut le coup. 
ratio <- (sup-inf)/(2 * ecartype) 
print(ratio)
0.002588563
if (ratio < 0.05) { print('ok pour utiliser la méthode moyenne +/- écart-type')} else {print('utiliser la méthode des quantiles')}

# dans ce cas
b1 <- mean(log10(notes$i_brut)) - sd(log10(notes$i_brut))
b2 <- mean(log10(notes$i_brut)) + sd(log10(notes$i_brut))
y <- c(min(notes$i_brut), 10^b1, 10^b2, max(notes$i_brut))
print(y)
[1] 1.337616e-08 5.316250e-03 3.653911e-02 7.803775e-01


i_brut_classes <- cut(notes$i_brut, y)
levels(i_brut_classes)
1] "(1.34e-08,0.00532]" "(0.00532,0.0365]"   "(0.0365,0.78]" 

# Pour connaitre les effectifs de chaque classe
table(i_brut_classes)
(1.34e-08,0.00532]   (0.00532,0.0365]      (0.0365,0.78] 
             73867             425417              74013

## Graphique montrant le découpage
dev.off()
par(mar=c(5, 10, 5, 0.5)) 
barplot(table(i_brut_classes), main="Découpage de C7 par moyenne +- écart-type \n [1.34e-08 / 0.00532 / 0.0365/ 0.78] ", xlab="cardinalite", horiz="TRUE", las=2 ) ; 
dev.copy(png,'./figures/C7_classee_par_gauss.png')
dev.off()

######################################################################################################
##
## 3. Sauvegarder la discrétisation dans la BDD
## 
#####################################################################################################

## Initialiser à 2 toutes les notes calibrées. Pour éviter plus tard une grosse requete
## Comme cela, seulement les notes à 1 et 3 seront à modifier dans la table
dbGetQuery(con, paste("update indicateurs.note set i_calibre = 2 where code_ind = 'C7'"))
-- long : 2 min

# On renomme correctement les classes
levels(i_brut_classes) <- c(1, 2, 3)

## On n'enregistre que 1 et 3 (beaucoup moins de lignes à mettre à jour)
table(i_brut_classes)
   1      2      3 
 73867 425417  74013

length(i_brut_classes)
573298

dim(notes)
573298 5

colnames(i_brut_classes)
notes<- cbind(notes, i_brut_classes)


length(notes[i_brut_classes==1,]$zhu_gid)
57952
head(paste(notes[i_brut_classes==1,]$zhu_gid, collapse=", "))
paste(head(notes[i_brut_classes==1,]$zhu_gid), collapse=", ")

sum(is.na(notes[i_brut_classes==1,]$zhu_gid)==TRUE)
#1
sum(is.na(notes[i_brut_classes==2,]$zhu_gid)==TRUE)
#1
sum(is.na(notes[i_brut_classes==3,]$zhu_gid)==TRUE)
#1

paste(na.omit(notes[i_brut_classes==1,]$zhu_gid), collapse=", ")

## Pour tester
dbGetQuery(con, paste("update indicateurs.note set i_calibre = '",1,"' where code_ind = 'C7' and  zhu_gid in (",paste(head(notes[i_brut_classes==1,]$zhu_gid), collapse=", "),")"));

## Toutes les valeurs
dbGetQuery(con, paste("update indicateurs.note set i_calibre = '",1,"' where code_ind = 'C7' and  zhu_gid in (",paste(na.omit(notes[i_brut_classes==1,]$zhu_gid), collapse=", "),")"));
dbGetQuery(con, paste("update indicateurs.note set i_calibre = '",3,"' where code_ind = 'C7' and  zhu_gid in (",paste(na.omit(notes[i_brut_classes==3,]$zhu_gid), collapse=", "),")"));

## Moins d'1 min pour chaque requete.

## Vérification : vous devez récupérer i_brut_classe 
test <- dbGetQuery(con, paste("select i_calibre  from indicateurs.note where code_ind = 'C7' "))
colnames(test) # "i_calibre"

## La requete renvoie une colonne que R voit comme une variable numerique
is.numeric(test$i_calibre)
#[1] TRUE
## Pour convertir en variable factorielle (en classe)
verif <- as.factor(test$i_calibre)
is.factor(verif )
# TRUE

## OK, vérifions ce qui a été enregistré en BDD
table(verif)
verif
    1      2      3 
 73867 427755  74013



test <- dbGetQuery(con, paste("select *  from indicateurs.note where code_ind = 'C6' and i_calibre is null"))
data frame with 0 columns and 0 rows

####################################################################################################################
####################################################################################################################
### Travail sur l'indicateur D9 - contribution des ZHU aux masses d'eau
####################################################################################################################
####################################################################################################################

dbGetQuery(con, paste("select count(*) from indicateurs.note where code_ind = 'D9' and missing is true"))
340051
dbGetQuery(con, paste("select count(*) from indicateurs.note where code_ind = 'D9' "))
575635

## Il faudrait spécifier que si la ZHU n'intersecte aucune masse d'eau à moins de 100m, 
## (missing is true dans 59 %), alors sa contribution est faible.
dbGetQuery(con, paste("update indicateurs.note set i_calibre = 1 where code_ind = 'D9' and missing is true"))

## Ensuite calibrer le restant en fonction de la distribution des contributions
## Initialiser à 2 toutes les notes calibrées. Pour éviter plus tard une grosse requete
## Comme cela, seulement les notes à 1 et 3 seront à modifier dans la table
dbGetQuery(con, paste("update indicateurs.note set i_calibre = 2 where code_ind = 'D9' and missing is false"))
-- long : 5 min


## Récupérer les notes sur toutes les zhu en France, non nulles. 
notes <- dbGetQuery(con, paste("select * from indicateurs.note where missing is false and code_ind = 'D9'"))


#liste des variables présentes 
colnames(notes)
[1] "zhu_gid"   "code_ind"  "i_brut"    "missing"   "i_calibre"

summary(notes$i_calibre)
Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
      2       2       2       2       2       2

summary(notes$i_brut)
 Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
  0.000   0.335   1.246   4.307   3.845 100.000


## Sauver les données dans votre répertoire local sous la forme d'un fichier CSV (importable facilement sous Excel)
## Encodage : UTF8
write.table(notes, "./notesD9.csv", sep = "\t")

## Plus tard, vous pourrez rechargez depuis ces fichiers vos données (si pas d'accès à la BD par exemple)
test <- read.delim("notesD9.csv", header = TRUE, sep = "\t", encoding="UTF8")
colnames(test)


######################################################################################################
##
## 2. Transformation des quantitatives en facteur 
## 
#####################################################################################################

## Quelques stats de base
summary(notes$i_brut)
     Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
  0.000   0.335   1.246   4.307   3.845 100.000

median(notes$i_brut)
1.246

length(notes[notes$i_brut >= 100,]$i_brut)
# 1047 zhu contribuent à 100 %

## Au fait, visualiser la distribution
dev.off()
hist(notes[notes$i_brut < 100,]$i_brut, breaks = 50, main="Distribution des notes brutes D9 sur la France entière \n élaguant les 1047 valeurs = 100%")
dev.copy(png,'./figures/D9_histogramme.png')
dev.off()

########################
## Option 1 : par quantiles
########################

y <- quantile(notes$i_brut,  probs = c(0, 0.33, 0.66, 1), type = 4, na.rm = "TRUE")
i_brut_classes <- cut(notes$i_brut, y)
levels(i_brut_classes)

## Graphique montrant le découpage
dev.off()
par(mar=c(5, 10, 5, 0.5)) 
barplot(table(i_brut_classes), main="Découpage de D9 par quantiles \n [0 / 33% / 66% / 100%] ", xlab="cardinalite", horiz="TRUE", las=2 ) ; 
dev.copy(png,'./figures/D9_classee_par_quantiles.png')
dev.off()


## Note, on peut aussi choisir de prendre une discrétisation sur un vecteur de quantiles adapté à nos idées
## Exemple : 0-25% des premiers effectifs, 25-75% des effectifs intermédiaires, 75% et au dela des effectifs 
## probs = c(0, 0.25, 0.75, 1), donc 3 classes
## y <- quantile(notes$i_brut,  probs = c(0, 0.25, 0.75, 1), type = 4, na.rm = "TRUE")
## donc etc.


########################
## Option 2 : si la distribution est gaussienne ou student
########################

## Dans ce cas, non, mais il semble qu'en log10 elle prennne une allure student
## visualiser la distribution en log10
dev.off()
hist(log10(notes$i_brut), breaks = 50, main="Distribution du log10 des notes brutes D9 sur la France")
dev.copy(png,'./figures/D9_log10_histogramme.png')
dev.off()

############################################################################################
## Si le coefficient de dispersion autour de la moyenne est faible, <0.5
## ou si l'écart-type est au moins plus petit que l'intervalle interquartile et la moyenne est dans l'intervalle interquartile
## Si la moyenne a du sens, (petit intervalle de confiance devant la largeur de l'intervalle de la classe centrale),
## alors on s'autorise à choisir une discrétisation centrée sur la moyenne,
## qui permet de faire une classe centrale regroupant les valeurs les plus moyennes, nombreuse
## et 2 classes par ailleurs pour des valeurs exceptionnellement faibles ou fortes
## Cette discrétisation sera considérée comme adéquate pour décrire les zones humides
############################################################################################

## Calcul du coefficient de variation
cv <-  abs(sd(log10(notes$i_brut)) / mean(log10(notes$i_brut)))
print(cv)
18.506
## la dispersion est forte, mais elle est calculée sur des valeurs négatives.

## observons les écarts inter-quartiles Q1 et Q3. 
## Si la moyenne est incluse dans l'intervalle, et que l'écart-type est plus petit que l'intervalle, on est rassurés
Q <- quantile(log10(notes$i_brut),  probs = c(0, 0.25, 0.75, 1), type = 4, na.rm = "TRUE")
IntervalleInterQuartiles <- as.numeric(Q[3] - Q[2]) #1.059901

sd(log10(notes$i_brut)) #1.025672
mean(log10(notes$i_brut)) #-0.05542376

## La moyenne est bien incluse dans l'intervalle inter quartile
if (Q[2]< mean(log10(notes$i_brut)) & mean(log10(notes$i_brut)) < Q[3]) { print('La moyenne est bien dans l\'intervalle interquartile')} else {print('La moyenne n\'est pas dans l\'intervalle interquartile')}

## L'ecart-type est bien plus petit que l'intervalle interquartile
if (sd(log10(notes$i_brut)) < IntervalleInterQuartiles ) { print('L\'ecart-type est bien plus petit que l\'intervalle interquartile')} else {print('L\'ecart-type est supérieur à l\'intervalle interquartile')}

## Intervalle de confiance autour de la moyenne
n<- length(notes$i_brut) #235584
moyenne <- mean(log10(notes$i_brut)) #-0.05542376
ecartype <- sd(log10(notes$i_brut)) # 1.025672

error <- qt(0.975,df=n-1)*ecartype/sqrt(n)
inf <- moyenne  - error # -0.05956553
sup <- moyenne  + error # -0.05128199

## si la largeur de l'intervalle de confiance est très petite devant la largeur de l'intervalle de bornage
## alors la méthode vaut le coup. 
ratio <- (sup-inf)/(2 * ecartype) 
print(ratio)
if (ratio < 0.05) { print('ok pour utiliser la méthode moyenne +/- écart-type')} else {print('utiliser la méthode des quantiles')}

# si moyenne +/- ecart-type
b1 <- mean(log10(notes$i_brut)) - sd(log10(notes$i_brut))
b2 <- mean(log10(notes$i_brut)) + sd(log10(notes$i_brut))
y <- c(min(notes$i_brut), 10^b1, 10^b2, max(notes$i_brut))


i_brut_classes <- cut(notes$i_brut, y)
levels(i_brut_classes)
#"(3.37e-10,0.083]" "(0.083,9.34]"     "(9.34,100]" 

# Pour connaitre les effectifs de chaque classe
table(i_brut_classes)
#i_brut_classes
#(3.37e-10,0.083]     (0.083,9.34]       (9.34,100] 
#           27042           183471            25070     

## Graphique montrant le découpage
dev.off()
par(mar=c(5, 7, 5, 1)) 
barplot(table(i_brut_classes), main="Découpage de D9 par moyenne +- écart-type \n [0 / 0.083 / 9.34/ 100] ", xlab="cardinalite", horiz="TRUE", las=2 ) ; 
dev.copy(png,'./figures/D9_classee_par_gauss.png')
dev.off()



######################################################################################################
##
## 3. Sauvegarder la discrétisation dans la BDD
## 
#####################################################################################################

# On renomme correctement les classes
levels(i_brut_classes) <- c(1, 2, 3)

## On n'enregistre que 1 et 3 (beaucoup moins de lignes à mettre à jour)

notes<- cbind(notes, i_brut_classes)


length(notes[i_brut_classes==1,]$zhu_gid)
#27043
length(notes[i_brut_classes==3,]$zhu_gid)
#25071

paste(head(na.omit(notes[i_brut_classes==1,]$zhu_gid)), collapse=", ")
# "2332584, 2333824, 2334075, 2327173, 2332642, 2335080"
sum(is.na(notes[i_brut_classes==1,]$zhu_gid)==TRUE)
#1
sum(is.na(notes[i_brut_classes==2,]$zhu_gid)==TRUE)
#1
sum(is.na(notes[i_brut_classes==3,]$zhu_gid)==TRUE)
#1


## Pour tester
dbGetQuery(con, paste("update indicateurs.note set i_calibre = '",1,"' where code_ind = 'D9' and  zhu_gid in (",paste(head(notes[i_brut_classes==1,]$zhu_gid), collapse=", "),")"));

## Toutes les valeurs
dbGetQuery(con, paste("update indicateurs.note set i_calibre = '",1,"' where code_ind = 'D9' and  zhu_gid in (",paste(na.omit(notes[i_brut_classes==1,]$zhu_gid), collapse=", "),")"));
dbGetQuery(con, paste("update indicateurs.note set i_calibre = '",3,"' where code_ind = 'D9' and  zhu_gid in (",paste(na.omit(notes[i_brut_classes==3,]$zhu_gid), collapse=", "),")"));

## Moins d'1 min pour chaque requete.

## Vérification : vous devez récupérer i_brut_classe 
test <- dbGetQuery(con, paste("select i_calibre  from indicateurs.note where code_ind = 'D9' and missing is false"))
colnames(test) # "i_calibre"

## La requete renvoie une colonne que R voit comme une variable numerique
is.numeric(test$i_calibre)
#[1] TRUE
## Pour convertir en variable factorielle (en classe)
verif <- as.factor(test$i_calibre)
is.factor(verif )
# TRUE

## OK, vérifions ce qui a été enregistré en BDD
table(verif)
print(verif)

#verif
#     1      2      3 
# 27042 183472  25070

test <- dbGetQuery(con, paste("select *  from indicateurs.note where code_ind = 'D9' and i_calibre is null"))
#data frame with 0 columns and 0 rows




