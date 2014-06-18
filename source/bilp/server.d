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
import std.process;

import vibe.d;

version (OSX) {
    import core.sys.posix.unistd;
    extern(C) char*** _NSGetEnviron() nothrow;
}

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
        
        if (settings.serve) {
            auto router = new URLRouter();
            router.get("/", &showPage);
            listenHTTP(settings.http, router);
        }

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
        if (settings.serve) {
            synchronized (rhLock) {
                renderedHtml = rh;
            }
        }
        
        if (settings.onreload.length) {
            auto tempfile = tempDir ~ "/" ~ "bilp_render_tmp.html";
            write(tempfile, rh);
            
            version (OSX) {
                auto pid = fork();
                if (pid < 0) {
                    logError("unable to fork the shell");
                } else if (pid == 0) {
                    alias cstring = char*;
                    cstring* environ = *_NSGetEnviron();
                    
                    cstring[] envp;
                    while (environ !is null) {
                        envp ~= *environ;
                        environ++;
                    }
                    envp ~= ("BILP_RENDER="~tempfile~"\0").dup.ptr;
                    envp ~= null;
                    
                    auto r = execve("/bin/bash".ptr, ["/bin/bash".ptr, "-c".ptr, (settings.onreload~"\0").ptr, null].ptr, envp.ptr);
                    logError("unable to fork the shell");
                    _exit(r);
                }
            } else {
                auto proc = std.process.executeShell(settings.onreload, ["BILP_RENDER": tempfile]);
                logInfo("onreload done, status: %s, output: %s", proc.status, proc.output);
            }
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
    bool serve = true;
    string onreload;
}
