  library(HUCAgg)
  library(rgdal)
  library(maptools)
  library(dplyr)
  # This script works with data from: https://www.epa.gov/waterdata/nhdplus-national-data
  
  # Set this to where the files are.
  workingPath<-'/Users/dblodgett/Documents/Projects/WaterSmart/5_data/databaseShapefiles/HUC12_NHDPlus/NHDPlusNationalData/'
  
  setwd(workingPath)
  
  WBDPath<-"../NHDPlusV21_National_Seamless.gdb"
  regionsPath<-"regions"
  
  # Found a few HUCs that feed to themselves. These are where they should go.
  hu_fixes <- data.frame(HUC_12 = c("101800100703", "060101051402", "160300020305", 
                                    "170401050304", "101800110901", "101800120602", 
                                    "100200070304", "060101051302"), 
                         HU_12_DS_f = c("101800100702", "060101051404", "160300020306", 
                                        "170401050306", "101800110902", "101800120603", 
                                        "100200070307", "060101051303"), stringsAsFactors = F)
  new_TOHUC <- readr::read_csv("/Users/dblodgett/Documents/Projects/WaterSmart/4_code/nldi_gf/outputs/updated_HU_12_DS.csv") %>%
    rename(HUC12 = HUC_12, new_TOHUC = HU_12_DS)
  
  regions<-init_regions(WBDPath, regionsPath)
  
  options(expressions=50000)
  
  sink(file='error.log',append = FALSE)
  
  out <- data.frame()
  aggrHUCs_out <- list()
  for(region in names(regions)) {
    print(region)
    load(file.path('regions',paste0(region,'.rda')))
    subhucPoly <- combine_multis(subhucPoly)
    subhucPoly@data <- subhucPoly@data %>%
      left_join(hu_fixes, by = c("HUC12" = "HUC_12")) %>%
      mutate(TOHUC = ifelse(is.na(HU_12_DS_f), TOHUC, HU_12_DS_f)) %>%
      select(-HU_12_DS_f) %>%
      left_join(new_TOHUC, by = "HUC12") %>%
      mutate(TOHUC = ifelse(is.na(new_TOHUC), TOHUC, new_TOHUC)) %>%
      select(-new_TOHUC)
    for(subRegion in regions[region][[1]]) { # Mysterious errors occur when the scale is above a region at a time.
      print(paste('aggregating hucs for',subRegion))
      hucList<-getHUCList(subRegion,subhucPoly)
      fromHUC<-sapply(as.character(unlist(hucList)),fromHUC_finder,hucs=subhucPoly@data$HUC12,tohucs=subhucPoly@data$TOHUC)
      aggrHUCs<-sapply(as.character(unlist(hucList)), HUC_aggregator, fromHUC=fromHUC)
      aggrHUCs_out <- c(aggrHUCs_out, aggrHUCs)
      subhucPoly<-unionHUCSet(aggrHUCs, fromHUC, subhucPoly)
      print('simplifying hucs')
      subhucPoly<-simplifyHucs(subhucPoly, simpTol = 1e-04)
    }
    subhucPoly@data$UPHUCS<-paste(unlist(aggrHUCs[as.character(subhucPoly@data$HUC12)]),collapse=',')
    print('writing output')
    tryCatch(
      subhucPoly<-spChFIDs(subhucPoly,subhucPoly@data$HUC12),
      warning = function(w) {print(paste("Warning handling", region, "warning was", w))},
      error = function(e) {print(paste("Error handling", region, "error was", e, "trying to fix"))
        remove<-c()
        for( ind in which(duplicated(subhucPoly@data$HUC12))) { # This is horrible, but it does combine duplicated entries.
          subhucPolySub<-subset(subhucPoly,subhucPoly@data$HUC12 %in% subhucPoly@data$HUC12[ind])
          subhucPolySub@data$group<-1
          subhucPolySub<-spChFIDs(subhucPolySub,as.character(seq(length(subhucPolySub@data$TNMID))))
          subhucPoly@polygons[ind][[1]]<-unionSpatialPolygons(subhucPolySub,subhucPolySub@data$group)@polygons[[1]]
          remover<-which(subhucPoly@data$HUC12 %in% subhucPoly@data$HUC12[ind])
          remove<-c(remove,remover[!remover %in% ind])
        }
        subhucPoly<-subhucPoly[-remove,]
        subhucPoly<-spChFIDs(subhucPoly,subhucPoly@data$HUC12)
      })
    print('writing output pgdump')
    proj4string(subhucPoly) <- CRS('+init=epsg:4269')
    layer_options = c("GEOMETRY_NAME=the_geom", "CREATE_TABLE=ON", "DROP_TABLE=OFF")
    writeOGR(obj = subhucPoly, dsn = paste0(region,'_huc12agg.pgdump'),
             layer = paste0(region,'_huc12agg'), driver = 'PGDUMP', layer_options = layer_options)
    system(paste0("perl -pi -e 's/OGC_FID/ogc_fid/g' ", region, "_huc12agg.pgdump"))
    system(paste0("gzip ", region, "_huc12agg.pgdump"))
    out <- bind_rows(out, subhucPoly@data[c("HUC12", "AREASQKM")])
  }
  sink()
  saveRDS(out, "huc_da.rds")
  saveRDS(aggrHUCs_out, "aggrHUCs.rds")
  