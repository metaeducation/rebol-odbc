Rebol [
    Title: "ODBC Test Script"
    Description: {
        This script does some basic table creation, assuming you have
        configured an ODBC connection that has a "test" database inside it.
        Then it queries to make sure it can get the data back out.

        Due to variations in SQL implementations (as well as some variance
        in what you need to do to configure ODBC), it's very difficult to
        write a single generic "test script" does anything complex.  But
        this shows some coverage of fundamental ODBC operation; since it
        just passes through the query strings as-is, really this is most of
        what an interface has to handle.
    }
    Notes: {
        * Some databases (notably MySQL and SQLite) allow backticks when
          naming tables or columns, and use double-quotes to annotate string
          values.  This is not standard SQL, which conflates double quotes for
          string literals as the means for avoiding conflicts with reserved
          column names:

          https://stackoverflow.com/q/5952677

          But because MySQL will error if you put column or table names in
          double quotes--and databases like Firebird will error if you use
          backticks--there's no common way to use a reserved word as a column
          name.  That means not just columns with names like `INT`, but even
          useful-sounding names like `VALUE`.

          This file sticks to a lowest-common denominator of naming without
          quotes, rather than do conditional delimiting based on ODBC source.
    }
]

(dsn: match text! first system.script.args) else [
    fail "Data Source Name (DSN) must be text string on command line"
]

show-sql?: did find system.script.args "--show-sql"

is-sqlite: did find system.script.args "--sqlite"
is-mysql: did find system.script.args "--mysql"
is-firebird: did find system.script.args "--firebird"

