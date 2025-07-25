#' Registers a logger instance in a given logging namespace.
#'
#' @description `r lifecycle::badge("stable")`
#'
#' @note It's a thin wrapper around the `logger` package.
#'
#' @details Creates a new logging namespace specified by the `namespace` argument.
#' When the `layout` and `level` arguments are set to `NULL` (default), the function
#' gets the values for them from system variables or R options.
#' When deciding what to use (either argument, an R option or system variable), the function
#' picks the first non `NULL` value, checking in order:
#' 1. Function argument.
#' 2. System variable.
#' 3. R option.
#'
#' `layout` and `level` can be set as system environment variables, respectively:
#' * `teal.log_layout` as `TEAL.LOG_LAYOUT`,
#' * `teal.log_level` as `TEAL.LOG_LEVEL`.
#'
#' If neither the argument nor the environment variable is set the function uses the following R options:
#' * `options(teal.log_layout)`, which is passed to [logger::layout_glue_generator()],
#' * `options(teal.log_level)`, which is passed to [logger::log_threshold()]
#'
#'
#' The logs are output to `stdout` by default. Check `logger` for more information
#' about layouts and how to use `logger`.
#'
#' @seealso The package vignettes for more help: `browseVignettes("teal.logger")`.
#'
#' @param namespace (`character(1)` or `NA_character_`)\cr
#'  the name of the logging namespace
#' @param layout (`character(1)`)\cr
#'  the log layout. Alongside the standard logging variables provided by the `logging` package
#'  (e.g. `pid`) the `token` variable can be used which will write the last 8 characters of the
#'  shiny session token to the log.
#' @param level (`character(1)` or `call`) the log level. Can be passed as
#'   character or one of the `logger`'s objects.
#'   See [logger::log_threshold()] for more information.
#'
#' @return `invisible(NULL)`
#' @export
#'
#' @examples
#' options(teal.log_layout = "{msg}")
#' options(teal.log_level = "ERROR")
#' register_logger(namespace = "new_namespace")
#' \donttest{
#' logger::log_info("Hello from new_namespace", namespace = "new_namespace")
#' }
#'
register_logger <- function(namespace = NA_character_,
                            layout = NULL,
                            level = NULL) {
  if (!((is.character(namespace) && length(namespace) == 1) || is.na(namespace))) {
    stop("namespace argument to register_logger must be a single string or NA.")
  }

  if (is.null(level)) {
    level <- get_val("TEAL.LOG_LEVEL", "teal.log_level", "INFO")
  }

  tryCatch(
    logger::log_threshold(level, namespace = namespace),
    error = function(condition) {
      stop(paste(
        "The log level passed to logger::log_threshold was invalid.",
        "Make sure you pass or set the correct log level.",
        "See `logger::log_threshold` for more information"
      ))
    }
  )

  if (is.null(layout)) {
    layout <- get_val(
      "TEAL.LOG_LAYOUT",
      "teal.log_layout",
      "[{level}] {format(time, \"%Y-%m-%d %H:%M:%OS4\")} pid:{pid} token:[{token}] {ans} {msg}"
    )
  }

  tryCatch(
    expr = {
      logger::log_layout(layout_teal_glue_generator(layout), namespace = namespace)
      logger::log_appender(logger::appender_file(nullfile()), namespace = namespace)
      logger::log_success("Set up the logger", namespace = namespace)
      logger::log_appender(logger::appender_stdout, namespace = namespace)
    },
    error = function(condition) {
      stop(paste(
        "Error setting the layout of the logger.",
        "Make sure you pass or set the correct log layout.",
        "See `logger::layout` for more information."
      ))
    }
  )

  invisible(NULL)
}


#' Generate log layout function using common variables available via glue syntax including shiny session token
#'
#' @inheritParams register_logger
#' @return function taking `level` and `msg` arguments - keeping the original call creating the generator
#'   in the generator attribute that is returned when calling log_layout for the currently used layout
#' @details this function behaves in the same way as [logger::layout_glue_generator()]
#'   but allows the shiny session token (last 8 chars) to be included in the logging layout
#' @keywords internal
layout_teal_glue_generator <- function(layout) {
  force(layout)
  structure(
    function(level, msg, namespace = NA_character_, .logcall = sys.call(), .topcall = sys.call(-1),
             .topenv = parent.frame(), ...) {
      if (!inherits(level, "loglevel")) {
        stop("Invalid log level, see ?logger::log_levels")
      }
      with(logger::get_logger_meta_variables(
        log_level = level, namespace = namespace, .logcall = .logcall, .topcall = .topcall,
        .topenv = .topenv, ...
      ), {
        token <- substr(shiny::getDefaultReactiveDomain()$token, 25, 32)
        if (length(token) == 0) {
          token <- ""
        }
        glue::glue(layout)
      })
    },
    generator = deparse(match.call())
  )
}
