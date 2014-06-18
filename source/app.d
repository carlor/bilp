// Written in the D programming language.

// app - application starting point
// Part of bilp, the Basic Internet LaunchPad
// Copyright (C) 2013 Nathan M. Swan
// Distributed under the GNU General Public License
// (See accompanying file ../LICENSE)

import bilp.server;

shared static this() {
    auto server = new BilpServer();
    server.start();
    /+
    import vibe.core.args : finalizeCommandLineOptions;
    import vibe.core.core : runEventLoop, lowerPrivileges;
    import vibe.core.log;
    import std.encoding : sanitize;
    
    try if (!finalizeCommandLineOptions()) return 0;
   catch (Exception e) {
           logDiagnostic("Error processing command line: %s", e.msg);
           return 1;
   }

   lowerPrivileges();

   logDiagnostic("Running event loop...");
   int status;
   debug {
           status = runEventLoop();
   } else {
           try {
                   status = runEventLoop();
           } catch( Throwable th ){
                   logError("Unhandled exception in event loop: %s", th.msg);
                   logDiagnostic("Full exception: %s", th.toString().sanitize());
                   return 1;
           }
   }
   logDiagnostic("Event loop exited with status %d.", status);
   return status;+/
}
