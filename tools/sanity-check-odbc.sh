# These are important files to look at when debugging UnixODBC

echo "ODBC Driver Configuration =>"
odbcinst -q -d

echo "Dumping /etc/odbcinst.ini"
cat /etc/odbcinst.ini || echo "** not found **"

echo "ODBC Data Source Configuration =>"
odbcinst -q -s

echo "Dumping /etc/odbc.ini =>"
cat /etc/odbc.ini || echo "** not found **"

echo "Listing /usr/lib/x86_64-linux-gnu/odbc/"
ls /usr/lib/x86_64-linux-gnu/odbc/ || echo "** not found **"

echo "Listing /usr/local/lib"
ls /usr/local/lib/ || echo "** not found **"
