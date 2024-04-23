library(tidyverse)
library(fs)
library(sf)
library(sfnetworks)
library(tidygraph)

pkgload::load_all()

# setup -------------------------------------------------------------------

crs_JGD2011 <- 6668

make_network <- function(data,
                         transport = NULL) {
  data |>
    st_make_valid() |>
    st_cast("LINESTRING") |>
    filter(!st_is_empty(geometry)) |>
    as_sfnetwork(directed = FALSE) |>

    activate(nodes) |>
    mutate(transport = factor(transport)) |>
    select(transport, everything()) |>

    activate(edges) |>
    mutate(transport = factor(transport)) |>
    select(transport, everything()) |>

    activate(nodes)
}

get_nodes <- function(transport_network) {
  transport_network |>
    activate(nodes) |>
    as_tibble() |>
    rowid_to_column("id")
}

get_edges <- function(transport_network) {
  transport_network |>
    activate(edges) |>
    as_tibble()
}

link_transport_network <- function(transport_network) {
  # Choose the largest road component for each boundary
  transport_network <- transport_network |>
    activate(nodes) |>
    mutate(component_id = group_components(type = "strong")) |>
    st_join(boundary |>
              st_transform(st_crs(get_nodes(transport_network))),
            join = st_nearest_feature)

  nodes <- get_nodes(transport_network)
  component_id_nodes_road <- nodes |>
    filter(transport == "road") |>
    select(!transport) |>
    st_drop_geometry() |>
    distinct(component_id, boundary_id) |>
    slice_min(component_id,
              by = boundary_id) |>
    select(!boundary_id) |>
    pull(component_id)

  transport_network <- transport_network |>
    filter(transport != "road" | component_id %in% component_id_nodes_road) |>
    select(!component_id)

  # Link road and non-road nodes if they are in the same boundary
  nodes <- get_nodes(transport_network)
  edges <- get_edges(transport_network)

  nodes_road <- nodes |>
    filter(transport == "road") |>
    select(!transport) |>
    rename(to = id,
           geometry_to = geometry,
           boundary_id_to = boundary_id) |>
    # https://github.com/tidyverse/tibble/issues/1552
    rowid_to_column("road_id")

  edges_new <- nodes |>
    filter(transport != "road") |>
    mutate(transport = factor("link_road")) |>
    rename(from = id,
           geometry_from = geometry,
           boundary_id_from = boundary_id) |>
    st_join(nodes_road,
            join = st_nearest_feature) |>
    filter(boundary_id_from == boundary_id_to) |>
    select(!c(boundary_id_from, boundary_id_to)) |>
    mutate(nodes_road |>
             select(geometry_to) |>
             vctrs::vec_slice(road_id)) |>
    select(!road_id) |>
    as_tibble() |>
    mutate(
      geometry = list(geometry_from, geometry_to) |>
        pmap(\(geometry_from, geometry_to) {
          st_linestring(c(geometry_from, geometry_to))
        }),
      .keep = "unused"
    ) |>
    st_as_sf(crs = st_crs(nodes))

  sfnetwork(nodes = nodes |>
              select(!c(id, boundary_id)),
            edges = bind_rows(edges,
                              edges_new),
            directed = FALSE,
            force = TRUE) |>
    activate(edges) |>
    mutate(length = st_length(geometry)) |>
    select(!geometry) |>

    activate(nodes) |>
    filter(group_components(type = "strong") == 1)
}
