// Written in the D programming language.

// bilp.server - functionality for running server
// Part of bilp, the Basic Internet LaunchPad
// Copyright (C) 2013 Nathan M. Swan
// Distributed under the GNU General Public License
// (See accompanying file ../../LICENSE)

module bilp.server;

import bilp.config;

import core.sync.mutex;
import core.time;

import std.conv;
import std.datetime;
import std.file;

import vibe.d;


class BilpServer {
  private:
    ConfigFile config;
    ServerSettings settings;

    Mutex rhLock;
    string renderedHtml;
    
  public:
    this() {
        config = new ConfigFile(findConfigFile());
        settings = config.loadServerSettings();
        rhLock = new Mutex();
    }
    
    void start() {
        loadFile();

        auto router = new URLRouter();
        router.get("/", &showPage);
        listenHTTP(settings.http, router);

    }
  
  private:
    string findConfigFile() {
        
        string test(string delegate()[] files...) {
            foreach(f; files) {
                string evald = f();
                if (evald.exists) return evald;
            }
            return null;
        }
        
        immutable filename = "config_bilp.xml";

        string r = test("./" ~ filename, "~/" ~ filename, "/etc/config_bilp.xml");
        
        if (r is null) {
            throw new Exception("config file not found");
        }
        
        return r;
    }

    void loadFile() {
        logInfo("loadFile() start");
        StopWatch sw;
        sw.start();

        try {
            auto newConfig = new ConfigFile(config.fname);
            newConfig.loadItems();
            config = newConfig;
        } catch (Exception e) {
            logError("%s", e.toString);
            config.parsingException = e;
        }
        
        auto rh = config.render();
        synchronized (rhLock) {
            renderedHtml = rh;
        }
        
        sw.stop();
        logInfo("loadFile() done taking "~to!string(sw.peek().msecs)~"ms");
        setTimer(settings.reloadInterval, &loadFile);
    }
    
    void showPage(HTTPServerRequest req, HTTPServerResponse res) {
        logInfo("homepage accessed");

        string rh;
        synchronized (rhLock) {
            rh = renderedHtml;
        }
        res.writeBody(rh, "text/html");
    }
}

struct ServerSettings {
    HTTPServerSettings http;
    Duration reloadInterval;
}
