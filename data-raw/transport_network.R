source("data-raw/setup.R")

# transport_network -------------------------------------------------------

boundary <- rnaturalearth::ne_countries(country = "japan",
                                        scale = "large") |>
  as_tibble() |>
  st_as_sf() |>
  select() |>
  st_cast("POLYGON") |>
  rowid_to_column("boundary_id")

# global_map_v2_2 ---------------------------------------------------------
dir_global_map_v2_2 <- "data-raw/global_map/v2.2"

transport_network_global_map_v2_2 <- list(road = "roadl_jpn\\.shp$",
                                          railroad = "raill_jpn\\.shp$",
                                          ferry_route = "ferryl_jpn\\.shp$") |>
  imap(\(regexp, transport) {
    dir_ls(dir_global_map_v2_2,
           recurse = TRUE,
           regexp = regexp) |>
      read_sf() |>
      st_transform(crs_JGD2011) |>
      make_network(transport = transport)
  },
  .progress = TRUE)

transport_network_global_map_v2_2 <- bind_graphs(transport_network_global_map_v2_2$road,
                                                 transport_network_global_map_v2_2$railroad,
                                                 transport_network_global_map_v2_2$ferry_route) |>
  as_sfnetwork(force = TRUE) |>
  link_transport_network()

usethis::use_data(
  transport_network_global_map_v2_2,
  overwrite = TRUE
)
