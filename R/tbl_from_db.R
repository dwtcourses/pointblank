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


# nocov start

#' Get a table from a database
#' 
#' @description If your target table is in a database, the `db_tbl()` function
#' is a handy way of accessing it. This function simplifies the process of
#' getting a `tbl_dbi` object, which usually involves a combination of building
#' a connection to a database and using the `dplyr::tbl()` function with the
#' connection and the table name (or a reference to a table in a schema). A
#' better option is to use this function as the `read_fn` parameter in
#' [create_agent()] or [create_informant()]. This can be done by using a
#' leading `~` before the `db_tbl()` call (e.g,. `read_fn = ~db_tbl(...)`).
#'
#' The username and password are supplied though environment variables. If
#' desired, these can be supplied directly by enclosing those values in `I()`.
#' 
#' @param table The name of the table, or, a reference to a table in a schema
#'   (two-element vector with the names of schema and table). Alternatively,
#'   this can be supplied as a data table to copy into an in-memory database
#'   connection. This only works if: (1) the `db` is either `"sqlite"` or
#'   `"duckdb"`, (2) the `dbname` was chosen as `":memory:"`, and (3) the
#'   `data_tbl` is a data frame or a tibble object.
#' @param dbname The database name.
#' @param dbtype Either an appropriate driver function (e.g.,
#'   `RPostgres::Postgres()`) or a shortname for the database type. Valid names
#'   are: `"postgresql"`, `"postgres"`, or `"pgsql"` (PostgreSQL, using the
#'   `RPostgres::Postgres()` driver function); `"mysql"` (MySQL, using
#'   `RMySQL::MySQL()`); `"maria"` or `"mariadb"` (MariaDB, using
#'   `RMariaDB::MariaDB()`); `"duckdb"` (DuckDB, using `duckdb::duckdb()`); and
#'   `"sqlite"` (SQLite, using `RSQLite::SQLite()`).
#' @param host,port The database host and optional port number.
#' @param user,password The environment variables used to access the username
#'   and password for the database.
#'   
#' @return A `tbl_dbi` object.
#' 
#' @examples 
#' # You can use an in-memory database
#' # table and supply an in-memory table
#' # to it too:
#' # small_table_duckdb <- 
#' #   db_tbl(
#' #     table = small_table,
#' #     dbname = ":memory:",
#' #     dbtype = "duckdb"
#' #   )
#'
#' # It's also possible to obtain a remote
#' # file and shove it into an in-memory
#' # database; use the all-powerful `file_tbl()`
#' # + `db_tbl()` combo
#' # all_revenue_large_duckdb <-
#' #   db_tbl(
#' #     table = file_tbl(
#' #       file = from_github(
#' #         file = "all_revenue_large.rds",
#' #         repo = "rich-iannone/intendo",
#' #         subdir = "data-large"
#' #       )
#' #     ),
#' #     dbname = ":memory:",
#' #     dbtype = "duckdb"
#' #   )
#' 
#' # For remote databases, it's just as
#' # simple (I think); you can get access
#' # to the `rna` table that's in the
#' # RNA Central public database with the
#' # following `db_tbl()` call
#' # rna_db_tbl <- 
#' #   db_tbl(
#' #     table = "rna",
#' #     dbname = "pfmegrnargs",
#' #     dbtype = "postgres", 
#' #     host = "hh-pgsql-public.ebi.ac.uk",
#' #     port = 5432,
#' #     user = I("reader"),
#' #     password = I("NWDMCE5xdipIjRrp")
#' #   )
#' 
#' # Using `I()` for the user name and
#' # password means that you're passing in
#' # the actual values but, normally, you
#' # would use names of environment variables
#' # (envvars) to access the username and
#' # password values when connecting to a
#' # database... like this:
#' # example_db_tbl <- 
#' #   db_tbl(
#' #     table = "<table_name>",
#' #     dbname = "<database_name>",
#' #     dbtype = "<database_type_shortname>", 
#' #     host = "<connection_url>",
#' #     port = "<connection_port>",
#' #     user = "<DB_USER_NAME>",
#' #     password = "<DB_PASSWORD>"
#' #   )
#'
#' # Environment variables can be created
#' # by editing the user `.Renviron` file and
#' # the `usethis::edit_r_environ()` function
#' # makes this pretty easy to do
#'
#' @family Planning and Prep
#' @section Function ID:
#' 1-6
#'
#' @export
db_tbl <- function(table,
                   dbname,
                   dbtype,
                   host = NULL,
                   port = NULL,
                   user = NULL,
                   password = NULL) {
  
  force(table)
  
  if (!requireNamespace("DBI", quietly = TRUE)) {
    stop("Accessing a database table requires the DBI package:\n",
         " * It can be installed with `install.packages(\"DBI\")`.",
         call. = FALSE)
  }
  
  if (is.character(dbtype)) {
    
    dbtype <- tolower(dbtype)
    
    # nolint start
    driver_function <- 
      switch(
        dbtype,
        postgresql = ,
        postgres = ,
        pgsql = RPostgres_driver(),
        mysql = RMySQL_driver(),
        maria = ,
        mariadb = RMariaDB_driver(),
        duckdb = DuckDB_driver(),
        sqlite = RSQLite_driver(),
        unknown_driver()
      )
    # nolint end
    
  } else {
    driver_function <- dbtype
  }

  # Create the DB connection object
  connection <-
    DBI::dbConnect(
      drv = driver_function,
      user = ifelse(inherits(user, "AsIs"), user, Sys.getenv(user)),
      password = ifelse(
        inherits(password, "AsIs"),
        password, Sys.getenv(password)
      ),
      host = host,
      dbname = dbname
    )
  
  # Insert data if is supplied, in the right format, and
  # if the DB connection is in-memory
  if (dbname == ":memory:" &&
      is.data.frame(table) && 
      tolower(dbtype) %in% c("duckdb", "sqlite")) {
    
    # Obtain the name of the data table
    if ("pb_tbl_name" %in% names(attributes(table))) {
      table_name <- table_stmt <- attr(table, "pb_tbl_name", exact = TRUE)
    } else {
      table_name <- table_stmt <- deparse(match.call()$table)[1]
    }
    
    # Copy the tabular data into the `connection` object
    dplyr::copy_to(
      dest = connection, 
      df = table,
      name = table_name,
      temporary = FALSE
    )
  }
  
  if (is.character(table)) {
    if (length(table) == 1) {
      table_stmt <- table
      table_name <- table
    } else if (length(table) == 2) {
      table_stmt <- dbplyr::in_schema(schema = table[1], table = table[2])
      table_name <- table[2]
    } else {
      stop("The length of `table` should be either 1 or 2.",
           call. = FALSE)
    }
  }
  
  access_time <- Sys.time()
  
  x <- dplyr::tbl(src = connection, table_stmt)
  
  con_desc <- dbplyr::db_connection_describe(con = connection)
  
  attr(x, "pb_tbl_name") <- table_name
  attr(x, "pb_con_desc") <- con_desc
  attr(x, "pb_access_time") <- access_time
  
  x
}

