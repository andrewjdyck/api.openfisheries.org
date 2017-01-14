
# mysql openfisheries.org
# library(RODBC)
library(RMySQL)
library(countrycode)

sendToDb <- function(data, tblname, host, db, uid, pwd) {
	string <- paste("SERVER=", host,
					";DRIVER={MySQL ODBC 5.1 Driver}",
					";DATABASE=", db,
					";uid=", uid,
					";pwd=", pwd, ";", sep="")
	conn <- odbcDriverConnect(string)
	sqlSave(conn, data, tablename=tblname, rownames=FALSE)
}


#source <- "C:/Users/a.dyck/Documents/My Dropbox/business/openfisheries.org/"
source <- "/var/www/openfisheries.org/data/"

data <- read.csv(paste(source, "capture1950to2009.csv", sep=""), as.is=TRUE, header=TRUE)
names(data)[1:4] <- c("country", "species", "area", "measure")
data <- data[which(data$species != ""), ]
#data$iso3c <- countrycode(data$country, "country.name", "iso3c")

# countries
countries <- data.frame(sort(unique(data$country)), stringsAsFactors=FALSE)
countries$iso3c <- countrycode(countries[,1], "country.name", "iso3c")
names(countries)[1] <- "country"

# fix countries: "Channel Islands", "Congo, Republic of", Czechoslovakia", "French Southern Terr", "Other nei", "Tokelau", "Un. Sov. Soc. Rep.", "Yugoslavia SFR", "Zanzibar"
countries$iso3c[which(countries[,1] == "Congo, Republic of")] <- "COG"
countries$iso3c[which(countries[,1] == "Czechoslovakia")] <- "CSK"
countries$iso3c[which(countries[,1] == "French Southern Terr")] <- "ATF"
countries$iso3c[which(countries[,1] == "Tokelau")] <- "TKL"
countries$iso3c[which(countries[,1] == "Yugoslavia SFR")] <- "YUG"
countries$iso3c[which(countries[,1] == "Zanzibar")] <- "EAZ"
countries$iso3c[which(countries[,1] == "Un. Sov. Soc. Rep.")] <- "SUN"
countries$iso3c[which(countries[,1] == "Serbia and Montenegro")] <- "SCG"
countries$iso3c[which(countries[,1] == "Korea, Dem. People's Rep")] <- "PRK"
countries$iso3c[which(countries[,1] == "British Indian Ocean Ter")] <- "IOT"


# These two are not official.
countries$iso3c[which(countries$country == "Other nei")] <- "ZZZ"
countries$iso3c[which(countries$country == "Channel Islands")] <- "CHA"

# merge in country codes
data <- merge(data, countries, by.x="country", by.y="country")

# the official ASFIS species coding
asfis <- read.csv(paste(source, "ASFIS_sp_Feb_2011.csv", sep=""), header=TRUE, as.is=TRUE)
names(asfis) <- tolower(names(asfis))
names(asfis)[3] <- "a3_code"

data$species <- sub("\\[", "", data$species)
data$species <- sub("\\]", "", data$species)
data <- merge(data, asfis, by.x="species", by.y="english_name", all.x=TRUE, all.y=FALSE)
data <- merge(data, asfis, by.x="species", by.y="scientific_name", all.x=TRUE, all.y=FALSE)
data$a3_code.x[which(is.na(data$a3_code.x))] <- data$a3_code.y[which(is.na(data$a3_code.x))]
data <- data[,c(1:65, 68)]

# for parsing the areas
data$inland <- as.numeric(grepl(" - Inland waters", data$area))
data$location <- sub(" - Inland waters", "", data$area)
locations <- data.frame(sort(unique(data$location)), c(1:length(unique(data$location))), stringsAsFactors=FALSE)
names(locations) <- c("location", "location_id")
data <- merge(data, locations, by.x="location", by.y="location")

# remove data on number of fish caught. 
# need just tonnes
data <- data[which(data$measure=="Quantity (tonnes)"),]

# remove unnecessary variables
data$location <- NULL
data$area <- NULL
data$country <- NULL
data$measure <- NULL
data$species <- NULL

###########################
# reshape to long format
###########################
d <- reshape(data, direction="long", varying=list(names(data)[1:60]), v.names="catch", idvar=names(data)[61:64], timevar="year", times=1950:2009)
row.names(d) <- NULL
names(d)[2] <- "a3_code"

# clean junk from catch values
d$catch <- sub("\\.\\.\\.", "", d$catch)
d$catch <- sub("-", "", d$catch)
d$catch <- sub("0 0", "0", d$catch)
d$catch <- sub(" F", "", d$catch)



write.csv(d, "capture.csv", row.names=FALSE, na="")









dfCleanedByStata <- read.table(paste(source, "data/capture.csv", sep=""), sep="\t", as.is=TRUE, header=TRUE)


library(RMySQL)
#rs <- dbSendQuery(mycon, "SELECT * FROM wp_ak_twitter")
#data1 <- fetch(rs, n = -1)

conn <- dbConnect(MySQL(), user='root', dbname='openfisheries', host='localhost', password='supra')
webconn <- dbConnect(MySQL(), user='anddyc1', dbname="openfisheries", host="mysql.midcoastdata.com", password='miDc0astd8A')
dbWriteTable(conn, "capture", d)
dbWriteTable(conn, "countries", countries)
dbWriteTable(conn, "asfis", asfis)
dbWriteTable(conn, "locations", locations)

# end
