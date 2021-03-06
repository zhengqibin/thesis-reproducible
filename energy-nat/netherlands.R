# netherlands.R - calculate Dutch commuter energy costs
nm <- read.csv("NL-Data/2011netherlands.csv", sep=";") # This is the Dutch commuting data, downloaded from the CBS
head(nm)
agrep(pattern=" (PV)", x=nm[,1], )
sub(pattern=" (PV)", replacement="", x=as.character(nm[,1])) # also don't work... calc
class(nm[,1])

head(nm)
names(nm) <- gsub(pattern="Auto..passagier.", replacement="Car.p", x=names(nm))
names(nm) <- gsub(pattern="Auto..bestuurder.", replacement="Car.d", x=names(nm))
names(nm) <- gsub(pattern="Trein", replacement="Train", x=names(nm))
names(nm) <- gsub("Brom..snorfiets", "Moto", x=names(nm))
names(nm) <- gsub(names(nm[8]), "Bicycle", x=names(nm))
names(nm) <- gsub(names(nm[9]), "Walk", x=names(nm))
names(nm) <- gsub(names(nm[10]), "Other", x=names(nm))
names(nm)

library(rgeos) # ensure the right packages are installed
library(rgdal)
setwd("NL-Data/")
regs <- readOGR(dsn=".", layer="Provinces") ; setwd("../")
plot(regs) # distant islands present
r2 <- regs[2:nrow(regs@data),] # remove 1st row, so only mainland regions present
plot(r2)
head(r2@data) # remove excess cols
r2@data <- r2@data[,-c(1,3,4,5,6,7,8,9,10,11,12,14,15:18,20:ncol(r2@data))]

# match-up names
r2@data
nm[,1]
nm <- nm[-2,]
names(nm)
code2 <- strtrim(nm[,1], width=2)
nm$c2 <- toupper(code2)
c2 <- strsplit(as.character(r2$code_hasc), split="[.]" )
r2@data
r2@data$c2 <- unlist(c2)[seq(2,24,2)]
nm$Vervoerwijzen
nm$c2
r2$c2 ; r2$name

merge(y=nm, x=r2@data, by="c2") # test of the merge process...
unmatched <- merge(y=nm, x=r2@data, by="c2")[,1]
unmatched
nm[which(nm$c2 %in% unmatched == F),1:3] # regions that are not matched 1st time
duplicated(regs@data$c2) # no duplicates
nm[,c(1,29)]
nm[10,29] # Says ZU, but should be ZH
nm[10,29] <- "ZH"
nm[9,29] # NO but should be NH, North Holland
nm[9,29] <- "NH"
nm$c2 <- sub("NO", "NB",  nm$c2)
nm[,c(1,29)]
head(nm) # still contains superfluous units
nm <- nm[-1,] # removes superfluous units
head(nm) # missing times + distances for key modes
class(nm$Car.d) # but still factors
for(i in 3:(ncol(nm)-1)){
  nm[,i] <- as.numeric(as.character(nm[,i]))
}
class(nm$Car.d) # numeric - previous for loop worked
natdis <- as.matrix(read.csv("NL-Data/2011netherlands.csv", sep=";")[2,12:19])
natdis <- as.numeric(natdis) # converts data to numeric
(nm)[,12:19] # zeros must be replaced by nat. averages
for(i in 1:8){
  nm[which(nm[,i+11] == 0),i+11] <- natdis[i]
}
head(nm)
# now re-match
?merge # sort = T important to see this default, will result in wrong join if not overridden 
r2@data <- merge(x=r2@data, y=nm, by="c2", sort=F) # worked a treat

fr3 <- fortify(r2, region="c2")
head(fr3)
library(plyr)
names(fr3)[names(fr3) == "id"] <- "c2"
fr3 <- join(x=fr3, y=r2@data)
head(fr3)
p <- ggplot(data = fr3, aes(x=long, y=lat, fill=Car.d))
p + geom_polygon(aes(group=group)) + geom_path(aes(group=group)) + 
  geom_text(data = r2@data ,aes(x=coordinates(r2)[,1],
                                y=coordinates(r2)[,2], label=r2$c2)  )
r2@data

names(fr3)
ec <- c(3,0,0.77,0.57,1.7,0.09,0.13,0) # Energy costs of transport modes, in order 
names(ec) <- names(fr3[,14:21])
ec

r3 <- r2 # new object, to add energy costs to (keep original r2, as backup)
names(r3@data)
# r3@data[,7:14] <- (r3@data[,7:14]) * 2 Originally used this as an approximation - multiply by 2
?sweep # check how this function works
r3$Totaal.vervoerwijzen <- as.numeric(as.character(r3$Totaal.vervoerwijzen))
summary(1/r3$Totaal.vervoerwijzen) # Shows that 2 is a good estimate, but out by an average of 3.7%
r3@data[,7:14] <- sweep(r3@data[,7:14], MARGIN=1, STATS=r3$Totaal.vervoerwijzen, FUN="/" ) # true proportions

ecosts <- r3@data[,7:14] # set-up correctly dimensioned df
for(i in 1:nrow(r3@data)){
  ecosts[i,] <- r3@data[i,7:14] * r3@data[i,16:23] * ec
}
head(r3@data)
r3@data$etot <- rowSums(ecosts)

r3 <- spTransform(r3, CRS("+init=epsg:27700"))
r3$id <- 1:length(r3$name)
fr3 <- fortify(r3, region="c2")
head(fr3)
names(fr3)[7] <- "c2"
fr3 <- join(x=fr3, y=r3@data, by="c2")
head(fr3)
fr3$lat <- fr3$lat / 1000
fr3$long <- fr3$long / 1000
head(fr3)
# if analysis alread done... load(".RData")
p <- ggplot(data = fr3, aes(x=long, y=lat))
p + geom_polygon(aes(group=group, fill=etot)) + geom_path(aes(group=group)) + 
  geom_text(data = r3@data ,aes(x=coordinates(r3)[,1]/1000,
                                y=coordinates(r3)[,2]/1000, label=r3$c2), color = "blue") +
  scale_fill_continuous(low="green", high="red", name="Etrp (MJ)",
                        limits=c(20,55)) + coord_fixed() +
  xlab("Easting (km)") + ylab("Northing (km)") #+ theme_minimal()
# save.image("en-nl.RData")