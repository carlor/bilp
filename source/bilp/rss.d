// Written in the D programming language.

// bilp.rss - parses rss files
// Part of bilp, the Basic Internet LaunchPad
// Copyright (C) 2013 Nathan M. Swan
// Distributed under the GNU General Public License
// (See accompanying file ../../LICENSE)

module bilp.rss;

import bilp.config;
import bilp.xml;

import std.algorithm;
import std.array;
import std.container;
import std.datetime;
import std.stdio;

import vibe.d;

public:
void parseRssItems(string url, ConfigFile cf, ItemHandler handler) {
    auto res = requestHTTP(url, delegate void(scope HTTPClientRequest req) {});
    scope (exit) res.dropBody();
    int sc = res.statusCode;
    if (sc != 200) {
        cf.warn("received http status "~to!string(sc)~" from "~url);
    } else {
        auto rdr = new RssReader(url, cf, handler);
        string buf = readAllUTF8(res.bodyReader, true);
        rdr.read(buf);
    }
}

alias ItemHandler = bool delegate(RssItem);

class RssItem {
    string title = "(no title)", link="", desc="(no description)";
    
    SysTime pubDate;
    
    int opCmp(ref const RssItem b) const {
        return pubDate.opCmp(b.pubDate);
    }
}

private:
class RssReader : XmlErrorHandler {
  private:
    string url;
    ConfigFile cf;
    ItemHandler itemHandler;
    XmlParser parser;
    
  public:
    this(string url, ConfigFile cf, ItemHandler handler) {
        logInfo("reading rss from %s", url);
        parser = new XmlParser();
        parser.onStartElement(&handleElem);
        this.url = url;
        this.cf = cf;
        this.itemHandler = handler;
        parser.setErrorHandler(this);
    }
    
    void read(string rssXml) {
        parser.parse(rssXml);
    }
    
  private:
    RssItem item = null;

    void handleElem(Element elem) {
        with (elem) {
            if (parent is null && name != "rss") {
                err("not an rss feed");
            }
            switch (name) {
                case "rss":
                    if (parent !is null) {
                        err("unexpected non-root <rss> element");
                    }
                    expect(
                        "version", (string v) {
                            if (v != "2.0") {
                                err("cannot parse rss v"~v~", only v2.0");
                            }
                        }
                    );
                    break;
                
                case "channel":
                    parentShouldBe("rss");
                    break;
                
                case "item":
                    parentShouldBe("channel");
                    item = new RssItem();
                    onEnd = {
                        if (!itemHandler(item)) {
                            parser.cancel();
                        }
                        item = null;
                    };
                    break;
                
                case "title":
                    if (parent.name == "item") {
                        onEnd = {
                            strip;
                            item.title = content;
                        };
                    }
                    break;
                    
                case "link":
                    if (parent.name == "item") {
                        onEnd = {
                            strip;
                            item.link = content;
                        };
                    }
                    break;
                    
                case "description":
                    if (parent.name == "item") {
                        onEnd = {
                            strip;
                            item.desc = content;
                        };
                    }
                    break;
                
                case "pubDate":
                    if (parent.name == "item") {
                        onEnd = {
                            item.pubDate = parseRFC822DateTimeString(content);
                        };
                    }
                    break;
                
                
                default: // plenty of other ignorable fields
            }
        }
    }
  protected:
    override void warn(string msg) {
        cf.warn(url~": "~msg);
    }
    
    override void err(string msg) {
        cf.warn("Error parsing "~url~": "~msg);
        parser.cancel();
    }
}

public class LimitedHeap(T) {
    T[] arr;
    size_t limit;
    
    this(size_t limit) {
        arr.reserve(limit);
        this.limit = limit;
    }
    
    bool attemptInsert(T e) {
        arr ~= e;
        sort(arr);
        if (arr.length > limit) {
            bool res = e != arr[0];
            arr = arr[1 .. $];
            return res;
        } else {
            return true;
        }
    }
    
    alias contents = arr;
}

unittest {
    auto lh = new LimitedHeap!int(4);
    bool[] res;
    foreach(n; [3, 5, 2, 6, 1, 4]) {
        res ~= lh.attemptInsert(n);
    }
    assert( lh.contents == [3, 4, 5, 6]);
    assert( res == [true, true, true, true, false, true]);
}
