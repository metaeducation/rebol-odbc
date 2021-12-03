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

        Use: r3 test-odbc.reb dsn --firebird --show-sql
    }
    Notes: {
      * This test supports Firebird even though it is non-standard, because
        prominent user @gchiu has used it for decades, including in the
        Synapse EHR product.  Here is a summary of its quirky mappings; we
        assume support for versions >= 3.0 only:

        https://firebirdsql.org/manual/migration-mssql-data-types.html

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
leave-connected?: did find system.script.args "--leave-connected"
list-tables?: did find system.script.args "--list-tables"

is-sqlite: did find system.script.args "--sqlite"
is-mysql: did find system.script.args "--mysql"
is-firebird: did find system.script.args "--firebird"

tables: compose [
    ;
    ; Note: Although MySQL supports BOOLEAN it is just a synonym for TINYINT(1)
    ; so it would give back 0 and 1, not false and true.  (Firebird has a
    ; distinct boolean type.)
    ;
    ((if is-firebird '[
        boolean "BOOLEAN" [#[false] #[true]]
    ]))

    ; The BIT type can be parameterized with how many bits to store, and can
    ; be more compact than a BOOLEAN.
    ;
    ; !!! Should this map to BITSET, if it can have a size, vs. LOGIC! ?
    ;
    ((if not is-firebird '[
        bit "BIT" [#[false] #[true]]
    ]))

    ((if not is-firebird '[  ; Firebird does not have TINYINT
        tinyint_s "TINYINT" [-128 -10 0 10 127]
        tinyint_u "TINYINT UNSIGNED" [0 10 20 30 255]
    ]))

    smallint_s "SMALLINT" [-32768 -10 0 10 32767]
    integer_s "INT" [-2147483648 -10 0 10 2147483647]
    bigint_s "BIGINT" [-9223372036854775808 -10 0 10 9223372036854775807]

    ((if not is-firebird '[  ; Firebird lacks unsigned types
        smallint_u "SMALLINT UNSIGNED" [0 10 20 30 65535]
        integer_u "INT UNSIGNED" [0 10 20 30 4294967295]

        ; Note: though BIGINT unsigned storage in ODBC stores the full range of
        ; unsigned 64-bit values, Rebol's INTEGER! is always signed.  Hence it
        ; is limited to the signed range.  The plan to address this is to make
        ; INTEGER! arbitrary precision:
        ;
        ; https://forum.rebol.info/t/planning-ahead-for-bignum-arithmetic/623
        ;
        bigint_u "BIGINT UNSIGNED" [0 10 20 30 9223372036854775807]
    ]))

    ((if is-firebird '[
        ;
        ; REAL and FLOAT(20) get these answers in Firebird back if you were
        ; to put in the rounded values.  It's not that interesting as to why at
        ; this particular time.
        ;
        real "REAL" [
            -3.4000000953674316
            -1.2000000476837158
            0.0
            5.599999904632568
            7.800000190734863
        ]
        float "FLOAT(20)" [
            -3.4000000953674316
            -1.2000000476837158
            0.0
            5.599999904632568
            7.800000190734863
        ]
    ] else '[
        real "REAL" [-3.4 -1.2 0.0 5.6 7.8]
        float "FLOAT(20)" [-3.4 -1.2 0.0 5.6 7.8]
    ]))

    ((if is-firebird '[  ; throws in word "precision"
        double "DOUBLE PRECISION" [-3.4 -1.2 0.0 5.6 7.8]
    ] else '[
        double "DOUBLE" [-3.4 -1.2 0.0 5.6 7.8]
    ]))

    ; Firebird has a maximum of 18 for NUMERIC, so NUMERIC(18,2) will work but
    ; NUMERIC(20,2) will not.
    ;
    numeric "NUMERIC(18,2)" [-3.4 -1.2 0.0 5.6 7.8]
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
    ((if is-sqlite '[
        ;
        ; LONGVARCHAR is considered a "legacy type", and not supported by most
        ; modern SQLs, but it is in Sqlite.
        ;
        longvarchar "LONGVARCHAR(255)" ["" "abc" "defgh" "jklmnopqrs"]
    ]))

    ; Firebird lacked NCHAR types and expects you to use the syntax of
    ; CHAR(x) CHARACTER SET UNICODE_FSS.  3.0 supports NCHAR but not NVARCHAR
    ; so you still need the weird syntax for VARCHAR, test it for CHAR as well.
    ;
    ((if not is-firebird '[
        nchar "NCHAR(3)" ["abc" "ταБ" "ghi"]
        nvarchar "NVARCHAR(10)" ["" "abc" "ταБЬℓσ" "٩(●̮̮̃•̃)۶"]
    ] else '[
        nchar "CHAR(3) CHARACTER SET UNICODE_FSS" ["abc" "ταБ" "ghi"]
        nvarchar "VARCHAR(10) CHARACTER SET UNICODE_FSS"
            ["" "abc" "ταБЬℓσ" "٩(●̮̮̃•̃)۶"]
    ]))

    ; Firebird has no BINARY column types.  But Firebird 4 will pretend you
    ; said CHAR or VARCHAR if you say BINARY or VARBINARY instead of raising an
    ; error.  This creates nonsense on the round trip, because the ODBC layer
    ; will perceive the column as a string.  Don't use BINARY in Firebird ODBC.
    ;
    ((if not is-firebird '[
        binary "BINARY(3)" [#{000000} #{010203} #{FFFFFF}]
        varbinary "VARBINARY(10)" [#{} #{010203} #{DECAFBADCAFE}]
    ]))

    ; Firebird appears to conflate empty blobs with nulls in the ODBC driver.
    ;
    ((if is-firebird '[
        blob "BLOB(10)" [#{010203} #{DECAFBADCAFE}]
    ] else '[
        blob "BLOB(10)" [#{} #{010203} #{DECAFBADCAFE}]
    ]))
]

