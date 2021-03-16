Firebird's download for the ODBC driver is hosted on SourceForge (red flag
number one) but also says it has a corrupt archive and will not run
on Linux.

You can build Firebird's ODBC driver from source (and build as debug and
step into it).  But building it requires modification, as the Github repo
does not seem to be getting patches taken.

https://github.com/FirebirdSQL/firebird-odbc-driver/

Notes on building it can be found here in this thread about the
corrupted file:

https://bugs.documentfoundation.org/show_bug.cgi?id=67145

Some places suggest the DRIVER and the SETUP require distinct .so files,
but this does not appear to be the case in the current driver.  The same
file is used for both (hence why the ODBC driver is distributed as a
single file).

Firebird does not support backquote syntax for escaping like MySQL and
SQLite do.  At time of writing, the UnixODBC version of Firebird is not
working, but some investment was made into trying.

CREATE TABLE reference

https://firebirdsql.org/refdocs/langrefupd15-create-table.html

Datatype variations from MS SQL / MySQL etc.

https://firebirdsql.org/manual/migration-mssql-data-types.html
