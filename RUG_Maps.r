# Title and resources ----

# Introduction to making maps in R
#     21 September 2020

# Resources:
#   Geocomputation with R | Robin Lovelace, Jakub Nowosad, Jannes Muenchow, 2020 | 
#      <https://geocompr.robinlovelace.net/index.html>
#   Intro to geospatial raster and vector data with R | Leah A. Wasser et al., 2018 |
#      <https://datacarpentry.org/r-raster-vector-geospatial/>
#   Spatial data manipulation | Robert J Hijmans, 2016 | 
#      <https://rspatial.org/raster/spatial/1-introduction.html>
#   Reproducible research course: making maps with r | Eric C. Anderson, 2014 | 
#      <https://eriqande.github.io/rep-res-web/lectures/making-maps-with-R.html>


# Vector data ----

### Vector data - graphically represents the world with points, lines, and polygons
#      Geographic vector data are based on points within a coordinate reference system (CRS)

library(sf)           # Classes and functions for vector data and provides a command-line interface
#                       to GEOS (geometry opterations), GDAL (geographic data files), 
#                       and PROJ (representing and transforming projected coordinate reference systems) 
#                       libraries | raster datasets are NOT supported
library(spData)       # Load geogrpahic data

### Using 'world' dataset from 'spData' containing spatial attribute columns | Grasping base functions
names(world)                 # Returns column names in dataset, "geom" required for 'sf'
world$geom
plot(world)

plot(world["gdpPercap"])
summary(world["gdpPercap"])  # Summary of 'world' data by column

### How to subset spatial dataframe
sub_world <- world[1:2, 1:3] # Subset by the first two rows and first three columns
sub_world 

plot(sub_world)
### 'sf' is most recent package to for vector data, but some packages still rely on 'sp' package
library(sp)

world_sp <- as(world, Class = "Spatial")   # Can convert spatial class back to sf in the same 
world_sp
#                                            manner with 
#                                            > x <- as(world_sp, Class = "sf") 

### Basic mapping with vector data
plot(world)
plot(world[5:7])         # Plot variables 5 - 7
plot(world["area_km2"])  # Plot single variable

## Have capability of layering features, which can verify the geographic correspondence b\w laeyrs
world_NA <- world[world$continent == "North America",]
plot(world_NA)

NorthAm <- st_union(world_NA)            # 'st_union' to combine all features in attribute
plot(NorthAm)

plot(world["area_km2"], reset = FALSE)   # reset = F says to not reset the original key
plot(NorthAm, add = TRUE, col = "green")

## 'sf' extends basic R plotting functions
plot(world["continent"], reset = FALSE)
cex <- sqrt(world$pop) / 10000
world_pop <- st_centroid(world, of_largest_polygon = TRUE)  # 'st_centroid' converts one
#                                                              geometric shape into another,
#                                                              in this case polygon to point
plot(st_geometry(world_pop), add = TRUE, cex = cex)

## Want to get fancy with previous plot??
world_proj <- st_transform(world, "+proj=eck4")  # Spatial reference list available at
#                                                 <spatialreference.org>
world_pop2 <- st_centroid(world_proj, of_largest_polygon = TRUE)
plot(world_proj["continent"], reset = FALSE, main = "", key.pos = NULL)

g <- st_graticule()                             # Creating a network of lines 
#                                                 representing meridians and parallels
g <- st_transform(g, crs = "+proj=eck4")

plot(g$geometry, add = TRUE, col = "lightgrey")
plot(st_geometry(world_pop2), add = TRUE, cex = cex, lwd = 2, graticule = T)

# Raster data ----

### Raster data - graphically divides the surface of the world into  constant sizes with cells
library(raster)       # Load and manipulate raster data
library(rgdal)        # Provides access to Geospatial Data Abstraction Library (GDAL)
library(spDataLarge)  # Load large geographic data | to install need to use 'remotes' package,
#                       which allows installation from remote repositories like GitHub. 
#                       > remotes::install_github("Nowosad/spDataLarge")

## Create a raster layer
rfile <- system.file("raster/srtm.tif", package = "spDataLarge")  # Easiest way to read in a raster
Utah <- raster(rfile)
Utah

plot(Utah)   # Simplest form of a raster object, with one layer

## Creating a single layer raster from scratch
new_raster <- raster(nrows = 6, ncols = 6, res = 0.5, xmn = -1.5, xmx = 1.5, ymn = -1.5, 
                     ymx = 1.5, vals = 1:36)