mismatches: 0
total: 0

trap [
    odbc-set-char-encoding 'ucs-2

    print ["Opening DSN:" dsn]

    connection: open (any [is-sqlite is-firebird] then [
        join odbc:// dsn  ; no user or password for sqlite or firebird
    ] else [
        join odbc:// reduce [dsn ";UID=test;PWD=test-password"]
    ])

    statement: odbc-statement-of connection

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
        ; if you say you want to increment it.  Firebird is...different, and
        ; position matters (e.g. must be after INTEGER, not after NOT NULL):
        ; https://stackoverflow.com/a/34555507
        ;
        let auto-increment: case [
            is-sqlite [_]
            is-firebird ["GENERATED BY DEFAULT AS IDENTITY"]
            true ["AUTO_INCREMENT"]
        ]
        sql-execute [
            {CREATE TABLE} table-name {(}
                {id} {INTEGER} auto-increment {PRIMARY KEY} {NOT NULL} {,}
                {val} sqltype {NOT NULL}
            {)}
        ]

        === LIST TABLES IF REQUESTED ===

        if list-tables? [
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
            mismatches: me + 1
            print "QUERY DID NOT MATCH ORIGINAL DATA"
        ]

        total: total + 1

        print newline
    ]

    ; Being a GC-oriented language, we might have code paths that don't close
    ; connections and thus we only find out about leaked C entities when the
    ; GC is being shut down--after things like the ODBC extension are unloaded.
    ; There's special handling for this, that neutralizes the data pointed to
    ; by the HANDLE!s during ODBC extension shutdown.  We sometimes test that
    ; to make sure the system doesn't panic on exit if you omit the close.
    ;
    if leave-connected? [
        print "!!! --LEAVE-CONNECTED, ODBC CONNECTION LIVE DURING SHUTDOWN !!!"
    ]
    else [
        close statement
        close connection
    ]
]
then (func [e] [
    print ["Test had an error:" mold e]
    quit 1
])

if mismatches <> 0 [
    fail [mismatches "out of" total "tests did not match original data"]
]

quit 0  ; return code is heeded by test caller
