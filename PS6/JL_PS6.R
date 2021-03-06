#Some packages

library(dplyr)
library(tidyr)
library(data.table)
library(ggplot2)
library("rio")
library(matlib)
library(gdata)
library(tinytex)
library(scales)
library(ggplot2)
library(foreign)
library(rmarkdown)
library(fastDummies)
library(stargazer)
library(naniar)


options(scipen=10000)
options(digits=4)

rm(list=ls())


#Set my working directory
setwd("C:/Users/User/Documents/GitHub/Problem-Sets--753/PS6")

#Import data on employment 2005-2015
emp.2015<-import("nal2005.xls")



#Import data on employment 1995-2004
#Route INEGI 2004
# https://www.inegi.org.mx/sistemas/bie/?idserPadre=10100035
emp.2004<-import("nal.xls")
#Change colnames
colnames(emp.2004)<-emp.2004[3,]

#Keep relevant variables 1
emp.2004<-data.frame(emp.2004[-c(22:138),])

#Keep relevant variables2:
emp.2004<-emp.2004 %>% filter(Indicador=="Población económicamente activa (PEA)"|
                                Indicador=="Trabajadores por cuenta propia" |
                                Indicador=="Trabajadores no remunerados"|
                                Indicador=="Tasa de condiciones críticas de ocupación (TCCO)"|
                                Indicador=="Tasa de trabajo asalariado"|
                                Indicador=="Tasa de presión general (TPRG)"|
                                Indicador=="Tasa de ocupación parcial y desocupación 1 (TOPD1)"|
                                Indicador=="Tasa de desocupación"|
                                Indicador=="Tasa de participación"|
                                Indicador=="Cuenta propia")
#Change colnames
years1<-c(1995:1999)
#2000 only 3 quartes
year2000<-paste(2000,c(2:4), sep=".")
years2<-c(2001:2004)
quarters<-c(1:4)
years2.final<-paste(rep(years2,each=4), quarters, sep=".")
years<-c(years1,year2000,years2.final)
years
colnames(emp.2004)<-c("indicador", years)

#Convert to numeric
emp.2004<-emp.2004 %>% mutate(across(2:25,as.numeric))

#Take average of years for which we have quarterly data
emp.2004.2<-emp.2004[c(1,7:25)]

emp.2004.2<-emp.2004.2 %>% pivot_longer(cols=c(2:20),names_to="year")

#Split year and quarter
emp.2004.2<- emp.2004.2 %>% 
  separate(year,c("year","quarter",sep="."))

#Delete "." columns
emp.2004.2<-emp.2004.2 %>% select(-".")

#Take average
emp.2004.2<-emp.2004.2 %>% group_by(indicador,year) %>% 
  summarise(across(value, mean, na.rm=TRUE)) %>% ungroup()

#Pivot_longer first part
emp.2004.1<-emp.2004 %>% select(c(1:6))
emp.2004.1<-emp.2004.1 %>% pivot_longer(cols=(2:6), names_to="year")

#Append both objects
emp.2004<-bind_rows(emp.2004.1,emp.2004.2)

#Now pivot wider: we want our variables as columns
emp.2004<-emp.2004 %>% pivot_wider(names_from = indicador)

#Rename cols (Also can use rename)
colnames(emp.2004)<-c("year",
                      "pea",
                      "cuenta.propia.total",
                      "no.remunerados.total",
                      "participacion",
                      "desocupacion",
                      "topd1",
                      "tprg",
                      "asalariado",
                      "tcco")

#Calculate tasas
emp.2004 <- emp.2004 %>% 
  mutate(cuenta.propia=(cuenta.propia.total/pea)*100,
         no.remunerados=(no.remunerados.total/pea)*100)


emp.2004<-emp.2004 %>% select(-pea,-cuenta.propia.total,-no.remunerados.total)
################################################
#Now these same variables but for 2005-2015#####

#Change colnames
colnames(emp.2015)<-emp.2015[2,]

#Delete rows 1 and 2
emp.2015<-emp.2015 %>% 
  slice(-c(1,2))

#Delete last rows
emp.2015<-emp.2015 %>% 
  slice(-c(191:195))

#Separate year month
emp.2015<- emp.2015 %>% 
  separate(Periodo,c("year","month"),sep="/")

#Make numeric
emp.2015<-emp.2015 %>% 
  mutate(across(3:14,as.numeric))

#Take year average
emp.2015<-emp.2015 %>% group_by(year) %>% 
  summarise(across(where(is.numeric), mean)) %>% ungroup()

