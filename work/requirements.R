userLib <- Sys.getenv("R_LIBS_USER")
if (nzchar(userLib)) {
  dir.create(userLib, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(userLib, .libPaths()))
}

install.packages(c("arrow"), repos = "https://cloud.r-project.org")
