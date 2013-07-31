// Written in the D programming language.

// app - application starting point
// Part of bilp, the Basic Internet LaunchPad
// Copyright (C) 2013 Nathan M. Swan
// Distributed under the GNU General Public License
// (See accompanying file ../LICENSE)

import bilp.server;

BilpServer server;

static this() {
    server = new BilpServer();
    server.start();
}