plot(new_raster)
## Multiple layered rasters -> 'RasterBrick' or 'RasterStack'
# 'RasterBrick' has multiple layers associated with a single satellite file
multi_raster <- system.file("raster/landsat.tif", package = "spDataLarge")
raster_brick <- brick(multi_raster)
raster_brick

plot(raster_brick)

## Difference between 'RasterBrick' and 'RasterStack' is that 'RasterStack' can combine multiple
# rasters from different files with similar extents and resolutions 
# Creating a raster stack using the first layer from the previous "brick" and a raster we create
LS1 <- raster(raster_brick, layer = 1)

random_raster <- raster(xmn = 301905, xmx = 335745, ymn = 4111245, ymx = 4154085, res = 30)
values(random_raster) = sample(seq_len(ncell(LS1)))
crs(random_raster) = crs(LS1)

raster_stack <- stack(LS1, random_raster)
raster_stack

plot(raster_stack)
## How to manipulate rasters
# Cells in a raster can only contain one value, a numeric class, an integer, a logical class, or a factor 

# Make the new raster represent grain size
grain_type <- c("clay", "silt", "sand")
grain_count <- sample(grain_type, 36, replace = TRUE)
grain_asfact <- factor(grain_count, levels = grain_type)

grain_raster <- raster(nrows = 6, ncols = 6, res = 0.5, xmn = -1.5, xmx = 1.5, ymn = -1.5, ymx = 1.5,
               vals = grain_asfact)
grain_raster

plot(grain_raster)
# Add new factor levels to attribute table
levels(grain_raster)[[1]] = cbind(levels(grain_raster)[[1]], wetness = c("wet", "moist", "dry"))
levels(grain_raster)

factorValues(grain_raster, grain_raster[c(2, 15, 36)])

par(mfrow=c(1,2))
plot(new_raster)
plot(grain_raster)

# Making maps ----

library(dplyr)    # Tool for working with data frame like objects
library(tmap)     # Static and interactive maps
library(leaflet)  # Interactive maps
library(ggplot2)  # Tidyverse data visualization package

## Static maps
# tmap syntax is very similar to ggplot2
tm_shape(us_states) +    # "us_states" is dataset option in 'spData'
  tm_polygons()


area <- tm_shape(us_states) + 
  tm_polygons(col = "AREA", style = "jenks")

pop2010 <- tm_shape(us_states) + 
  tm_polygons(col = "total_pop_10", style = "jenks")

pop2015 <- tm_shape(us_states) +
  tm_polygons(col = "total_pop_15", style = "jenks")

tmap_arrange(area, pop2010, pop2015)
# Alter colors with tmaptools::palette_explorer() | will require 'shiny' and 'shinyjs' packages

## Faceted maps
# Multiple static maps to show spatial difference over time
urban_hotspots <- urban_agglomerations %>%
  filter(year %in% c(1970, 1990, 2010, 2030))

tm_shape(world) +
  tm_polygons() +
  tm_shape(urban_hotspots) +
  tm_symbols(col = "black", border.col = "white", size = "population_millions") +
  tm_facets(by = "year", nrow = 2, free.coords = FALSE)
## Animated maps
# Create a map of the 30 largest urban agglomerations from 1950 to 2030

# Will require 'gifski' and 'magick' packages
world_hotspots <- world %>%
  filter(continent != "Antartica") %>%
  tm_shape() +
  tm_polygons() +
  tm_shape(urban_agglomerations) +
  tm_dots(size = "population_millions", title.size = "Population (m)", alpha = 0.5, col = "purple") +
  tm_facets(along = "year", free.coords = FALSE)

tmap::tmap_animation(tm = world_hotspots, filename = "C:/Users/bmcca/Desktop/tmap.gif", width = 1200, height = 800)
magick::image_read("C:/Users/bmcca/Desktop/tmap.gif")
# Series of individual maps being shown in a fast pace

## Interactive maps
# tmap
tmap_mode("view")  # Enters interactive mode
us

tm_shape(us_states) + 
  tm_borders() +
  tm_basemap(server = "OpenTopoMap")

tmap_mode("plot")  # Exits interactive mode

# mapview
library(mapview)

mapview::mapview(us_states)  # Quick format and simple syntax if unfamilar with 'tmap'

# More complicate mapview map with a 'sf' feature
trails %>%
  st_transform(st_crs(franconia)) %>%
  st_intersection(franconia[franconia$district == "Oberfranken",]) %>%
  st_collection_extract("LINE") %>%
  mapview(color = "red", lwd = 3, layer.name = "trails") +
  mapview(franconia, zcol = "district", burst = TRUE) +
  breweries
