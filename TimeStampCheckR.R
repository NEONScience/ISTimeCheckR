library(ssh)

session <- ssh::ssh_connect(host = "user@10.110.17.2",passwd = "resuresu")
start<-Sys.time()
ssh::ssh_exec_wait(session, command = "nc localhost 30000 & sleep 2s; kill $!", std_out = "C:/GitHub/TimeCheck/ins/DSNYoutput.txt",std_err = stderr())
end <- Sys.time()
ssh::ssh_disconnect(session)


### some batch script to translate data just pulled
# https://stackoverflow.com/questions/32015333/executing-a-batch-file-in-an-r-script
# https://www.youtube.com/watch?v=fu2S4MjA6A8
shell.exec("C:/GitHub/TimeCheck/bats/time.bat")
Sys.sleep(3.1)
### 
library(data.table)
library(bit64)
library(dplyr)
f<- fread("C:/GitHub/TimeCheck/outs/DSNYout.csv")
# Delete files after read ins
#Define the file name that will be deleted
NandOut <- c("C:/GitHub/TimeCheck/outs/DSNYout.csv","C:/GitHub/TimeCheck/ins/DSNYoutput.txt")
#Check its existence
for(i in NandOut){
  file.remove(i)
}

names(f) <- c("TimeStamp","MacAddres","Eeprom","StreamNumber","Data")
# f <- f %>% distinct()
f$TimeStamp <- f$TimeStamp/1000000000
f$TimeStamp <- as.numeric(f$TimeStamp)

# https://stackoverflow.com/questions/30437930/convert-data-frame-with-epoch-timestamps-to-time-series-with-milliseconds-in-r
f$TimeStamp <- as.POSIXct(f$TimeStamp, origin = "1970-01-01", tz = "UTC")
f$StartTime <- as.POSIXct(start, tz="UTC")  
f$EndTime <- as.POSIXct(end, tz="UTC")

# Grab just unique eeproms and stream numbers
ftest <- f %>%
  distinct(Eeprom,.keep_all = TRUE) %>%
  mutate(diffTime = difftime(EndTime,TimeStamp))

hist(as.numeric(ftest$diffTime), breaks = 10, xlab = "Seconds from EndTime", main = "STER Time Sync Analysis")
  
library(ggplot2)
ggplot2::ggplot(data=ftest,aes(x=diffTime))+
  ggplot2::geom_histogram()

ggsave(filename = "testplot.png")


library(dplyr)
f <- f %>%
  mutate(diffTime = difftime(EndTime,TimeStamp))



