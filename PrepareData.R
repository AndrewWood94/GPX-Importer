list.of.packages <- c("yaml", "dplyr")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if (length(new.packages)){
  install.packages(new.packages)
}

library(dplyr)
library(configr)
source('Analysis functions.R')

parameters = read.config(file = 'Rconfig.yaml')
  
AllData50mNoBreaks = prepare(parameters)


