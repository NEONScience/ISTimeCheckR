# Check Site TimeStamp function
library(plotly)
library(dplyr)
library(ssh)
library(data.table)
library(ggplot2)


TimeStampCheck <- function(ip, password, pullTime) {
  ## Initialize Connection
  session <- ssh::ssh_connect(host = paste0("user@",ip),passwd = password)
  # Grab "Start Time"
  start<-Sys.time()
  # Grab Data from live port
  ssh::ssh_exec_wait(session, command = paste0("nc localhost 30000 & sleep ",pullTime,"s; kill $!"), std_out = paste0("C:/GitHub/TimeCheck/ins/input.txt"),std_err = stderr())
  # Grab "End Time"
  end <- Sys.time()
  # Courtesty Disc
  ssh::ssh_disconnect(session)
  
  # Start batch script to Run Python
  shell.exec("C:/GitHub/TimeCheck/bats/time.bat")
  
  # Matchup IP and SiteID
  metaData <- fread("C:/GitHub/TimeCheck/metadata.csv")
  siteIDz <- metaData %>%
    filter(ipAddress == ip) %>%
    select(siteID)
  
  siteIDz <- siteIDz[1,]
  
  # Wait for batch to complete
  Sys.sleep(as.numeric(pullTime)*2.5)
  
  # Read in data that's been converted from binary to CSV
  f <- fread("C:/GitHub/TimeCheck/outs/output.csv", header = FALSE)
  # Grab the inputs/outputs from previous steps
  NandOut <- c("C:/GitHub/TimeCheck/outs/output.csv","C:/GitHub/TimeCheck/ins/input.txt")
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
  
  # Grab just unique eeproms and stream numbers
  ftest <- f %>%
    distinct(Eeprom,.keep_all = TRUE) %>%
    mutate(diffTime = difftime(EndTime,TimeStamp)) %>%
    mutate(siteID = siteIDz)
  
  write.csv(ftest, paste0("C:/GitHub/TimeCheck/reports/",siteIDz,".csv"), row.names = FALSE)
  
  # Save histogram
  # ggplot2::ggplot(data=ftest,aes(x=diffTime))+
  #   ggplot2::geom_histogram(bins = 10)+
  #   ggplot2::labs(x = "Difference between Time final and LC time (seconds)", "Number of Streams", title = paste0(siteIDz, "'s Time Difference Analysis "))
  # 
  # ggsave(filename = paste0("C:/GitHub/TimeCheck/reports/",siteIDz,"Histogram.png"), device = "png")
}

# TimeStampCheck(ip = "10.110.17.2",password = "resuresu",pullTime = "2")

metaData <- fread("C:/GitHub/TimeCheck/metadata.csv")
for(i in metaData$ipAddress[1:1]){
  TimeStampCheck(ip = i, password = "resuresu",pullTime = "2")
}


# Grab file names from the set directory
file_names <- list.files("C:/GitHub/TimeCheck/reports/",pattern="*.csv")

# Import Data -- Assign 'files' to the product of reading though all of the csv's in 'file_names'
files = lapply(file_names, fread, header=T, stringsAsFactors = F)
# Import Data -- Bind all of the csv object together
files = rbindlist(files, fill = TRUE)
timeData <- files %>% distinct() %>% filter(diffTime >20)


analysisPlot <- ggplot2::ggplot(data=timeData,aes(x=diffTime/60, fill = siteID,text=MacAddres))+
  ggplot2::geom_histogram(bins = 10)+
  ggplot2::labs(x = "Difference between Time final and LC time (minutes)", 
                "Number of Streams", 
                title = paste0("Time Difference Analysis"))
ggplotly(analysisPlot)