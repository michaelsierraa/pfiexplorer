  #install.packages('rsconnect')

library(rsconnect)

rsconnect::setAccountInfo(name='michaelsierraa',
                          token='8D5456348CCBB47D60CA68C17EFCE954',
                          secret='XZ6dQBTxFYq+9szMccP1nCE3KsP6nKvlsSrJDQBi')
library(rsconnect)
rsconnect::deployApp()