#Rename renumerados lol
emp.2015<- emp.2015 %>% rename(no.remunerados=no.renumerados)
######### Append to have all employment data ######
emp<-bind_rows(emp.2004,emp.2015)


########################################################
#Import data Labor Income Share
LIS<-import("LIS.xlsx")
#### Clean data on the LIS

#First keep only data on WS and LIS
LIS.w<-LIS[,1:19]

#Get vector of colnames
names<-c("WS","LIS1","LIS2")
cats<-c("WE","PBS","Tradables","Non-tradables","Agriculture", "Manufacturing")
names.cats<-paste(names,rep(cats,each=3),sep=".")
names.cats
colnames(LIS.w)<-c("year",names.cats)

#Remove 1st 2 rows
LIS.w<-LIS.w %>% slice(-c(1,2))

#Make everything numeric
LIS.w<- LIS.w %>% mutate(across(where(is.character),as.numeric))

#Merge with data on employmeny
emp.LIS<-merge(emp, LIS.w, by="year",all=TRUE)



###############################
#### Import inflation data ####
###############################
inflation<-import("inflation.xlsx")
colnames(inflation)<-c("year","infl.IPC","infl.suby","infl.no.suby")

#separate year
inflation<-inflation %>%separate(year,c("year","month"),"-") 

#get year averages
inflation<-inflation %>% group_by(year) %>% summarise(across(starts_with("infl"),mean)) %>% ungroup()

#Merge with all our previous data
complete<-merge(emp.LIS,inflation, by="year",all=TRUE)
complete<-complete %>% arrange(year)

#Make labels
years.5<-c("1990",NA,NA,NA,NA,"1995",NA,NA,NA,NA,"2000",NA,NA,NA,NA,"2005",NA,NA,NA,NA,"2010",NA,NA,NA,NA,"2015",NA,NA,NA,NA,"2020")
complete$years.5<-years.5

#########################################################################
#########################################################################
################################# PLOTS #################################
#########################################################################
#########################################################################


# 1st: traditional Phillips Curve
f1<-complete %>% arrange(year) %>% ggplot(aes(x=desocupacion, 
             y=infl.IPC, label=years.5))
f1<-f1+ geom_point() 
f1<-f1+ geom_text(data=complete %>% filter(!is.na(years.5)),aes(label=year),
                  angle=45,hjust=-0.25,vjust=-0.25)
f1<-f1+ theme_bw()
f1<-f1+ geom_path()
f1<-f1+scale_x_continuous(name="Unemployment Rate (%)", 
                        breaks=c(2:8))
f1<-f1+scale_y_continuous(name="Inflation (CPI) (%)")
f1<-f1+ylim(0,40)
f1<-f1+ ggtitle("Inflation and Unemployment Rate: 1995-2020")
f1

ggsave("philips.png")

# 2nd: TCCP
f1<-complete %>% arrange(year) %>% ggplot(aes(x=topd1, 
                                              y=infl.IPC, label=years.5))
f1<-f1+ geom_point() 
f1<-f1+ geom_text(data=complete %>% filter(!is.na(years.5)),aes(label=year),
                  angle=45,hjust=-0.25,vjust=-0.25)
f1<-f1+ theme_bw()
f1<-f1+ geom_path()
f1<-f1+scale_x_continuous(name="Rate of Unemployment and Partial Ocupation (%)", 
                          )
f1<-f1+scale_y_continuous(name="Inflation (CPI) (%)")
f1<-f1+ylim(0,40)
f1<-f1+ ggtitle("Inflation and RUPO: 1995-2020")
f1

ggsave("philips_topd1.png")
######################################################
######################################################
##### Self-employment and Self-employment income share 

f1<-complete %>% arrange(year) %>% ggplot(aes(x=cuenta.propia, 
                                              y=LIS1.WE-WS.WE))
f1<-f1+ geom_point() 
f1<-f1+ geom_text(data=complete %>% filter(!is.na(years.5)),aes(label=year),
                  angle=90,hjust=-0.25,vjust=-0.25)
f1<-f1+ theme_bw()
f1<-f1+scale_x_continuous(name="Self-employment share (%)", limits=c(22.25,24))
f1<-f1+scale_y_continuous(name="Self-employed income Share (%)",limits=c(4,8))
f1<-f1+ ggtitle("Self-employment share and income share: 1995-2015")
f1

ggsave("")
######################################################
######################################################
############ Wage Share and Unemployment ############

