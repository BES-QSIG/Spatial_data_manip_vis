---
title: RGIS workshop liverpool
subtitle: A BES QE SIG training event
date: 2018-04-12 9:00:00
author: Reto Schmucki
---

 Together with the R script below, you will need to download the data folder available [via this link](https://drive.google.com/file/d/1jJMM_4zqrrkPvex-iJxPNAntTuKe6qt4/view?usp=sharing). The data are contained in a zip file (674Mb) that you will have to unzip and save in your working directory, or amend the path in the R script. The data used in this tutorial should be used for a training purpose only.

 **NOTE:** This tutorial is a work-in-progress and I am expecting to maintain, edit and update the script to improve and add new material.



### Tutorial Aims:

#### <a href="#SpatialObject1"> 1. What is a spatial object? </a>
#### <a href="#SpatialObject2"> 2. Spatial object with sf </a>
#### <a href="#LoadManipulate"> 3. Load and manipulate spatial objects. </a>
#### <a href="#Extracting"> 4. Merge, extract and map spatial object. </a>
#### <a href="#PostgreSQL"> 5. Interfacing R and PostgreSQL/PostGIS. </a>
#### <a href="#PlotWithggplot2"> 6. Mapping your spatial objects </a>

<p></p>

For this "tutorial", you will need some packages and their dependencies

```r
if(!requireNamespace("raster")) install.packages("raster")
if(!requireNamespace("sf")) install.packages("sf")
if(!requireNamespace("rmapshaper")) install.packages("rmapshaper")
if(!requireNamespace("ggplot2")) install.packages("ggplot2")
if(!requireNamespace("ggspatial")) install.packages("ggspatial")
if(!requireNamespace("rgdal")) install.packages("rgdal")
if(!requireNamespace("RPostgreSQL")) install.packages("RPostgreSQL")
if(!requireNamespace("rgbif")) install.packages("rgbif")


library(raster)
library(sf)
library(rmapshaper)
library(ggplot2)
library(ggspatial)
library(RPostgreSQL)
library(rgdal)
library(rgbif)

```

<a name="SpatialObject1"></a>
##### What is a spatial object?
A spatial object is an entity with coordinates in a geographical space (x, y) or (x, y, z) with a specific projection.

> **Coordinates are not enough!** To illustrate this affirmation, just have a look at this example.

```r
# create two ojbects with their long/lat coordinates
point_liverpool <- data.frame(name = 'Liverpool', longitude = -2.98, latitude = 53.41)
point_edinburgh <- data.frame(name = 'Edinburgh', longitude = -3.19, latitude = 55.95)
city_points <- rbind(point_liverpool, point_edinburgh)

# Now have a look at them in a 2D space.
plot(city_points[,c("longitude", "latitude")], pch = 19, col = 'magenta')
text(city_points[,c("longitude", "latitude")], labels = city_points$name, pos = c(2, 4))
```

With these two cities, although the coordinates are right, you have no information about the context of their coordinates.

> *Spatial projection*
> The Coordinate Reference System or CRS of a spatial object tells R where the spatial object is located in geographic space (*see* http://spatialreference.org/).

For example, you might have seen the expression WGS84, the common longitude-latitude (degree decimal), or maybe EPSG:4326.
In other words, spatial objects should come with some information relative to their reference system (CRS), no matter if it's a raster, a point, a line or a complex polygon. To locate an object in space, you need to know the reference system and the units in which the coordinates are expressed.

```r
# Adding a projection to our cities, using WGS84
proj_city_points <- sf::st_as_sf(city_points, coords = c("longitude", "latitude"), crs = 4326)
plot(proj_city_points, pch = 19, col = c("magenta", "blue"), cex = 1.5)
legend("topleft", legend = proj_city_points$name, col = c("magenta", "blue"), pch = 19, cex = 1.5, bty="n")

# get some base layer to see this in perspective
country_sf_gbr <- sf::st_as_sf(raster::getData(name = "GADM", country = 'GBR', level = 1))

# visualize the points on a map
## if you are on a Mac, this might be very slow, see below how we will address this issues (simplify).
plot(country_sf_gbr$geometry, graticule = TRUE, axes = TRUE, col = "wheat1", xlim = c(-15, 5), ylim = c(50, 61))
plot(proj_city_points, pch = 19, col = c("magenta", "blue"), cex = 1.5, add = TRUE)
legend("topleft", legend = proj_city_points$name, col = c("magenta", "blue"), pch = 19, cex = 1.5, bty="n")
text(x = -15, y = 50.2, "EPSG:4326 - WGS84", pos = 4, cex = 0.7)
```

And when you have a CRS, it is possible transform your coordinates and express them, reproject, in another reference system (i.e. on other origin and units). You can change an geometry's projection with the function `st_tranform` from [sf](https://cran.r-project.org/web/packages/sf/) package. Some projections are more appropriate for representing and extract specific metric (e.g. distance, area) from geometry.

```r
# Reproject your city points in OSGB 1936 / British National Grid (EPSG:27700)
proj_city_points_osgb <- sf::st_transform(proj_city_points, crs = 27700)
country_sf_gbr_osgb <- sf::st_transform(country_sf_gbr, crs = 27700)
```

The sf object containing the Great Britain geometry is relatively big, with much detail at high at a resolution level that might be unnecessary when mapping GB. You can simplify the polygon by changing the resolution and the number of points defining your polygons. This can be done with the function `st_simplify` available in [sf](https://cran.r-project.org/web/packages/sf/) or the `ms_simplify` function from the [rmapshaper](https://cran.r-project.org/web/packages/rmapshaper/) package. When simplifying multiple polygons, you need to keep the topology to avoid creation of slivers and holes between polygons. Simplifying your geometry can be particularly helpful as it will speed up the plotting process, an issues that can be particularly acute on MacOS and slowing the rendering of your map.

```r
country_sf_gbr_osgb_simpl <- ms_simplify(country_sf_gbr_osgb, keep = 0.1)

object.size(country_sf_gbr_osgb_simpl)
object.size(country_sf_gbr_osgb)

# visualise the points on a map of GB, with a simplified geometry

plot(country_sf_gbr_osgb_simpl$geometry, graticule = TRUE, axes = TRUE, col = "wheat1", xlim = c(-333585, 713000), ylim = c(20000, 1290000))
plot(proj_city_points_osgb, pch = 19, col = c("magenta", "blue"), cex = 1.5, add = TRUE)
legend("topleft", legend = proj_city_points_osgb$name, col = c("magenta", "blue"), pch = 19, cex = 1.5, bty="n")
text(x = -453585, y = 25000, "EPSG:27700 - OSGB 1936 ", pos = 4, cex = 0.7)

```

> to get coordinates on a plot, you can use the function drawExtent() from the raster package that allow you to clic on a map to get the coordinates of an extent.

```r
plot(country_sf_gbr_osgb_simpl$geometry, graticule = TRUE, axes = TRUE, col = "wheat1")
raster::drawExtent()
```
<a name="SpatialObject2"></a>
#### Building and working with spatial objects using sf in R

This is a revolution, providing a modern, stronger and cleaner workflow to deal with spatial object in R, at least vector data. The "sf" is developed by some of the same people that provide us with "sp", offering an ecosystem that open new opportunities to do GIS in R. The firs place to look for resource is the [sf package website](https://r-spatial.github.io/sf/index.html), this is your first stop to learn how it works and develop new skills in R spatial.

```r
library(sf)

p1 <- sf::st_point(c(1, 2))
p2 <- sf::st_point(c(3, 5))
p3 <- sf::st_multipoint(matrix(2 * c(1, 2, 4, 2, 3, 5, 7, 3), ncol = 2, byrow = TRUE))
p4 <- sf::st_as_sf(data.frame(X = c(1, 4, 3, 7), Y = c(2, 2, 5, 3) ), coords = c("X", "Y"))
p5 <- sf::st_sfc(p1, p2, p3)

plot(p1)
plot(p3, col = "blue", pch = 19)
plot(p2, col = "magenta", pch = 19, add = TRUE)
```

## Modify sf - sfc objects
```r
p6 <- sf::st_cast(x = st_sfc(p3), to = "POINT")
p_multi <- sf::st_cast(p6, ids = c(1, 2, 1, 2), group_or_plist = TRUE, to = "MULTIPOINT")

plot(p_multi[1], ylim = c(0, 20), xlim = c(0, 20), col = "tomato3", pch = 19)
plot(p_multi[2], col = "magenta", pch = 19, add = TRUE)

p7 <- st_cast(x = p4, to = "POINT")
p8 <- rbind(st_cast(x = p4[1:3,], to = "MULTIPOINT"), p4[4,])
p8
```

### Lines
```r
l1 <- sf::st_linestring(matrix(c(1, 1, 2, 2, 3, 3, 4, 4, 4, 2), ncol = 2, byrow = TRUE))
lp <- sf::st_cast(x = sf::st_sfc(l1), to = "MULTIPOINT")
bl1 <- sf::st_buffer(l1, 2)
blp <- sf::st_cast(x = sf::st_sfc(bl1), to = "MULTIPOINT")

plot(lp, col = "blue", pch = 19, cex = 2, ylim = c(-5, 10), xlim = c(-5, 10))
plot(blp, col = "magenta", pch = 19, cex = 1, add = TRUE)
plot(l1, col = "tomato3", lwd = 1.5, add = TRUE)
```

### Polygon
```r
bl1 <- sf::st_buffer(l1, 2)
blp <- sf::st_cast(x = sf::st_sfc(bl1), to = "MULTIPOINT")

plot(bl1, col = "lightblue", border = NA)
plot(lp, col = "blue", pch = 19, cex = 2, ylim = c(-5, 10), xlim = c(-5, 10), add = TRUE)
plot(blp, col = "magenta", pch = 19, cex = 1, add = TRUE)
plot(l1, col = "tomato3", lwd = 1.5, add = TRUE)
```

### Intersects and intesections
```r
p1 <- sf::st_as_sf(data.frame(X = c(1, 4, 3, 7), Y = c(2, 2, 5, 3) ), coords = c("X", "Y"), crs = 4326)
poly1 <- st_as_sfc(st_bbox(st_buffer(p1[2,], 2)))
poly2 <- st_as_sfc(st_bbox(st_buffer(p1[3,], 1.5)))

plot(st_geometry(poly1), col = "goldenrod", xlim = c(-5, 5), ylim = c(0, 10))
plot(st_geometry(poly2), col = rgb(1,1,0,0.3), add = TRUE)
plot(st_geometry(p1), col = "magenta", pch = 19, cex= 1.5, add = TRUE)

## INTERSECTION
poly3 <- sf::st_intersection(poly1, poly2)
plot(st_geometry(poly3), col = "lightblue", add = TRUE)

## INTERSECT
p1_poly1 <- sf::st_intersects(p1, poly1, sparse = FALSE)
plot(st_geometry(p1[p1_poly1,]), col = "turquoise", pch = 19, cex = 2, add = TRUE)
```

### circle buffer intersection
```r
poly1 <- sf::st_buffer(p1[2,], 2)
poly2 <- sf::st_buffer(p1[3,], 1.5)
int_b2_b1 <- sf::st_intersection(poly2, poly1)

plot(st_geometry(poly1), col = NA, border = "red", ylim = c(0, 7), axes = TRUE)
plot(st_geometry(poly2), add = TRUE)
plot(st_geometry(p1[2,]), col = "black", pch = 19, add = TRUE)
plot(st_geometry(p1[3,]), col = "blue", pch = 19, add = TRUE)
plot(st_geometry(int_b2_b1), col = "lightblue", boder = NA, add = TRUE)
```

#### Difference between objects
```r
poly1 <- sf::st_buffer(p1[2,], 2)
poly2 <- sf::st_buffer(p1[2,], 4)
dif_poly2_poly1 <- sf::st_difference(poly2, poly1)

plot(st_geometry(dif_poly2_poly1), col = "orange", axes = TRUE)
plot(st_geometry(poly1), col = "blue", add = TRUE)
```

#### Union (merge and melt) objects
```r
poly1 <- sf::st_buffer(p1[2,], 2)
poly2 <- sf::st_buffer(p1[2,], 4)
uni_poly1_2 <- sf::st_union(dif_poly2_poly1, poly1)

plot(st_geometry(uni_poly1_2), col = "lightblue", axes = TRUE)
plot(st_geometry(poly1), col = "tomato3", add = TRUE)
plot(st_geometry(st_buffer(poly1,-1)), col = "white", add = TRUE)
plot(st_geometry(st_centroid(poly1)), col = "black", pch = 19, add = TRUE)
```

If you like it tidy and the dplyr way? Since sf is essentally a data.frame with  a list of spatial attribute attached, it works well in the tidy univers. Have a look at this blog to get a first feel http://strimas.com/r/tidy-sf/.


<a name="LoadManipulate"></a>
##### Load and manipulate spatial objects

Spatial data are increasingly available from the Web, from species occurrence to natural and  cultural features data, accessing spatial data is now relatively easy. For base layers, you can find many freely available data sets such as the ones provided by the Natural Earth [http://www.naturalearthdata.com], the IUCN Protected Planet database [www.protectedplanet.net], the GADM project [https://gadm.org], worldclim [http://worldclim.org/version2] the CHELSA climate data sets [http://chelsa-climate.org] or the European Environmental Agency [https://www.eea.europa.eu/data-and-maps/data#c0=5&c11=&c5=all&b_start=0]

#### Raster object
```r
library(raster)
# annual mean temperature
chelsa_amt <- raster::raster("data/CHELSA_bio10_1.tif")
raster::plot(chelsa_amt)
chelsa_amt

# crop climate data for a specific bounding box
chelsa_amt_gbr <- raster::crop(chelsa_amt, raster::extent(country_sf_gbr)) # cut the worldwide raster according to
raster::plot(chelsa_amt_gbr)

# convert temperature data in usual unit
chelsa_amt_gbr[] <- chelsa_amt_gbr[]*0.1 # convert temperature data in usual unit
raster::res(chelsa_amt_gbr)

# change resolution aggregate() or disaggregate()
chelsa_amt_gbr_2 <- raster::disaggregate(chelsa_amt_gbr, fact=4)
raster::res(chelsa_amt_gbr_2)

chelsa_amt_gbr_3 <- raster::aggregate(chelsa_amt_gbr, fact=4)
raster::res(chelsa_amt_gbr_3)
raster::plot(chelsa_amt_gbr_3)
```
> *Other format for gridded data*
>netCDF format is commonly used for gridded time series (temperature)

```r
rast_1 <- raster::raster("data/tg_0.25deg_reg_2011-2017_v17.0.nc", band = 1)
rast_2 <- raster::raster("data/tg_0.25deg_reg_2011-2017_v17.0.nc", band = 2)
rast_stack <- raster::stack(rast_1, rast_2)
plot(rast_stack$mean.temperature.1)
plot(rast_stack)
```
#### Land cover
```r
eunis_1km <- raster::raster("data/es_l1_1km.tif")
raster::plot(eunis_1km)
raster::projection(eunis_1km)
```

#### Spatial extraction (raster value for a vector object)
```r
proj_city_points_laea <- sf::st_transform(proj_city_points, raster::projection(eunis_1km))
eunis_city <- raster::extract(eunis_1km, as(proj_city_points_laea, "Spatial"))
eunis_city <- raster::extract(eunis_1km, as(sf::st_buffer(proj_city_points_laea, 10000), "Spatial"))

str(eunis_city)
table(eunis_city[[1]])

proportion <- as.numeric(table(eunis_city[[1]]))[which(names(table(eunis_city[[1]]))!="10")] / sum(as.numeric(table(eunis_city[[1]]))) * 100
proportion
```

#### Vector object
```r
library(sf)
st_prov <- sf::st_read("data/GADM_2.8_GBR_adm2.shp")
plot(st_prov[,"HASC_2"], graticule = TRUE, axes = TRUE)

# Older option
library(rgdal)
st_prov_sp <- rgdal::readOGR("data", "GADM_2.8_GBR_adm2")
class(st_prov_sp)
plot(st_prov_sp, axes = TRUE)

# Change projection of an "sp" object
crs.osgb = CRS("+init=epsg:27700")
st_prov_sp.osgb = sp::spTransform(st_prov_sp, crs.osgb)
plot(st_prov_sp.osgb, axes = TRUE)

spplot(st_prov_sp.osgb, "HASC_2", colorkey = FALSE)
```

#### Read and write your spatial object in Shapefile
```r
# read with "sf"
st_prov <- sf::st_read("data/GADM_2.8_GBR_adm2.shp")

# write with "sf"
sf::st_write(st_prov, dsn = "st_prov.shp", delete_layer = TRUE)

# write with OGR (rgdal)
st_prov_sp <- sf::as(st_prov, "Spatial")
rgdal::writeOGR(st_prov_sp, "st_prov_sp", driver = "ESRI Shapefile")
```

### Subseting and filtering

```r
wdpa_gbr <- sf::st_read("data/wdpa_gbr.shp")
wdpa_gbr <- wdpa_gbr[wdpa_gbr$MARINE == 0,]
plot(wdpa_gbr$geometry)

## bounding box
bb <- sf::st_bbox(country_sf_gbr)
bb

## faster solution
bb_poly <- sf::st_make_grid(country_sf_gbr, n = 1)
wdpa_gbr_2 <- sf::st_intersects(wdpa_gbr, bb_poly, sparse = FALSE)
wdpa_gbr <- wdpa_gbr[wdpa_gbr_2,]
plot(wdpa_gbr$geometry[wdpa_gbr$IUCN_CAT == "V"])

wdpa_cntr <- sf::st_centroid(wdpa_gbr)
plot(wdpa_cntr$geometry)

## building a box from the st_bbox output
g.bbox <- raster::extent(as.numeric(sf::st_bbox(country_sf_gbr))[c(1,3,2,4)])
g.bbox_sf <- sf::st_set_crs(sf::st_as_sfc(as(g.bbox, 'SpatialPolygons')), 3035)
plot(g.bbox_sf, add = TRUE)
```
> *Try it your self*
> Get some river data from
> http://land.copernicus.eu/pan-european/satellite-derived-products/eu-hydro/eu-hydro-public-beta/eu-hydro-river-network/view

<a name="PostgreSQ"></a>
##### Interfacing R and PosgreSQL/PostGIS
1. Install PostgreSQL, with the PostGIS extension
2. Create a database
3. Populate your database
4. Extract from your database

**NOTE** This section with PostgreSQL require that you have a functional installation of PostgreSQL with the spatial extension PostGIS. I will add some installation instruction for Windows and Mac, later when I get some time, but if you are curious, search the web as it is a good and resourceful place to start.

## Create PostgreSQL database
```r
library('RPostgreSQL')

# create a new database in on your local PostgreSQL server
sql_createdb <- paste0("-h localhost -U ", "postgres", " -T ", "postgis_22_sample", " -E UTF8 -O postgres ", "RGIS_workshop")
system2("createdb", sql_createdb, invisible = FALSE)

# connect R to your server and newly created database
drv <- dbDriver("PostgreSQL")
dbcon <- dbConnect(drv, dbname = "RGIS_workshop",
                 host = "localhost", port = 5432,
                 user = "postgres", password = "****")

# create a schema, send your first SQL statement (query)
sql_createschema <- paste0("CREATE SCHEMA IF NOT EXISTS my_shemas AUTHORIZATION postgres;")
dbSendStatement(dbcon, sql_createschema)

# have a look at your PostgreSQL database, using pgAdmin
```

#### Send spatial data to your newly created database located on your local server
```r
library(sf)
dbcon <- dbConnect(drv, dbname = "RGIS_workshop",
                 host = "localhost", port = 5432,
                 user = "postgres", password = "*****")

wdpa_gbr <- sf::st_read("data/wdpa_gbr.shp")
sf::st_write(wdpa_gbr, dbcon, overwrite = TRUE)

# check if you succeeded
dbExistsTable(dbcon, "wdpa_gbr")

# extract some data with a SQL query and a condition
psql_extract <- dbGetQuery(dbcon, "SELECT \"IUCN_CAT\", ST_AsText(geometry) as geom FROM wdpa_gbr WHERE \"IUCN_CAT\" = \'V\' AND \"MARINE\" = \'0\'")

str(psql_extract)
new_extract <- sf::st_as_sf(psql_extract, wkt = "geom")
new_extract <- sf::st_set_crs(new_extract, 4326)
plot(new_extract)

new_area <- sf::st_area(sf::st_transform(new_extract, 27700))
head(new_area)
```

#### Interacting with PostgreSQL through your terminal

> *In your terminal, type*
> ogr2ogr -f "PostgreSQL" -t_srs EPSG:27700 PG:"host=localhost port=5432 dbname=RGIS_workshop user=postgres password=****" 'C:\\Users\\retoschm\\OneDrive - Natural Environment Research Council\\Rgis_workshop\\data\\GADM_2.8_GBR_adm2.shp' -nln public.wdpa_gbr2 -nlt MULTIPOLYGON -overwrite -progress -unsetFid --config PG_USE_COPY YES

#### Some more raster operations

##### Hillshade and Terrain map
```r
library(raster)
alt <- raster::getData("alt", country = "GBR")
slope <- raster::terrain(alt, opt = "slope")
aspect <- raster::terrain(alt, opt = "aspect")
hill <- raster::hillShade(slope, aspect, angle = 40, direction = 270)

# plot your raster and newly extracted polygons on a map
raster::plot(hill, col = grey(0:100/100), legend = FALSE)
plot(sf::st_transform(new_extract, 4326), add = TRUE)
raster::plot(alt, col = terrain.colors(25, alpha = 0.5), add = TRUE)
```

<a name="PlotWithggplot2"></a>
#### Plot your spatial object data with ggplot2
```r
library(ggplot2)
library(ggspatial)
library(rmapshaper)

country_sf_gbr <- sf::st_as_sf(raster::getData(name = "GADM", country = 'GBR', level = 1))
country_sf_gbr_osgb <- sf::st_transform(country_sf_gbr, crs = 27700)
country_sf_gbr_osgb_simpl <- ms_simplify(country_sf_gbr_osgb, keep = 0.1)

point_liverpool <- data.frame(name = 'Liverpool', longitude = -2.98, latitude = 53.41)
point_edinburgh <- data.frame(name = 'Edinburgh', longitude = -3.19, latitude = 55.95)
city_points <- rbind(point_liverpool, point_edinburgh)
proj_city_points_osgb <- sf::st_transform(sf::st_as_sf(city_points, coords = c("longitude", "latitude"), crs = 4326), crs = 27700)

## simple plot with ggplot
ggplot(data = country_sf_gbr_osgb_simpl) +
    geom_sf() +
    xlab("Longitude") + ylab("Latitude") +
    ggtitle("GBR map", subtitle = paste0("(", length(unique(country_sf_gbr_osgb_simpl$NAME_1)), " countries)"))

## add some colors
ggplot(data = country_sf_gbr_osgb_simpl) +
    geom_sf(color = "black", fill = "wheat1" ) +
    xlab("Longitude") + ylab("Latitude") +
    ggtitle("GBR map", subtitle = paste0("(", length(unique(country_sf_gbr_osgb_simpl$NAME_1)), " countries)"))

## color with some qualitative meaning
ggplot(data = country_sf_gbr_osgb_simpl) +
    geom_sf(aes(fill = as.numeric(sf::st_area(country_sf_gbr_osgb_simpl)))) +
    scale_fill_viridis_c(option = "plasma", name = "Area") +
    xlab("Longitude") + ylab("Latitude") +
    ggtitle("GBR map", subtitle = paste0("(", length(unique(country_sf_gbr_osgb_simpl$NAME_1)), " countries)"))

# add a scale bar and a north arrow
ggplot(data = country_sf_gbr_osgb_simpl) +
    geom_sf() +
    xlab("Longitude") + ylab("Latitude") +
    annotation_scale(location = "bl", width_hint = 0.5) +
    annotation_north_arrow(location = "bl", which_north = "true",
          pad_x = unit(0.75, "in"), pad_y = unit(0.5, "in"),
          style = north_arrow_fancy_orienteering) +
    ggtitle("GBR map", subtitle = paste0("(", length(unique(country_sf_gbr_osgb_simpl$NAME_1)), " countries)"))

# add more spatial object with geom_sf
ggplot(data = country_sf_gbr_osgb_simpl) +
    geom_sf() +
    geom_sf(data = proj_city_points_osgb, size = 4, color = c("magenta", "blue")) +
    xlab("Longitude") + ylab("Latitude") +
    annotate(geom = "text",
            x = sf::st_coordinates(sf::st_centroid(country_sf_gbr_osgb_simpl))[,1],
            y = sf::st_coordinates(sf::st_centroid(country_sf_gbr_osgb_simpl))[,2],
            label = country_sf_gbr_osgb_simpl$NAME_1,
        fontface = "italic", color = "grey22", size = 3)  +
    annotation_scale(location = "bl", width_hint = 0.5) +
    annotation_north_arrow(location = "bl", which_north = "true",
          pad_x = unit(0.75, "in"), pad_y = unit(0.5, "in"),
          style = north_arrow_fancy_orienteering) +
    ggtitle("GBR map", subtitle = paste0("(", length(unique(country_sf_gbr_osgb_simpl$NAME_1)), " countries)"))
```

#### Adding a raster to a ggplot
```r
library(raster)
alt <- raster::getData("alt", country = "GBR")
# need to reproject your raster to match the other layer and get a regular resolution
alt_prj <- raster::projectRaster(alt, crs = sp::CRS("+init=epsg:27700"), res = 1000)

# first method
alt_prj_df <- raster::as.data.frame(alt_prj, xy = TRUE)
colnames(alt_prj_df)  <- c("x", "y", "Altitude")

ggplot() +
    geom_tile(data = alt_prj_df, aes(x = x, y = y, fill = Altitude)) +
    xlab("Longitude") + ylab("Latitude") +
    annotate(geom = "text",
            x = sf::st_coordinates(sf::st_centroid(country_sf_gbr_osgb_simpl))[,1],
            y = sf::st_coordinates(sf::st_centroid(country_sf_gbr_osgb_simpl))[,2],
            label = country_sf_gbr_osgb_simpl$NAME_1,
        fontface = "italic", color = "white", size = 3) +
    annotation_scale(location = "bl", width_hint = 0.5) +
    annotation_north_arrow(location = "bl", which_north = "true",
          pad_x = unit(0.75, "in"), pad_y = unit(0.5, "in"),
          style = north_arrow_fancy_orienteering) +
    ggtitle("GBR map", subtitle = paste0("(", length(unique(country_sf_gbr_osgb_simpl$NAME_1)), " countries)")) +
    theme(panel.background = element_rect(fill = "aliceblue"))

## second method (better)
alt_prj_spdf <- as(alt_prj, "SpatialPixelsDataFrame")
alt_prj_df2 <- as.data.frame(alt_prj_spdf)
colnames(alt_prj_df2) <- c("Altitude", "x", "y")

ggplot() +
    geom_sf(data = country_sf_gbr_osgb_simpl) +
    geom_tile(data = alt_prj_df2, aes(x = x, y = y, fill = Altitude)) +
    geom_sf(data = proj_city_points_osgb, size = 4, color = c("magenta", "blue")) +
    xlab("Longitude") + ylab("Latitude") +
    annotate(geom = "text",
            x = sf::st_coordinates(sf::st_centroid(country_sf_gbr_osgb_simpl))[,1],
            y = sf::st_coordinates(sf::st_centroid(country_sf_gbr_osgb_simpl))[,2],
            label = country_sf_gbr_osgb_simpl$NAME_1,
        fontface = "italic", color = "white", size = 3) +
    annotation_scale(location = "bl", width_hint = 0.5) +
    annotation_north_arrow(location = "bl",which_north = "true",
          pad_x = unit(0.75, "in"), pad_y = unit(0.5, "in"),
          style = north_arrow_fancy_orienteering) +
    ggtitle("GBR map", subtitle = paste0("(", length(unique(country_sf_gbr_osgb$NAME_1)), " countries)")) +
    theme(panel.background = element_rect(fill = "aliceblue"))
```

#### Can you plot the deer occurrence extracted from GBIF on a UK map?
```r
library(rgbif)
deer_locations <- occ_search(scientificName = "Cervus elaphus", limit = 5000,
                             hasCoordinate = TRUE, country = "GB",
                             return = "data") %>% dplyr::select(key, name, decimalLongitude,
		                         decimalLatitude, year, individualCount, datasetKey, country)

deer_locations_sf <- sf::st_as_sf(deer_locations, coords = c("decimalLongitude", "decimalLatitude"), crs = 4326)
plot(deer_locations_sf[, "datasetKey"])
# ============
# YOUR TURN!
# ===========
```

### Your challenge, build some wider map for Europe

Have a look at tutorial 1, 2 and 3 on how to draw beautiful map with sf.

1. https://www.r-spatial.org/r/2018/10/25/ggplot2-sf.html
2. https://www.r-spatial.org/r/2018/10/25/ggplot2-sf-2.html
3. https://www.r-spatial.org/r/2018/10/25/ggplot2-sf-3.html

Look at the exellent sf vignettes (*see list here*: https://cran.r-project.org/web/packages/sf/index.html)
