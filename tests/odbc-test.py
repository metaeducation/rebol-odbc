# Due to being open source and vetted by a number of people, Python's
# ODBC implementation makes a pretty good reference for comparison.
# This file is just a simple test, on Ubuntu you should say:
#
#     sudo apt install python-pip
#     pip install pyodbc
# 
# If something works in Python but not Rebol, then just build the
# pyodbc driver .so file as DEBUG, overwrite it in the lib directory,
# and then step through it in a debugger to see what the difference is.

import pyodbc

cnxn = pyodbc.connect("dsn=rebol-firebird")
crsr = cnxn.cursor()

crsr.execute("CREATE TABLE test_smallint_s (id INTEGER PRIMARY KEY NOT NULL, val SMALLINT NOT NULL )")
#crsr.execute("CREATE TABLE test_int (id INTEGER PRIMARY KEY NOT NULL, val INT NOT NULL);")
#crsr.execute("DROP TABLE test_int;")
