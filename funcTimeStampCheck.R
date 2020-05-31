# Check Site TimeStamp function
library(plotly)
library(dplyr)
library(ssh)
library(data.table)
library(ggplot2)
library(stringr)

ping <- function(x, stderr = FALSE, stdout = FALSE, ...){
  pingvec <- system2("ping", x,
                     stderr = FALSE,
                     stdout = FALSE,...)
  if (pingvec == 0) TRUE else FALSE
}

ip = "10.116.17.2"
password = "resuresu"
pullTime = "2"
path = "c:/GitHub/ISTimeCheckR/reports/TIS/"

TimeStampCheck <- function(ip, password, pullTime, path) {
  
  # Check connection
  pingResult <- ping(ip)
      if(pingResult == TRUE){
      ## Initialize Connection
      session <- ssh::ssh_connect(host = paste0("user@",ip),passwd = password)
      # Grab "Start Time"
      start<-Sys.time()
      # Grab Data from live port
      ssh::ssh_exec_wait(session, command = paste0("nc localhost 30000 & sleep ",pullTime,"s; kill $!"), 
                         std_out = paste0("C:/GitHub/ISTimeCheckR/ins/input.txt"),
                         std_err = stderr())
      # Grab "End Time"
      end <- Sys.time()
      # Courtesty Disc
      ssh::ssh_disconnect(session)
      
      # Start batch script to Run Python
      shell.exec("C:/GitHub/ISTimeCheckR/bats/time.bat")
      
      # Matchup IP and SiteID
      metaData <- fread("C:/GitHub/ISTimeCheckR/metadata.csv")
      siteIDz <- metaData %>%
        filter(ipAddress == ip) %>%
        select(siteID)
      
      siteIDz <- siteIDz[1,]
      
      # Wait for batch to complete
      Sys.sleep(as.numeric(pullTime)*2.5)
      
      # Read in data that's been converted from binary to CSV
      if(file.exists("C:/GitHub/ISTimeCheckR/outs/output.csv")){
      f <- fread("C:/GitHub/ISTimeCheckR/outs/output.csv", header = FALSE)
      # Grab the inputs/outputs from previous steps
      NandOut <- c("C:/GitHub/ISTimeCheckR/outs/output.csv","C:/GitHub/ISTimeCheckR/ins/input.txt")
      # Delete those files
      for(i in NandOut){
        file.remove(i)
      }
      
      # Give Header Names
      names(f) <- c("TimeStamp","MacAddress","Eeprom","StreamNumber","Data")
      # Convert LC TimeStamps
      f$TimeStamp <- f$TimeStamp/1000000000
      f$TimeStamp <- as.numeric(f$TimeStamp)
      
      # Convert TimeStamps https://stackoverflow.com/questions/30437930/convert-data-frame-with-epoch-timestamps-to-time-series-with-milliseconds-in-r
      f$TimeStamp <- as.POSIXct(f$TimeStamp, origin = "1970-01-01", tz = "UTC")
      f$StartTime <- as.POSIXct(start, tz="UTC")  
      f$EndTime <- as.POSIXct(end, tz="UTC")
      f$PullDate <- Sys.Date()
      
      # Grab just unique eeproms and stream numbers
      ftest <- f %>%
        distinct(Eeprom,.keep_all = TRUE) %>%
        mutate(diffTime = difftime(EndTime,TimeStamp)) %>%
        mutate(siteID = siteIDz)
      
      write.csv(ftest, paste0(path,siteIDz,Sys.Date(),"special2.csv"), row.names = FALSE)
      } else {
        message(paste0("No data pulled from ", ip))
      }
      } else {
        noIpRaw <- fread("C:/GitHub/ISTimeCheckR/reports/noData/noData.csv",stringsAsFactors = FALSE)
        noIp <- ""
        noIp$date <- as.character(Sys.Date()) 
        noIp$ip <- ip
        noIp <- as.data.frame(noIp)
        noIp$X.. <- as.logical(noIp$X..)
        # str(noIp)
        # str(noIpRaw)
        ipList <- list(noIpRaw,noIp)
        masterIP <- rbindlist(ipList)
        write.csv(masterIP, "C:/GitHub/ISTimeCheckR/reports/noData/noData.csv",row.names = F,)
        message(paste0("Could not connect to ", ip))

  # Save histogram
  # ggplot2::ggplot(data=ftest,aes(x=diffTime))+
  #   ggplot2::geom_histogram(bins = 10)+
  #   ggplot2::labs(x = "Difference between Time final and LC time (seconds)", "Number of Streams", title = paste0(siteIDz, "'s Time Difference Analysis "))
  # 
  # ggsave(filename = paste0("C:/GitHub/TimeCheck/reports/",siteIDz,"Histogram.png"), device = "png")
      }
}

