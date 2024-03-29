path <-"E:/FORMATION/TP_SERIE_TEMP"
setwd(path)
list.files()
datafile <- "Base.csv"
data <- read.csv(datafile, sep = ";",dec = ",")
data
require(zoo)
require(tseries)
library(plyr)
data<-rename(data, c("�..dates"="dates"))
dates_char<-data$dates
dates_char[1];tail(dates_char,1)
dates<-as.yearmon(seq(1990+0/12,2018+11/12,1/12))
food<-zoo(data$IPI_ALIMENTAIRE,order.by = dates)

# representation de la serie
plot(food, main= "Evolution de l'indice de la production industrielle alimentaire", xlab = "Date", ylab ="IPI alimentaire", col="blue")
#L'observation nous montre que notre n'est pas stationnaire et poss�de une tendance � la hausse. 
#Nous ferons un test de stationnarit� pour confirmer cette intuition.
# Analyse de la tendance.
df.ts = ts(food, frequency = 12, start=c(1990, 01), end = c(2017, 12))
dec <- decompose(df.ts)
plot(dec)
# la serie presente une tendance et donc 

# test de stationarit� de la serie 
require(fUnitRoots)
pp.test(food)
kpss.test(food)
adf <- adfTest(food, lag=0, type="ct")
adf
#Le test  rejette la racine unitaire, mais il n'est pas forc�ment
# valide car on n'a pas v�rifier la validit� des r�sidus
#(ici on suppos� la non autocorrelation des residus, il faut donc v�rifier cela.
# 
# le test de Ljung Box 
Qtests <- function(series, k, fitdf=0)
{
  pvals <- apply(matrix(1:k), 1, FUN= function(l){
    pval <- if(l<=fitdf) NA else{
      Box.test(series, lag = l, type = "Ljung-Box", fitdf = fitdf)$p.value
    }
    return(c("lag"=l, "pval"=pval))
  })
  return(t(pvals))
}
str(adf)
Qtests(adf@test$lm$residuals, 24, length(adf@test$lm$coefficients))
# L'absence d'autocorr�lation des r�sidus est rejet� au moins une fois,
# le test n'est donc pas valide, on refait le test adf, pour un ordre d'autocorrelation k donn�

adfTest_valid <- function(series, kmax,type){
  k<- 0
  noautocorr <- 0
  while(noautocorr==0){
    cat(paste0("ADF with", k, " lags : residuals OK?"))
    adf <- adfTest(food, lags=k, type=type)
    pvals <- Qtests(adf@test$lm$residuals, 24, length(adf@test$lm$coefficients))
    if (sum(pvals<0.05, na.rm = T)==0){
      noautocorr <- 1; cat("OK \n")
    }else cat("nope \n")
    k <- k+1
  }
  return(adf)
}
adfTest_valid(food,24,"ct")
# On a du ajouter 8 retards pour obtenir des r�sidus non autocorr�l�s.
# pval >5% donc on ne rejette pas la racine unitaire,
# la serie food n'est donc pas stationnaire. On la diff�rencie.
dfood <- diff(food)
plot(dfood)
plot(cbind(food,dfood))
# la serie semble relativement stable autour d'une constante
# nulle et pourrait �tre stationnaire.
# la serie food est probablement I(1).


adfTest_valid(dfood, 24, "nc")
adf <- adfTest(dfood, lag=0, type="nc")
adf
# Aucun retard dans le mod�le ADF n'a �t� n�cessaire.
# pvals<5%, on rejette la racine unitaire.
# dfood est donc stationnaire.
# food est donc I(1). d*=1

x <- dfood
par(mfrow=c(1,2))
acf(x);pacf(x)


# Les ACF sont significatives jusqu'� l'ordre 1, donc q*=1.
# Les PACF sont significatives jusqu'� l'ordre 1, donc p*=7.
pmax<-7; qmax<- 1

#### Q5 ####
mat <- matrix(NA, nrow=pmax+1, ncol = qmax+1)
colnames(mat) <- paste0("q= ", 0:qmax)
rownames(mat) <- paste0("p= ", 0:pmax)
AICs <- mat
BICs <- mat
pqs<- expand.grid(0:pmax,0:qmax)
for(row in 1:dim(pqs)[1]){
  p <- pqs[row, 1]
  q <- pqs[row, 2]
  estim <- arima(x,c(p,0,q), include.mean = F)
  AICs[p+1,q+1] <- estim$aic
  BICs[p+1,q+1] <- BIC(estim)
}
AICs
AICs == min(AICs)
# L'ARIMA(1,1,1) minimise l'AIC
BICs
BICs == min(BICs)
# Le MA(1) minimise le BIC.
arima111 <- arima(food, c(1,1,1), include.mean = F)
arima011 <- arima(food, c(0,1,1), include.mean = F)
# Les mod�les ARIMA(1,1,1) et MA(1) pour food
# sont les candidats potentiels

# estmation du mod�le
arima111
# Pour le coef AR(1), coef/se < 1.96. Il n'est donc pas
# significatif � 5% mais l'ai � 10%, 
arima011
# pour le Ma(1), le coef MA(1): coef/se > 1.96 du mod�le MA(1). Le 
# mod�le est donc bien ajust� si les r�sidus ne sont pas autocorr�l�s.

Qtests(arima111$residuals, 24, fitdf = 2)
#Les r�sidus de ARIMA(1,1,1)ne sont pas autocorr�l�s.
Qtests(arima011$residuals, 24, fitdf = 1)
#Les r�sidus de MA(1) ne sont pas autocorr�l�s. 


# Les deux mod�les ARIMA(1,1,1) et MA(1) sont bien ajust�s
# et valides, et minimisent chacun un des crit�res 
# d'information.
# Il nous faut un autre crit�re de s�lection, par exemple
# la performance pr�dictive dans l'�chantillon comme le 
# R2 ajust�.
adj_r2 <- function(model){
  ss_res <- sum(model$residuals^2)
  p <- model$arma[1]
  q <- model$arma[2]
  ss_tot <- sum(dfood[-c(1:max(p,q))]^2)
  n<- model$nobs - max(p,q)
  adj_r2 <- 1-(ss_res/(n-p-q-1))/(ss_tot/(n-1))
  return(adj_r2)
}
adj_r2(arima111); adj_r2(arima011)
# Le ARIMA(1,1,1) a le meilleur R2 ajust�, on le garde donc comme
# meilleur mod�le.
