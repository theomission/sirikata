cb = function(){ system.print("\n\n\nPrint Test\n\n")};

mPat = new system.Pattern("m","o");

handler = system.registerHandler(cb,null,mPat,null);

handler.printContents();

//should print a debugging message of some type.


