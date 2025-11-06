## ODBC Extension

ODBC is an abstraction layer for communicating with databases, originating
from Microsoft in the 1990s but commonly available on Linux and other
platforms as well:

<https://en.wikipedia.org/wiki/Open_Database_Connectivity>

This extension provides ODBC interoperability with the **[Ren-C][1]** branch
of Rebol.  There's a basic translation of language value types into
corresponding SQL (e.g. INTEGER!, TEXT!, or the WORD! of `true` or `false`
to a BOOLEAN).

Best of all, it includes a higher-level **[ODBC Dialect](#the-odbc-dialect)**!

[1]: https://github.com/metaeducation/ren-c


## Parameterized Queries

The driver is made to handle what are called "parameterized queries".  These
use `?` at spots in the SQL where a literal value would go:

    ["select * from tables where (age = ?) and (name = ?)" 50 "Brian"]

Separating out the data helps defend against SQL injection attacks (as with
the infamous "Bobby Tables": <https://xkcd.com/327/>).

Perhaps obviously, you cannot use `?` in place of SQL keywords or operators:

  * `ORDER BY ?` (not allowed)
  * `LIMIT ?` (sometimes allowed for value, but not for identifiers)

You can only use `?` parameters in spots that substitute data values in
"Data Manipulation Language" (DML) statements:

  * `SELECT ... WHERE column = ?`
  * `INSERT INTO table (col) VALUES (?)`
  * `UPDATE table SET col = ? WHERE id = ?`

They can't be used anywhere a SQL identifier or structure is required,
especially in "Data Definition Language" (DDL) statements:

  * Table names: `SELECT * FROM ?`, `CREATE TABLE ? (...)` (not allowed)
  * Column names: `SELECT ? FROM table`, `CREATE TABLE t (? INT)` (not allowed)
  * Data types: `CREATE TABLE t (id ?)` (not allowed)
  * Constraint/index/schema names: `CREATE INDEX ? ON t (id)` (not allowed)


## The ODBC Dialect

Beyond passing queries as strings, you can also write your SQL as a BLOCK! of
words and other Rebol values.  WORD!s are formed as text, GROUP!s form out
their contents in parentheses, and it supports parameterized variable
substitutions using `$var` or `$(expression)` values.

For example: suppose you want to insert a new user into a database, and you
want to ensure the username is always stored in uppercase.  You can use both
simple variable substitution and an expression:

    user-id: 123
    user-name: "alice"
    user-email: "alice@example.com"

    odbc-execute [
        INSERT INTO users (id, name, email)
        VALUES ($user-id, $(uppercase of user-name), $user-email)
    ]

This produces a parameterized query for the driver:

    [
        "INSERT INTO users (id, name, email) VALUES (?, ?, ?)"
        123 "ALICE" "alice@example.com"
    ]

Though [as mentioned above](#parameterized-queries), there are many places
such substitutions won't work:

  table-name: 'audit_log
  odbc-execute [SELECT * FROM $table-name]

  ; ODBC Driver Manager: `?` syntax error or access violation

To handle cases where the driver does not support `?` substitution, the dialect
provides a `$[...]` splicing syntax.  The key safety feature is that `$[...]`
does not accept TEXT! strings, only transcoded values such as WORD!, BLOCK!,
or INTEGER!.

Example: splicing a table name safely (WORD!):

    table-name: 'audit_log
    odbc-execute [SELECT * FROM $[table-name]]

    ; => "SELECT * FROM audit_log"

Example: splicing a SQL fragment (BLOCK!):

    primary: if condition [[PRIMARY KEY]]
    odbc-execute [
        CREATE TABLE logs (
            id INTEGER AUTO_INCREMENT $[opt primary],
            message TEXT
        )
    ]

    ; => "CREATE TABLE logs (id INTEGER AUTO_INCREMENT PRIMARY KEY, ...)"
    ; or => "CREATE TABLE logs (id INTEGER AUTO_INCREMENT, ...)"

If you try to splice a TEXT!, the protection will block it.  For example:

    table-name: "DROP TABLE users"
    odbc-execute [SELECT * FROM $[table-name]]

    ; Error: TEXT! not allowed in $[...], use a WORD!, BLOCK!, or $[<!> ...]

But sometimes there are legitimate needs to splice a string that can't be
represented as a Ren-C value (for example, a type like `"NUMERIC(18,2)"`).
In these cases you can put a `<!>` TAG! as the first item in the `$[...]`
block as an explicit signal that you know what you're doing:

    weird-type: "NUMERIC(18,2)"  ; won't TRANSCODE due to lack of spacing
    odbc-execute [
        CREATE TABLE logs (
            amount $[<!> weird-type]  ; Warning: bypasses safety checks!
        )
    ]

    ; => "CREATE TABLE logs (amount NUMERIC(18,2))"

This dialect demonstrates the power of Ren-C's homoiconic, symbolic source --
where code and data share structure -- to enable robust and intuitive SQL
composition.  It's clear when when you are safely parameterizing values,
safely splicing identifiers or fragments, or intentionally bypassing safety
for advanced cases.

(For those interested in learning how Rebol dialecting works: there's not a
lot of code needed to implement this one, and it's relatively easy to follow.)


## Notes

* ODBC Data Source Names (DSN) have a maximum length of 32 characters.  They
  can be ASCII characters except for spaces and `[ ] { } , ; ? * = ! @ \`.
  DSN names are case-insensitive on Windows but may be case-sensitive on
  Unix-like systems.


## Building

If you are using Windows, the ODBC headers are typically included by default
(e.g. in Visual Studio).

On Linux, you will need `unixodbc`, but specifically the development library.
The command on Debian to get these is:

    sudo apt install unixodbc-dev

On macOS, typically you would use "Homebrew" to get it:

    brew install unixodbc


## License

This code was initially derived from an extension by Christian Ensel.  It was
Copyright (C) 2010-2012, under an "As Is" License.

<https://github.com/gurzgri/r3-odbc/>

Subsequent modifications are Copyright (C) 2012-2025 Rebol Open Source
Contributors, and the extension is licensed under the Lesser GPL 3.0

<https://www.gnu.org/licenses/lgpl-3.0.html>


## Future Directions

Right now if you build a Rebol with the ODBC extension statically but without
ODBC itself included statically, then that Rebol will require the ODBC shared
libraries or DLLs to be present on the target machine to run.

It would be nice if this could be decoupled such that if ODBC was not present,
it would still be able to run Rebol.  Otherwise executables either include
ODBC functionality statically and are big, or include it dynamically and won't
run without it.
