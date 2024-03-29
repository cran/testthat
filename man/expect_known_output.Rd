% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/expect-known.R
\name{expect_known_output}
\alias{expect_known_output}
\alias{expect_known_value}
\alias{expect_equal_to_reference}
\alias{expect_known_hash}
\title{Expectations: is the output or the value equal to a known good value?}
\usage{
expect_known_output(
  object,
  file,
  update = TRUE,
  ...,
  info = NULL,
  label = NULL,
  print = FALSE,
  width = 80
)

expect_known_value(
  object,
  file,
  update = TRUE,
  ...,
  info = NULL,
  label = NULL,
  version = 2
)

expect_known_hash(object, hash = NULL)
}
\arguments{
\item{file}{File path where known value/output will be stored.}

\item{update}{Should the file be updated? Defaults to \code{TRUE}, with
the expectation that you'll notice changes because of the first failure,
and then see the modified files in git.}

\item{...}{Passed on to \code{\link[waldo:compare]{waldo::compare()}}.}

\item{info}{Extra information to be included in the message. This argument
is soft-deprecated and should not be used in new code. Instead see
alternatives in \link{quasi_label}.}

\item{print}{If \code{TRUE} and the result of evaluating \code{code} is
visible, print the result using \code{testthat_print()}.}

\item{width}{Number of characters per line of output. This does not
inherit from \code{getOption("width")} so that tests always use the same
output width, minimising spurious differences.}

\item{version}{The serialization format version to use. The default, 2, was
the default format from R 1.4.0 to 3.5.3. Version 3 became the default from
R 3.6.0 and can only be read by R versions 3.5.0 and higher.}

\item{hash}{Known hash value. Leave empty and you'll be informed what
to use in the test output.}
}
\description{
For complex printed output and objects, it is often challenging to describe
exactly what you expect to see. \code{expect_known_value()} and
\code{expect_known_output()} provide a slightly weaker guarantee, simply
asserting that the values have not changed since the last time that you ran
them.
}
\details{
These expectations should be used in conjunction with git, as otherwise
there is no way to revert to previous values. Git is particularly useful
in conjunction with \code{expect_known_output()} as the diffs will show you
exactly what has changed.

Note that known values updates will only be updated when running tests
interactively. \verb{R CMD check} clones the package source so any changes to
the reference files will occur in a temporary directory, and will not be
synchronised back to the source package.
}
\section{3rd edition}{

\ifelse{html}{\href{https://lifecycle.r-lib.org/articles/stages.html#deprecated}{\figure{lifecycle-deprecated.svg}{options: alt='[Deprecated]'}}}{\strong{[Deprecated]}}

\code{expect_known_output()} and friends are deprecated in the 3rd edition;
please use \code{\link[=expect_snapshot_output]{expect_snapshot_output()}} and friends instead.
}

\examples{
tmp <- tempfile()

# The first run always succeeds
expect_known_output(mtcars[1:10, ], tmp, print = TRUE)

# Subsequent runs will succeed only if the file is unchanged
# This will succeed:
expect_known_output(mtcars[1:10, ], tmp, print = TRUE)

\dontrun{
# This will fail
expect_known_output(mtcars[1:9, ], tmp, print = TRUE)
}
}
\keyword{internal}
