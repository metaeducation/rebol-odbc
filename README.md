## ODBC Extension

ODBC is an abstraction layer for communicating with databases, originating
from Microsoft in the 1990s but commonly available on Linux and other
platforms as well:

https://en.wikipedia.org/wiki/Open_Database_Connectivity

Integration with ODBC was a commercial feature of Rebol2/Command:

http://www.rebol.com/docs/database.html 

Though it was not included in R3-Alpha, Christian Ensel published code to
interface with "hostkit" to provide some of the functionality:

https://github.com/gurzgri/r3-odbc/

That code was taken as the starting point for developing an ODBC extension
against the modern "libRebol" API.

## Building

If you are using Windows, the ODBC headers are typically included by default
(e.g. in Visual Studio).

On Linux, you will need `unixodbc`, but specifically the development library.
The command on Debian to get these is:

    sudo apt install unixodbc-dev

On Mac, it seems HomeBrew will install the headers when you merely say:

    brew install unixodbc

## Notes

* ODBC Data Source Names (DSN) have a maximum length of 32 characters.  They
  can be ASCII characters except for spaces and [ ] { } , ; ? * = ! @ \

## License

The original code from which this extension is derived is Copyright (C)
Christian Ensel 2010-2012, and was under an "As Is" License.

Subsequent modifications are Copyright (C) 2012-2019 Rebol Open Source
Contributors, and the extension is licensed under the Apache2 License--the
same as the Rebol 3 Core.

## Future Directions

A big goal for the ODBC Extension is to make it completely use the libRebol
API, without needing to reach into the structure of cells via the %sys-core.h
header file.  As the API has become more flexible this process is ongoing.

Right now if you build a Rebol with the ODBC extension statically, then that
Rebol will require the ODBC shared libraries or DLLs to be present on the
target machine to run.  It would be nice if this could be decoupled such that
if ODBC was not present, it would still be able to run Rebol.
