% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/logging.R
\name{log4r_step}
\alias{log4r_step}
\title{Enable logging of failure conditions at the validation step level}
\usage{
log4r_step(x, message = NULL, append_to = "pb_log_file")
}
\arguments{
\item{x}{A reference to the x-list object prepared by the \code{agent}. This
version of the x-list is the same as that generated via
\verb{get_agent_x_list(<agent>, i = <step>)} except this version is internally
generated and hence only available in an internal evaluation context.}

\item{message}{The message to use for the log entry. When not provided, a
default glue string is used for the messaging. This is dynamic since the
internal \code{glue::glue()} call occurs in the same environment as \code{x}, the
x-list that's constrained to the validation step. The default message, used
when \code{message = NULL} is the glue string \code{"Step {x$i} exceeded the {level} failure threshold (f_failed = {x$f_failed}) ['{x$type}']"}. As can be seen,
a custom message can be crafted that uses other elements of the x-list with
the \verb{\{x$<component>\}} construction.}

\item{append_to}{The file to which log entries at the warn level are
appended. This can alternatively be one or more \strong{log4r} appenders.}
}
\description{
The \code{log4r_step()} function can be used as an action in the \code{\link[=action_levels]{action_levels()}}
function (as a list component for the \code{fns} list). Place a call to this
function in every failure condition that should produce a log (i.e., \code{warn},
\code{stop}, \code{notify}). Only the failure condition with the highest severity for a
given validation step will produce a log entry (skipping failure conditions
with lower severity) so long as the call to \code{log4r_step()} is present.
}
\section{Function ID}{

5-1
}

\concept{Logging}