f1<-complete %>% arrange(year) %>% ggplot(aes(x=desocupacion, 
                                              y=WS.WE))
f1<-f1+ geom_point() 
f1<-f1+ geom_text(data=complete %>% filter(!is.na(years.5)),aes(label=year),
                  angle=90,hjust=-0.25,vjust=-0.25)
f1<-f1+ theme_bw()
f1
f1<-f1+scale_x_continuous(name="Unemployment rate")
f1<-f1+scale_y_continuous(name="Wage Share", limits=c(25,31))
f1<-f1+ ggtitle("Unemployment and Wage Share in Mexico: 1995-2015")
f1<-f1+geom_path()
f1

######################################################
######################################################
############ Wage Share and TOPD1 ####################

f1<-complete %>% arrange(year) %>% ggplot(aes(x=topd1, 
                                              y=WS.WE))
f1<-f1+ geom_point() 
f1<-f1+ geom_text(data=complete %>% filter(!is.na(years.5)),aes(label=year),
                  angle=90,hjust=-0.25,vjust=-0.25)
f1<-f1+ theme_bw()
f1
f1<-f1+scale_x_continuous(name="Partial employment and unemploymante rate")
f1<-f1+scale_y_continuous(name="Wage Share", limits=c(25,31))
f1<-f1+ ggtitle("Partial employment and unemployment vs Wage Share in Mexico: 1995-2015")
f1<-f1+geom_path()
f1

######################################################
######################################################
############ Wage Share and tpgr ####################

f1<-complete %>% arrange(year) %>% ggplot(aes(x=tprg, 
                                              y=WS.WE))
f1<-f1+ geom_point() 
f1<-f1+ geom_text(data=complete %>% filter(!is.na(years.5)),aes(label=year),
                  angle=90,hjust=-0.25,vjust=-0.25)
f1<-f1+ theme_bw()
f1
f1<-f1+scale_x_continuous(name="Partial Employment and Unemploymante Rate")
f1<-f1+scale_y_continuous(name="Wage Share", limits=c(25,31))
f1<-f1+ ggtitle("Partial employment and unemployment vs Wage Share in Mexico: 1995-2015")
f1<-f1+geom_path()
f1

############################################################
############################################################
############ Wage Share Manuf and topd1 ####################

f1<-complete %>% arrange(year) %>% ggplot(aes(x=topd1, 
                                              y=WS.Manufacturing))
f1<-f1+ geom_point() 
f1<-f1+ geom_text(data=complete %>% filter(!is.na(years.5)),aes(label=years.5),
                  angle=90,hjust=-0.25,vjust=-0.25)
f1<-f1+ theme_bw()
f1
f1<-f1+scale_x_continuous(name="Partial Employment and Unemploymante Rate")
f1<-f1+scale_y_continuous(name="Wage Share", limits=c(17,29))
f1<-f1+ ggtitle("PEUR vs Wage Share in Manufacturing: Mexico 1995-2015")
f1<-f1+geom_path()
f1

############################################################
############################################################
############ Wage Share Manuf and tprg ####################

f1<-complete %>% arrange(year) %>% ggplot(aes(x=tprg, 
                                              y=WS.Manufacturing))
f1<-f1+ geom_point() 
f1<-f1+ geom_text(data=complete %>% filter(!is.na(years.5)),aes(label=years.5),
                  angle=90,hjust=-0.25,vjust=-0.25)
f1<-f1+ theme_bw()
f1
f1<-f1+scale_x_continuous(name="General Pressure Rate")
f1<-f1+scale_y_continuous(name="Wage Share", limits=c(17,29))
f1<-f1+ ggtitle("General Pressure Rate vs Wage Share in Manufacturing: Mexico 1995-2015")
f1<-f1+geom_path()
f1

########################################################################
#######################################################################
############ Wage Share tradables and self-employed ####################

f1<-complete %>% arrange(year) %>% ggplot(aes(x=cuenta.propia, 
                                              y=WS.Tradables))
f1<-f1+ geom_point() 
f1<-f1+ geom_text(data=complete %>% filter(!is.na(years.5)),aes(label=years.5),
                  angle=90,hjust=-0.25,vjust=-0.25)
f1<-f1+ theme_bw()
f1
f1<-f1+scale_x_continuous(name="General Pressure Rate",limits=c(21,25))
f1<-f1+scale_y_continuous(name="Wage Share", limits=c(17,27))
f1<-f1+ ggtitle("General Pressure Rate vs Wage Share in Manufacturing: Mexico 1995-2015")
f1<-f1+geom_path()
f1