# TimeStampCheck(ip = "10.110.17.2",password = "resuresu",pullTime = "2")

metaData <- fread("C:/GitHub/ISTimeCheckR/metadata.csv")
for(i in metaData$ipAddress[1:47]){
  TimeStampCheck(ip = i, password = "resuresu",pullTime = "2", path = "c:/GitHub/ISTimeCheckR/reports/TIS/")
}
for(i in metaData$ipAddress[77:77]){
  TimeStampCheck(ip = i, password = "resuresu",pullTime = "2", path = "c:/GitHub/ISTimeCheckR/reports/TIS/")
}

### Stack all the resulting data with the code below if you so chose

# Grab file names from the set directory
file_names <- list.files("C:/GitHub/ISTimeCheckR/reports/TIS/",pattern="*.csv")

# Import Data -- Assign 'files' to the product of reading though all of the csv's in 'file_names'
setwd("C:/GitHub/ISTimeCheckR/reports/TIS/")
files = lapply(file_names, fread, header=T, stringsAsFactors = F) 

# Import Data -- Bind all of the csv object together
files = rbindlist(files, fill = TRUE)

files$TimeStamp <- as.POSIXct(files$TimeStamp, tz="UTC")
files$StartTime <- as.POSIXct(files$StartTime, tz="UTC")
files$EndTime <- as.POSIXct(files$EndTime, tz="UTC")
files$diffTime <- round(files$diffTime, 2)
files$`Sensor's Timestamp Difference` <- files$diffTime



timeData2 <- files %>%
  group_by(siteID) %>%
  mutate(`Site's Median Timestamp Difference` = median(`Sensor's Timestamp Difference` )) %>%
  mutate(`Sensor's Deviation from the Site's Median Timestamp` = abs(`Site's Median Timestamp Difference`-`Sensor's Timestamp Difference` )) %>%
  filter(`Sensor's Deviation from the Site's Median Timestamp` > 5) %>%
  filter(PullDate >= Sys.Date()-14)


analysisPlot <- ggplot2::ggplot(data=timeData2,aes(x=`Sensor's Deviation from the Site's Median Timestamp`,
                                                   SensorMac=MacAddress,fill=siteID,
                                                   SiteMedianDifferenceTime = `Site's Median Timestamp Difference`))+
  ggplot2::geom_histogram(bins = 30, binwidth = 5)+
  ggplot2::labs(x = "Difference between Time final and LC time (seconds)", 
                y = "Count of Streams in Bin",
                "Number of Streams", 
                title = paste0("Time Difference Histogram Analysis"))
analysisPlot
ggplotly(analysisPlot)
str(timeData)

# Upload files to dropbox
library(rdrop2)
local_KS_token_Path <- "C:/GitHub/swift/SwiftShinyDash/data/token.RDS"
drop_auth(rdstoken = local_KS_token_Path)
saveRDS(timeData2,"C:/Users/kstyers/Dropbox/SwiftData/swiftTimeCheck.rds")
drop_upload(      "C:/Users/kstyers/Dropbox/SwiftData/swiftTimeCheck.rds","SwiftData")
