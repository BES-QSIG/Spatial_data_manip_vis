R --vanilla
library(sf)
library('RPostgreSQL')

## building a working example to load collection of vector object to PostgreSQL
## create vector objects
# - lines
line_1 <- sf::st_linestring(matrix(4*c(1, 0, 2, 0, 2, 1, 3, 1), ncol = 2, byrow = TRUE))
line_2 <- sf::st_linestring(matrix(2*c(4, 3, 3, 3, 3, 2, 2, 1), ncol = 2, byrow = TRUE))
line_3 <- sf::st_linestring(matrix(5*c(4, 3, 3, 3, 3, 2, 2, 1, 1, 0, 2, 0, 2, 1, 3, 1), ncol = 2, byrow = TRUE))
my_lines <- sf::st_sfc(line_1, line_2, line_3, crs = sf::st_crs(4326))
my_lines_df <- data.frame(id = c("l_1", "l_2", "l_3"), color = c("blue", "magenta", "tomato3"))
my_lines <- sf::st_sf(my_lines_df, geometry = my_lines)

point_1 <- sf::st_point(c(1, 2))
point_2 <- sf::st_point(3*c(1, 2))
point_3 <- sf::st_point(8*c(1, 2))
my_points <- sf::st_sfc(point_1, point_2, point_3, crs = sf::st_crs(4326))
my_points_df <- data.frame(id = c("p_1", "p_2", "p_3"), color = c("blue", "magenta", "tomato3"))
my_points <- sf::st_sf(my_points_df, geometry = my_points)

my_polygon <- sf::st_sfc(sf::st_buffer(point_1, 0.5), crs = sf::st_crs(4326))
my_polygon <- sf::st_sf(id = "poly_1", color = NA, geometry = my_polygon)

## merge all objects in one collection, note that column name must match, so make sure this is
## the case across your objects

my_objects <- rbind(my_points, my_lines, my_polygon)

plot(sf::st_geometry(my_objects), col = as.character(my_objects$color), lwd = c(1, 2, 3))

## save to your system
sf::st_write(my_points, dsn ='my_points.shp')
sf::st_write(my_lines, dsn = 'my_lines.shp')
sf::st_write(my_polygon, dsn = 'my_polygon.shp')

## LOAD AND MERGE VECTORS OJBECTS
pnt <- sf::st_read("my_points.shp")
lne <- sf::st_read("my_lines.shp")
pol <- sf::st_read("my_polygon.shp")

merged_obj <- rbind(pnt, lne, pol)

## CONNECT to your database
dbcon <- dbConnect(dbDriver('PostgreSQL'), dbname='my_db', host='localhost', port=5432, user='your_username', password='your_password')

## WRITE to your database
## Write to the public schema in PostgreSQL
sf::st_write(merged_obj, dbcon, overwrite = TRUE)
sf::st_write(merged_obj, dbcon, append = TRUE)

## Write to your specific shemas
sf::st_write(merged_obj, dbcon, c("yourschema", "yourtable"), overwrite = TRUE)
sf::st_write(merged_obj, dbcon, c("yourschema", "yourtable"), append = TRUE)