# nolint start

RPostgres_driver <- function() {
  
  if (!requireNamespace("RPostgres", quietly = TRUE)) {
    stop("Accessing a PostgreSQL table requires the RPostgres package:\n",
         " * It can be installed with `install.packages(\"RPostgres\")`.",
         call. = FALSE)
  }
  
  RPostgres::Postgres()
}

RMySQL_driver <- function() {
  
  if (!requireNamespace("RMySQL", quietly = TRUE)) {
    stop("Accessing a MariaDB or MySQL table requires the RMySQL package:\n",
         " * It can be installed with `install.packages(\"RMySQL\")`.",
         call. = FALSE)
  }
  
  RMySQL::MySQL()
}

RMariaDB_driver <- function() {
  
  if (!requireNamespace("RMariaDB", quietly = TRUE)) {
    stop("Accessing a MariaDB or MySQL table requires the RMariaDB package:\n",
         " * It can be installed with `install.packages(\"RMariaDB\")`.",
         call. = FALSE)
  }
  
  RMariaDB::MariaDB()
}

DuckDB_driver <- function() {
  
  if (!requireNamespace("duckdb", quietly = TRUE)) {
    stop("Accessing a DuckDB table requires the duckdb package:\n",
         " * It can be installed with `install.packages(\"duckdb\")`.",
         call. = FALSE)
  }
  
  duckdb::duckdb()
}

RSQLite_driver <- function() {
  
  if (!requireNamespace("RSQLite", quietly = TRUE)) {
    stop("Accessing a SQLite table requires the RSQLite package:\n",
         " * It can be installed with `install.packages(\"RSQLite\")`.",
         call. = FALSE)
  }
  
  RSQLite::SQLite()
}

# nolint end

unknown_driver <- function() {
    stop("The supplied value for `db` doesn't correspond to database type:\n",
         " * Acceptable values are: \"postgres\", \"mysql\", \"mariadb\", ",
         "\"sqlite\", and \"duckdb\".", 
         call. = FALSE)
}

# nocov end
