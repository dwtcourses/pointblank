#
#                _         _    _      _                _    
#               (_)       | |  | |    | |              | |   
#  _ __    ___   _  _ __  | |_ | |__  | |  __ _  _ __  | | __
# | '_ \  / _ \ | || '_ \ | __|| '_ \ | | / _` || '_ \ | |/ /
# | |_) || (_) || || | | || |_ | |_) || || (_| || | | ||   < 
# | .__/  \___/ |_||_| |_| \__||_.__/ |_| \__,_||_| |_||_|\_\
# | |                                                        
# |_|                                                        
# 
# This file is part of the 'rich-iannone/pointblank' package.
# 
# (c) Richard Iannone <riannone@me.com>
# 
# For full copyright and license information, please look at
# https://rich-iannone.github.io/pointblank/LICENSE.html
#


#' Given an *informant* object, update and incorporate table snippets
#' 
#' When the *informant* object has a number of snippets available (by using
#' [info_snippet()]) and the strings to use them (by using the `info_*()`
#' functions and `{<snippet_name>}` in the text elements), the process of
#' incorporating aspects of the table into the info text can occur by
#' using the `incorporate()` function. After that, the information will be fully
#' updated (getting the current state of table dimensions, re-rendering the
#' info text, etc.) and we can print the *informant* object or use the
#' [get_informant_report()] function to see the information report.
#' 
#' @param informant An informant object of class `ptblank_informant`.
#' 
#' @return A `ptblank_informant` object.
#' 
#' @examples 
#' if (interactive()) {
#' 
#' # Take the `small_table` and
#' # assign it to `test_table`; we'll
#' # modify it later
#' test_table <- small_table
#' 
#' # Generate an informant object, add
#' # two snippets with `info_snippet()`,
#' # add information with some other
#' # `info_*()` functions and then
#' # `incorporate()` the snippets into
#' # the info text
#' informant <- 
#'   create_informant(
#'     read_fn = ~ test_table,
#'     tbl_name = "test_table"
#'   ) %>%
#'   info_snippet(
#'     snippet_name = "row_count",
#'     fn = ~ . %>% nrow()
#'   ) %>%
#'   info_snippet(
#'     snippet_name = "col_count",
#'     fn = ~ . %>% ncol()
#'   ) %>%
#'   info_columns(
#'     columns = vars(a),
#'     info = "In the range of 1 to 10. (SIMPLE)"
#'   ) %>%
#'   info_columns(
#'     columns = starts_with("date"),
#'     info = "Time-based values (e.g., `Sys.time()`)."
#'   ) %>%
#'   info_columns(
#'     columns = "date",
#'     info = "The date part of `date_time`. (CALC)"
#'   ) %>%
#'   info_section(
#'     section_name = "rows",
#'     row_count = "There are {row_count} rows available."
#'   ) %>%
#'   incorporate()
#' 
#' # We can print the `informant` object
#' # to see the information report
#' 
#' # Let's modify `test_table` to give
#' # it more rows and an extra column
#' test_table <- 
#'   dplyr::bind_rows(test_table, test_table) %>%
#'   dplyr::mutate(h = a + c)
#' 
#' # Using `incorporate()` will cause
#' # the snippets to be reprocessed, and,
#' # the strings to be updated
#' informant <-
#'   informant %>% incorporate()
#'   
#' # When printed again, we'll see that the
#' # row and column counts in the header
#' # have been updated to reflect the
#' # changed `test_table`
#' 
#' }
#' 
#' @family Incorporate and Report
#' @section Function ID:
#' 7-1
#' 
#' @export
incorporate <- function(informant) {

  # Get the target table for this informant object
  # TODO: Use the same scheme that the `agent` does
  tbl <- informant$tbl
  tbl_name <- informant$tbl_name
  read_fn <- informant$read_fn
  
  # Extract the informant's `lang` and `locale` values
  lang <- informant$lang
  locale <- informant$locale
  
  # TODO: Verify that either `tbl` or `read_fn` is available
  
  # Prefer reading a table from a `read_fn` if it's available
  # TODO: Verify that the table is a table object
  # and provide an error if it isn't
  if (!is.null(read_fn)) {
    
    if (inherits(read_fn, "function")) {
      
      tbl <- rlang::exec(read_fn)
      
    } else if (rlang::is_formula(read_fn)) {
      
      tbl <- 
        read_fn %>% 
        rlang::f_rhs() %>% 
        rlang::eval_tidy(env = caller_env(n = 1))
      
      if (inherits(tbl, "read_fn")) {
        
        if (inherits(tbl, "with_tbl_name") && is.na(tbl_name)) {
          tbl_name <- tbl %>% rlang::f_lhs() %>% as.character()
        }
        
        tbl <-
          tbl %>%
          rlang::f_rhs() %>%
          rlang::eval_tidy(env = caller_env(n = 1))
      }
      
    } else {
      
      stop(
        "The `read_fn` object must be a function or an R formula.\n",
        "* A function can be made with `function()` {<table reading code>}.\n",
        "* An R formula can also be used, with the expression on the RHS.",
        call. = FALSE
      )
    }
  }
  
  # Update the following property values without user intervention
  #  - _columns
  #  - _rows
  #  - _type
  
  x <- create_agent(tbl = tbl, read_fn = read_fn)
  
  table.type <- x$tbl_src
  column_names <- x$col_names
  column_types_r <- x$col_types
  
  table.columns <- length(column_names)
  table.rows <- dplyr::count(tbl, name = "n") %>% dplyr::pull(n)
  
  # TODO: Sync column names, determining which are newly seen
  # and those that are no longer seen
  
  # TODO: Sync column types
  
  #
  # Incorporate snippets
  #
  
  meta_snippets <- informant$meta_snippets

  for (i in seq_along(meta_snippets)) {

    snippet_fn <- 
      informant$meta_snippets[[i]] %>%
      rlang::f_rhs()
    
    snippet_f_rhs_str <-
      informant$meta_snippets[[i]] %>%
      rlang::f_rhs() %>%
      as.character()

    if (any(grepl("pb_str_catalog", snippet_f_rhs_str)) &&
        any(grepl("lang = NULL", snippet_f_rhs_str)) &&
        lang != "en") {

      # We are inside this conditional because the snippet involves
      # the use of `pb_str_catalog()` and it requires a resetting
      # of the `lang` value (from `NULL` to the informant `lang`)
      
      select_call_idx <-
        which(grepl("select", snippet_f_rhs_str))
      
      pb_str_catalog_call_idx <-
        which(grepl("pb_str_catalog", snippet_f_rhs_str))
      
      snippet_f_rhs_str[pb_str_catalog_call_idx] <-
        gsub(
          "lang = NULL", paste0("lang = \"", lang, "\""),
          snippet_f_rhs_str[pb_str_catalog_call_idx]
        )
      
      # Put the snippet back together as a formula and
      # get only the RHS
      snippet_fn <-
        paste0(
          "~",
          snippet_f_rhs_str[select_call_idx],
          " %>% ",
          snippet_f_rhs_str[pb_str_catalog_call_idx]
        ) %>%
        stats::as.formula() %>%
        rlang::f_rhs()
    }
    
    snippet_fn <- snippet_fn %>% rlang::eval_tidy()
    
    if (inherits(snippet_fn, "fseq")) {
      
      snippet <- snippet_fn(tbl)
      
      # The following stmts always assume that numeric
      # values should be formatted with the default options
      # of `pb_fmt_number()` in the informant's locale
      if (is.numeric(snippet)) {
        
        if (is.integer(snippet)) {
          
          snippet <- 
            snippet %>%
            pb_fmt_number(locale = locale, decimals = 0)
          
        } else {
          
          snippet <- 
            snippet %>%
            pb_fmt_number(locale = locale)
        }
      }
      
      assign(x = names(informant$meta_snippets[i]), value = snippet)
    }
  }
  
  metadata_meta_label <- 
    glue_safely(
      informant$metadata[["info_label"]],
      .otherwise = "~SNIPPET MISSING~"
    )
  
  metadata_table <-
    lapply(informant$metadata[["table"]], function(x) {
      glue_safely(x, .otherwise = "~SNIPPET MISSING~")
    })
  
  metadata_columns <- 
    lapply(informant$metadata[["columns"]], lapply, function(x) {
      glue_safely(x, .otherwise = "~SNIPPET MISSING~")
    })
  
  extra_sections <- 
    base::setdiff(
      names(informant$metadata),
      c("info_label", "table", "columns")
    )
  
  metadata_extra <- informant$metadata[extra_sections]
  
  for (i in seq_along(extra_sections)) {
    for (j in seq_along(metadata_extra[[i]])) {
      
      metadata_extra[[i]][[j]] <-
        lapply(metadata_extra[[i]][[j]], function(x) {
          glue_safely(x, .otherwise = "(SNIPPET MISSING)")
        })
    }
  }
  
  metadata_rev <-
    c(
      list(info_label = metadata_meta_label),
      list(table = metadata_table),
      list(columns = metadata_columns),
      metadata_extra,
      list(updated = Sys.time())
    )
  
  # nolint start
  metadata_rev$table$`_columns` <- as.character(table.columns)
  metadata_rev$table$`_rows` <- as.character(table.rows)
  metadata_rev$table$`_type` <- table.type
  # nolint end
  
  informant$metadata_rev <- metadata_rev
  informant
}
