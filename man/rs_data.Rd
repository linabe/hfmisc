% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/data.R
\docType{data}
\name{rs_data}
\alias{rs_data}
\title{Data from RiksSvikt (SwedeHF)}
\format{
A data frame with 500 rows and 3 variables:
\describe{
\item{id}{Patient id. Not unique. Integer.}
\item{indexdtm}{Index date. Combination id and date is unique. Date.}
\item{deathdtm}{Date of death or 2015-12-31 (censored). Date.}
}
}
\usage{
rs_data
}
\description{
rs_data aims to mimic data from SwedeHF (RiksSvikt),
used in the examples given in functions prep_sosdata, create_sosvar and create_deathvar.
}
\keyword{datasets}
