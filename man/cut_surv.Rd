% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/cut_surv.R
\name{cut_surv}
\alias{cut_surv}
\title{Limit event and survival times to a time point}
\usage{
cut_surv(data, event, time, at, cuttime = TRUE, rename = NULL, censval = NULL)
}
\arguments{
\item{data}{Data.}

\item{event}{Event that should be cut.}

\item{time}{Time that should be cut. See also cuttime.}

\item{at}{At what time point should event/time be cut? In units of time.}

\item{cuttime}{Should time be cut? (can be needed for later evaluation). Default is TRUE.}

\item{rename}{Suffix if event and time should be renamed. Default is not to rename.}

\item{censval}{Value of censoring in variable event.
If not given the function will use 0 if event is numeric or "No" if event is character or factor if these exist in event.}
}
\value{
Data with cut event and time variable.
}
\description{
\ifelse{html}{\href{https://lifecycle.r-lib.org/articles/stages.html#experimental}{\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}}}{\strong{[Experimental]}}
}
\examples{
rs_data <- cut_surv(rs_data, out_death_fac, outtime_death, at = 365, rename = "1yr")
}
