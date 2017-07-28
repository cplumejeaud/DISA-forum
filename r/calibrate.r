######################################################################
## Christine PLUMEJEAUD, 25/07/2017
##
## 1. Ouverture des sources de donn�es : lire la base de donn�es
## 2. Transformation des quantitatives en facteur 
## 3. Sauvegarde dans la base de donn�es
##
######################################################################

#####################################################
### 0. Installer et charger des biblioth�ques
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
## 1. Ouverture des sources de donn�es : lire la base de donn�es
## 
#####################################################################################################

## Quel est le r�pertoire de travail courant ?
getwd()

##  Sp�cifier mon r�pertoire de travail courant
setwd("F:/Dev/Forum/DISA-forum/r")

###  Acc�s distant SSH (apr�s avoir ouvert la connexion SSH avec PUTTY, voir PPTX)
######## ATTENTION : AJOUTER LE MOT DE PASSE ########
system('ssh -f forum@134.158.33.178  -L 8005:localhost:5432 -N')

## Ouverture de la connexion sur la base de donn�es
con <- dbConnect(dbDriver("PostgreSQL"), host='localhost', port='8005', dbname='forum', user='forum', password='tetard_79')

## Tester la connexion
test <- dbGetQuery(con, paste("select count(*) from indicateurs.indicateur"))
#46 indicateurs
print(test)


####################################################################################################################
####################################################################################################################
### Travail sur l'indicateur C6 - diversit� des habitants
####################################################################################################################
####################################################################################################################