tables: compose [
    ;
    ; Firebird added a logic type, but only in v3.0, and called it BOOLEAN
    ; not BIT (for some reason).  Prior to that it was expected to use `T`
    ; and `F` as CHAR(1).  It has no such type as TINYINT, either.
    ; https://firebirdsql.org/manual/migration-mssql-data-types.html
    ;
    ((if not is-firebird '[
        bit "BIT" [#[false] #[true]]
        tinyint_s "TINYINT" [-128 -10 0 10 127]
        tinyint_u "TINYINT UNSIGNED" [0 10 20 30 255]
    ]))

    smallint_s "SMALLINT" [-32768 -10 0 10 32767]
    smallint_u "SMALLINT UNSIGNED" [0 10 20 30 65535]
    integer_s "INT" [-2147483648 -10 0 10 2147483647]
    integer_u "INT UNSIGNED" [0 10 20 30 4294967295]
    bigint_s "BIGINT" [-9223372036854775808 -10 0 10 9223372036854775807]
    ;
    ; Note: though BIGINT unsigned storage in ODBC can store the full range of
    ; unsigned 64-bit values, Rebol's INTEGER! is always signed.  Hence it
    ; is limited to the signed range.  The plan to address this is to make
    ; INTEGER! arbitrary precision:
    ; https://forum.rebol.info/t/planning-ahead-for-bignum-arithmetic/623
    ;
    bigint_u "BIGINT UNSIGNED" [0 10 20 30 9223372036854775807]

    real "REAL" [-3.4 -1.2 0.0 5.6 7.8]
    double "DOUBLE" [-3.4 -1.2 0.0 5.6 7.8]
    float "FLOAT(20)" [-3.4 -1.2 0.0 5.6 7.8]
    numeric "NUMERIC(20,2)" [-3.4 -1.2 0.0 5.6 7.8]
    decimal "DECIMAL(3,2)" [-3.4 -1.2 0.0 5.6 7.8]

    date "DATE" [12-Dec-2012/0:00+0:00 21-Apr-1975/0:00+0:00]

    ; Fractional time is lost:
    ; https://github.com/metaeducation/rebol-odbc/issues/1
    ;
    time "TIME" [10:20 3:04]

    ; !!! There's no way to say "no time" in a timestamp.  So if you insert
    ; a date without a time, you'll get 00:00 back:
    ; https://github.com/metaeducation/rebol-odbc/issues/3
    ;
    ; !!! There's no generic mechanism for time zones...so it gets dropped.
    ; https://github.com/metaeducation/rebol-odbc/issues/2
    ;
    timestamp "TIMESTAMP" [30-May-2017/14:23:08 12-Dec-2012/00:00]

    char "CHAR(3)" ["abc" "def" "ghi"]
    varchar "VARCHAR(10)" ["" "abc" "defgh" "jklmnopqrs"]
    ((if not is-mysql '[
        longvarchar "LONGVARCHAR(255)" ["" "abc" "defgh" "jklmnopqrs"]
    ]))

    ; Firebird lacked NCHAR types and expects you to use the syntax of
    ; CHAR(x) CHARACTER SET UNICODE_FSS.  This was before 3.0 and so go ahead
    ; and test it as such.
    ; https://firebirdsql.org/manual/migration-mssql-data-types.html
    ;
    ((if not is-firebird '[
        nchar "NCHAR(3)" ["abc" "ταБ" "ghi"]
        nvarchar "NVARCHAR(10)" ["" "abc" "ταБЬℓσ" "٩(●̮̮̃•̃)۶"]
    ] else '[
        nchar "CHAR(3) CHARACTER SET UNICODE_FSS" ["abc" "ταБ" "ghi"]
        nvarchar "VARCHAR(10) CHARACTER SET UNICODE_FSS"
            ["" "abc" "ταБЬℓσ" "٩(●̮̮̃•̃)۶"]
    ]))

    binary "BINARY(3)" [#{000000} #{010203} #{FFFFFF}]
    varbinary "VARBINARY(10)" [#{} #{010203} #{DECAFBADCAFE}]
    blob "BLOB(10)" [#{} #{010203} #{DECAFBADCAFE}]
]

trap [
    odbc-set-char-encoding 'ucs-2

    print ["Opening DSN:" dsn]

    connection: open join odbc:// dsn
    statement: first connection

    sql-execute: specialize :odbc-execute [  ; https://forum.rebol.info/t/1234
        statement: statement
        verbose: if show-sql? [#]
    ]

    ; Despite the database being specified in the odbc.ini, it appears that
    ; MySQL requires you to name it again...either with a USE statement or
    ; by specifying test.<table-name> instead of just saying <table-name> on
    ; every mention below, otherwise you get "no database selected":
    ; https://stackoverflow.com/q/4005409/
    ;
    ; Note: initially the dots were what were done instead of this USE, but
    ; SQLite does not handle dots without difficulty:
    ; https://stackoverflow.com/q/5634501/
    ;
    if is-mysql [
        sql-execute {USE test}
    ]

    for-each [label sqltype content] tables [
        let table-name: unspaced [{test_} label]

        === DROP TABLE IF IT EXISTS ===

        trap [
            sql-execute [{DROP TABLE} table-name]
        ]

        === CREATE TABLE ===

        ; Each table has a single field `val` as the primary key, of the named
        ; type.  (It is "val" and not "value" to avoid being a SQL keyword.)
        ;
        ; SQLite auto-increments integer primary keys, and will complain
        ; if you say you want to increment it.  Firebird is...different:
        ; https://stackoverflow.com/a/34555507
        ;
        let auto-increment: case [
            is-sqlite [_]
            is-firebird ["GENERATED BY DEFAULT AS IDENTITY"]
            true ["AUTO_INCREMENT"]
        ]
        sql-execute [
            {CREATE TABLE} table-name {(}
                {id} {INTEGER} {PRIMARY KEY} {NOT NULL} auto-increment {,}
                {val} sqltype {NOT NULL}
            {)}
        ]

        ; If you wanted to see the table list you could dump it here.
        ;
        comment [
            insert statement ['tables]
            probe copy statement
        ]

        === INSERT VALUES SPECIFIED IN TEST ===

        ; Beyond just testing insertion, we also wind up testing the code
        ; which translates Rebol values into the column type for each test.
        ;
        print ["Inserting as" sqltype]
        print mold content
        for-each value content [
            sql-execute [
                {INSERT INTO} table-name {(val)} {VALUES} {(} ^value {)}
            ]
        ]

        === QUERY BACK THE INSERTED ROWS ===

        ; Make sure the values that come back are the same
        ;
        sql-execute [
            {SELECT val FROM} table-name
        ]

        rows: copy statement
        actual: copy []
        for-each row rows [
            assert [1 = length of row]
            append actual first row
        ]

        print ["=>" mold actual]

        either (sort copy actual) = (sort copy content) [
            print "QUERY MATCHED ORIGINAL DATA"
        ][
            print "QUERY DID NOT MATCH ORIGINAL DATA"
        ]

        print newline
    ]

    close statement
    close connection
]
then (func [e] [
    print ["Test had an error:" mold e]
    quit 1
])

quit 0  ; return code is heeded by test caller 
