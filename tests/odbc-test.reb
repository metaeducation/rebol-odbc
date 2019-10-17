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
]

(dsn: match text! first system/script/args) else [
    fail "Data Source Name (DSN) must be text string on command line"
]

is-sqlite: did find dsn "sqlite"
is-mysql: did find dsn "mysql"

tables: compose [
    bit "BIT" [#[false] #[true]]

    tinyint_s "TINYINT" [-128 -10 0 10 127]
    tinyint_u "TINYINT UNSIGNED" [0 10 20 30 255]
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

    date "DATE" [12-Dec-2012 21-Apr-1975]

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

    nchar "NCHAR(3)" ["abc" "ταБ" "ghi"]
    nvarchar "NVARCHAR(10)" ["" "abc" "ταБЬℓσ" "٩(●̮̮̃•̃)۶"]

    binary "BINARY(3)" [#{000000} #{010203} #{FFFFFF}]
    varbinary "VARBINARY(10)" [#{} #{010203} #{DECAFBADCAFE}]
    blob "BLOB(10)" [#{} #{010203} #{DECAFBADCAFE}]
]

trap [
    print ["Opening DSN:" dsn]

    connection: open join odbc:// dsn
    statement: first connection

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
        insert statement {USE test}
    ]

    for-each [name sqltype content] tables [
        ;
        ; Drop table if it exists
        ;
        trap [
            insert statement unspaced [
                {DROP TABLE `test_} name {`}
            ]
        ]

        ; Create table, each one of which has a single field `value` as the
        ; primary key, of the named type.
        ;
        ; Note: SQLite auto-increments integer primary keys, and will complain
        ; if you say you want to increment it.
        ;
        let auto-increment: if is-sqlite [_] else ["AUTO_INCREMENT"]
        insert statement unspaced [
            {CREATE TABLE `test_} name {`} space {(}
                {id INTEGER PRIMARY KEY NOT NULL} space auto-increment {, }
                {`value`} space sqltype space {NOT NULL} space
            {)}
        ]

        print ["Inserting as" sqltype]
        print mold content

        ; Insert the values.  As a side effect, here we wind up testing the
        ; parameter code for each type.
        ;
        for-each value content [
            insert statement reduce [
                unspaced [{INSERT INTO `test_} name {` (`value`) VALUES ( ? )}]
                value
            ]
        ]

        ; Query the rows and make sure the values that come back are the same
        ;
        insert statement unspaced [
            {SELECT value FROM `test_} name {`}
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

quit 0  ; return code is heeded by Travis 