## R�cup�rer les notes sur toutes les zhu en France, non nulles. 
notes <- dbGetQuery(con, paste("select * from indicateurs.note where missing is false and code_ind = 'C6'
 "))
#liste des variables pr�sentes 
colnames(notes)
[1] "zhu_gid"   "code_ind"  "i_brut"    "missing"   "i_calibre"

## Sauver les donn�es dans votre r�pertoire local sous la forme d'un fichier CSV (importable facilement sous Excel)
## Encodage : UTF8
write.table(notes, "./notesC6.csv", sep = "\t")

## Plus tard, vous pourrez rechargez depuis ces fichiers vos donn�es (si pas d'acc�s � la BD par exemple)
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
hist(notes[notes$i_brut < 10000,]$i_brut, breaks = 50, main="Distribution des notes brutes C6 sur la France enti�re \n �laguant les 14789 valeurs > 10000")
dev.copy(png,'./figures/C6_histogramme.png')
dev.off()

########################
## Option 1 : par quantiles
########################

y <- quantile(notes$i_brut,  probs = c(0, 0.33, 0.66, 1), type = 4, na.rm = "TRUE")
i_brut_classes <- cut(notes$i_brut, y)
levels(i_brut_classes)
"(0.0171,195]"   "(195,692]"      "(692,5.56e+10]"

## Graphique montrant le d�coupage
dev.off()
par(mar=c(5, 10, 5, 0.5)) 
barplot(table(i_brut_classes), main="D�coupage de C6 par quantiles \n [0 / 33% / 66% / 100%] ", xlab="cardinalite", horiz="TRUE", las=2 ) ; 
dev.copy(png,'./figures/C6_classee_par_quantiles.png')
dev.off()


## Note, on peut aussi choisir de prendre une discr�tisation sur un vecteur de quantiles adapt� � nos id�es
## Exemple : 0-25% des premiers effectifs, 25-75% des effectifs interm�diaires, 75% et au dela des effectifs 
## probs = c(0, 0.25, 0.75, 1), donc 3 classes
## y <- quantile(notes$i_brut,  probs = c(0, 0.25, 0.75, 1), type = 4, na.rm = "TRUE")
## donc etc.


########################
## Option 2 : si la distribution est gaussienne
########################

## Dans ce cas, non, mais il semble qu'en log10 elle prennne une allure gaussienne
## visualiser la distribution en log10
dev.off()
hist(log10(notes$i_brut), breaks = 50, main="Distribution des notes brutes C6 sur la France enti�re")
dev.copy(png,'./figures/C6_log10_histogramme.png')
dev.off()

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
      (0.0171,77.4]     (77.4,2.27e+03] (2.27e+03,5.56e+10] 
              57951              323182               56978 

## Graphique montrant le d�coupage
dev.off()
par(mar=c(5, 10, 5, 0.5)) 
barplot(table(i_brut_classes), main="D�coupage de C6 par moyenne +- �cart-type \n [0 / 77.4 / 2270 / 55595088321] ", xlab="cardinalite", horiz="TRUE", las=2 ) ; 
dev.copy(png,'./figures/C6_classee_par_gauss.png')
dev.off()

##################################################
## Tester la normalit� d'une distribution
## http://www.normalesup.org/~carpenti/Notes/Normalite/normalite.html
##################################################


## Tester la normalit� (Shapiro-Wilk) : la taille de l''�chantillon doit �tre comprise entre 3 et 5000
# H0 (non normalit�) est rejet�e au risque p_value, donc H1 (la normalit�) est accept�e si la p-value est petite (< 0.05).
shapiro.test(notes$i_brut)

# Tester la normalit� (Kolmogorov-Smirnov)
# La normalit� est accept�e si la p-value est grande (> 0.05).
moyenne <- mean(log10(notes$i_brut)) #2.622589
ecartype <- sd(log10(notes$i_brut)) #0.7339181

ks.test(log10(notes$i_brut),"pnorm",mean=moyenne, sd=ecartype )
	data:  log10(notes$i_brut)
	D = 0.044627, p-value < 2.2e-16
	alternative hypothesis: two-sided

	Warning message:
	In ks.test(log10(notes$i_brut), "pnorm", mean = moyenne, sd = ecartype) :
  	aucun ex-aequo ne devrait �tre pr�sent pour le test de Kolmogorov-Smirnov


# Tester la normalit� (Anderson-Darling) 
# https://blog.minitab.com/blog/fun-with-statistics/testing-for-normality-a-tale-of-two-samples-by-anderson-darling
# Il teste l'absence de normalit� et une petite p-value (<0.05) indique un manque significatif de normalit�.
library(nortest)
ad.test(log10(notes$i_brut))
	data:  log10(notes$i_brut)
	A = 2299.9, p-value < 2.2e-16

## Donc c'est pas normal !! 

#######################################################################
## Option 3 : a la main
#######################################################################
 
## Par exemple, 300 et 1500 sont 2 bornes qui s�parent bien selon vous . 
bornes <- c(min(notes$i_brut, na.rm=TRUE), 300, 1500, max(notes$i_brut, na.rm=TRUE))
#  1.710295e-02 3.000000e+02 1.500000e+03 5.559509e+10

is.numeric(notes$i_brut) #TRUE
is.numeric(bornes)#TRUE


i_brut_classes <- cut(notes$i_brut, bornes)

## decompte des valeurs dans chaque classe (table ou summary)
summary(i_brut_classes)
      (0.0171,300]      (300,1.5e+03] (1.5e+03,5.56e+10]               NA's 
            194799             160751              82561                  1 

levels(i_brut_classes)
#[1] "(0.0171,300]"       "(300,1.5e+03]"      "(1.5e+03,5.56e+10]"


length(levels(i_brut_classes)) #2




####################################################################################################################
####################################################################################################################
### Travail sur l'indicateur C7 - diversit� des habitants
####################################################################################################################
####################################################################################################################


#

## R�cup�rer les notes sur toutes les zhu en France, non nulles. 
notes <- dbGetQuery(con, paste("select * from indicateurs.note where missing is false and code_ind = 'C7'"))

#liste des variables pr�sentes 
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
hist(notes$i_brut, breaks = 50, main="Distribution des notes brutes C7 sur la France enti�re ")
dev.copy(png,'./figures/C7_histogramme.png')
dev.off()

dev.off()
hist(notes[notes$i_brut<0.2,]$i_brut, breaks = 50, main="Distribution des notes brutes C7 sur la France enti�re \n �laguant les valeurs > 0.2")
dev.copy(png,'./figures/C7_histogramme_cut.png')
dev.off()

########################
## Option 1 : par quantiles
########################

y <- quantile(notes$i_brut,  probs = c(0, 0.33, 0.66, 1), type = 4, na.rm = "TRUE")
i_brut_classes <- cut(notes$i_brut, y)
levels(i_brut_classes)
[1] "(1.34e-08,0.00982]" "(0.00982,0.0194]"   "(0.0194,0.78]"

## Graphique montrant le d�coupage
dev.off()
par(mar=c(5, 10, 5, 0.5)) 
barplot(table(i_brut_classes), main="D�coupage de C7 par quantiles \n [0 / 33% / 66% / 100%] ", xlab="cardinalite", horiz="TRUE", las=2 ) ; 
dev.copy(png,'./figures/C7_classee_par_quantiles.png')
dev.off()



########################
## Option 2 : si la distribution est gaussienne
########################

## Dans ce cas, non, mais il semble qu'en log10 elle prennne une allure gaussienne
## visualiser la distribution en log10
dev.off()
hist(log10(notes$i_brut), breaks = 50, main="Distribution des notes brutes C7 en log10 sur la France enti�re")
dev.copy(png,'./figures/C7_log10_histogramme.png')
dev.off()

# dans ce cas
b1 <- mean(log10(notes$i_brut)) - sd(log10(notes$i_brut))
b2 <-  mean(log10(notes$i_brut)) + sd(log10(notes$i_brut))
y <- c(min(notes$i_brut), 10^b1, 10^b2, max(notes$i_brut))
[1] 1.337616e-08 5.316250e-03 3.653911e-02 7.803775e-01

i_brut_classes <- cut(notes$i_brut, y)
levels(i_brut_classes)
[1] "(1.34e-08,0.00532]" "(0.00532,0.0365]"   "(0.0365,0.78]" 

# Pour connaitre les effectifs de chaque classe
table(i_brut_classes)
i_brut_classes
(1.34e-08,0.00532]   (0.00532,0.0365]      (0.0365,0.78] 
             73867             425417              74013

## Graphique montrant le d�coupage
dev.off()
par(mar=c(5, 10, 5, 0.5)) 
barplot(table(i_brut_classes), main="D�coupage de C7 par moyenne +- �cart-type \n [0 / 0.00532 / 0.0365/ 0.78] ", xlab="cardinalite", horiz="TRUE", las=2 ) ; 
dev.copy(png,'./figures/C7_classee_par_gauss.png')
dev.off()

##################################################
## Tester la normalit� d'une distribution
## http://www.normalesup.org/~carpenti/Notes/Normalite/normalite.html
##################################################


# Tester la normalit� (Kolmogorov-Smirnov)
# La normalit� est accept�e si la p-value est grande (> 0.05).
moyenne <- mean(log10(notes$i_brut)) #-1.855818
ecartype <- sd(log10(notes$i_brut)) #0.7339181


ks.test(log10(notes$i_brut),"pnorm",mean=moyenne, sd=ecartype )
	data:  log10(notes$i_brut)
	D = 0.037982, p-value < 2.2e-16
	alternative hypothesis: two-sided

	Warning message:
	In ks.test(log10(notes$i_brut), "pnorm", mean = moyenne, sd = ecartype) :
  	aucun ex-aequo ne devrait �tre pr�sent pour le test de Kolmogorov-Smirnov


# Tester la normalit� (Anderson-Darling) 
# https://blog.minitab.com/blog/fun-with-statistics/testing-for-normality-a-tale-of-two-samples-by-anderson-darling
# Il teste l'absence de normalit� et une petite p-value (<0.05) indique un manque significatif de normalit�.
library(nortest)
ad.test(log10(notes$i_brut))
	data:  log10(notes$i_brut)
	A = 2272.8, p-value < 2.2e-16

## Donc c'est pas normal !! 



######################################################################################################
##
## 3. Sauvegarder la discr�tisation dans la BDD
## 
#####################################################################################################

# On renomme correctement les classes
levels(i_brut_classes) <- c(1, 2, 3)


## Mettre � jour avec les donn�es de la colonne i_brut_classee
for (i in 1:length(i_brut_classes)) {
   print(i_brut_classes[i]);
   dbGetQuery(con, paste("update indicateurs.note set i_calibre = '",i_brut_classes[i],"' where code_ind = 'C6' and  zhu_gid= ",notes[i, ]$zhu_gid));
}

## V�rification : vous devez r�cup�rer i_brut_classe 
test <- dbGetQuery(con, paste("select i_calibre  from indicateurs.note where code_ind = 'C6' and missing is false"))
colnames(test) # "i_calibre"
summary(test)
   i_calibre      
 Min.   :-1.0000  
 1st Qu.:-1.0000  
 Median :-1.0000  
 Mean   :-0.9932  
 3rd Qu.:-1.0000  
 Max.   : 3.0000 

## La requete renvoie une colonne que R voit comme une variable numerique
is.numeric(test$i_calibre)
#[1] TRUE
## Pour convertir en variable factorielle (en classe)
verif <- as.factor(test$i_calibre)
is.factor(verif )
# TRUE

## OK, v�rifions ce qui a �t� enregistr� en BDD
table(verif)
verif
    -1      1      2      3 
437133    295    365    319

## Comme dit en r�union, on n'a pas du tout tout enregistr�. 

### Au cas o� on ait r�cup�rer des valeurs manquantes marqu�es " NA "
###  rebosser sur les NA
verif[is.na(verif) == TRUE] 
## Mise � jour � NA de toutes les chaines de caract�re " NA "
verif[grep("NA",verif)]<- NA




