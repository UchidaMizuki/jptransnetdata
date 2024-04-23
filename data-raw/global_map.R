source("data-raw/setup.R")

# global_map --------------------------------------------------------------

dir_global_map <- "data-raw/global_map"
dir_create(dir_global_map)

# v2.2

dir_global_map_v2_2 <- path(dir_global_map, "v2.2")
dir_create(dir_global_map_v2_2)

destfile <- file_temp()
curl::curl_download("https://www1.gsi.go.jp/geowww/globalmap-gsi/download/data/gm-japan/gm-jpn-all_u_2_2.zip",
                    destfile = destfile)

zip::unzip(destfile,
           exdir = dir_global_map_v2_2)
