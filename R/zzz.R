.onAttach <- function(...) {
  msg(cli::rule(crayon::bold("USITC Gravity Database")))
  msg(" ")
  msg("The package documentation and usage examples can be found at https://pacha.dev/usitcgravity/.")
  msg("Visit https://buymeacoffee.com/pacha if you wish to donate to contribute to the development of this software.")
  msg("This library needs 2.5 GB free to create the database locally. Once the database is created, it occupies 810 MB of disk space.")
  msg(" ")
  if (interactive() && Sys.getenv("RSTUDIO") == "1"  && !in_chk()) {
    usitcgravity_pane()
  }
  if (interactive()) usitcgravity_status()
}
