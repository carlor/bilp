// Written in the D programming language.

// bilp.config - processes config file
// Part of bilp, the Basic Internet LaunchPad
// Copyright (C) 2013 Nathan M. Swan
// Distributed under the GNU General Public License
// (See accompanying file ../../LICENSE)

module bilp.config;

import bilp.clip;
import bilp.rss;
import bilp.server;
import bilp.xml;

import core.exception;
import core.memory;

import std.algorithm;
import std.array;
import std.container;
import std.conv;
import std.file;
import std.parallelism;
import std.range;
import std.regex;
import std.string;
import std.utf;

import vibe.d;

class ConfigFile : XmlErrorHandler {
  private:
    public string fname;
    
    ServerSettings ss;
    Apdr layoutHTML;
    public Exception parsingException = null;
    XmlParser parser;

    LinkInfo[string] links;
    LinkInfo bufLink;

  public:
    this(string fname) {
        this.fname = fname;
    }

    ServerSettings loadServerSettings() {
        ss.http = new HTTPServerSettings();
        ss.http.port = 2926;
        ss.reloadInterval = 30.minutes;
        parse(true);
        return ss;
    }
    
    void loadItems() {
        parse(false);
    }

    string render() {
        auto apdr = new Apdr();
        foreach(i, f; appendFuncs) {
            f(apdr);
        }
        return apdr.result;
    }

    // -- utility functions --
    string download(string url) {
        string result;
        requestHTTP(url,
            delegate (scope HTTPClientRequest req) {},
            delegate (scope HTTPClientResponse res) {
                scope (exit) res.dropBody();
                auto sc = res.statusCode;
                if (sc != 200) {
                    throw new Exception("received status "~to!string(sc)~" from "~url~": "~res.statusPhrase);
                }
                result = readAllUTF8(res.bodyReader, true);
            });
        return result;
    }

  private:
    // -- basic parsing --
    void parse(bool serverSettings) {
        parser = new XmlParser();
        parser.setErrorHandler(this);
        parser.onStartElement(
            delegate void(Element elem) {
                receiveElem(elem, serverSettings);
            }
        );
        parser.parse(readText(fname));
    }

    void receiveElem(Element elem, bool serverOnly) {
        with (elem) switch (name) {
            case "bilp":
                if (parent !is null) err("<bilp> tag should be root element");
                expect(
                    "version", delegate(string v) {
                        if (v is null) {
                            warn("No version specified, assuming 0.1");
                        } else if (v != "0.1") {
                            warn("Hosting a v"~v~" site with bilp v0.1");
                        }
                    }
                );
                break;
                
            // -- server settings --
            case "server":
                if (!serverOnly) break;
                parentShouldBe("bilp");
                break;
            case "port":
                if (!serverOnly) break;
                parentShouldBe("server");
                onEnd = {
                    strip;
                    ss.http.port = to!ushort(content);
                };
                break;
            case "reload_interval":
                if (!serverOnly) break;
                parentShouldBe("server");
                auto ri = Duration.zero;
                expect(
                    "days", delegate(string d) {
                        if (d !is null)
                            ri += d.to!int().days();
                    },
                    "hours", delegate(string h) {
                        if (h !is null)
                            ri += h.to!int().hours();
                    },
                    "minutes", delegate(string m) {
                        if (m !is null)
                            ri += m.to!int().minutes();
                    },
                    "seconds", delegate(string s) {
                        if (s !is null)
                            ri += s.to!int().seconds();
                    });
                ss.reloadInterval = ri;
                break;
            case "no_http":
                if (!serverOnly) break;
                parentShouldBe("server");
                ss.serve = false;
                break;
            case "onreload":
                if (!serverOnly) break;
                parentShouldBe("server");
                onEnd = { ss.onreload = content; };
                break;
            
            // -- site ids --
            case "sites":
                parentShouldBe("bilp");
                if (serverOnly) break;
                break;
            case "link":
                parentShouldBe("sites");
                if (serverOnly) break;

                string id;
                bufLink = new LinkInfo(this);
                expect(
                    "id", delegate(string id_) {
                        if (bufLink is null) return;
                        if (id_ is null) {
                            warn("link must have id");
                            bufLink = null;
                        } else {
                            id = id_;
                        }
                    },
                    "url", delegate(string url_) {
                        if (bufLink is null) return;
                        if (url_ is null) {
                            warn("link must have url");
                            bufLink = null;
                        } else {
                            bufLink.url = url_;
                        }
                    },
                    "match", delegate(string match_) {
                        if (bufLink is null) return;
                        bufLink.match = match_;
                    }
                );
                if (bufLink is null) break;
                onEnd = {
                    strip;
                    bufLink.title = content;
                    links[id] = bufLink;
                    bufLink = null;
                };
                break;

            case "mdalg":
                parentShouldBe("link");
                if (serverOnly) break;

                string selector, algName;
                expect(
                    "for", delegate(string for_) {
                        if (for_ is null) {
                            warn("mdalg must have for");
                        }
                        selector = for_;
                    },
                    "alg", delegate(string alg_) {
                        if (alg_ is null) {
                            warn("mdalg must have alg");
                        }
                        algName = alg_;
                    }
                );
                if (selector is null || algName is null) break;

                bufLink.addMdAlg(selector, algName);

                break;
            
            // -- layout --
            case "layout":
                parentShouldBe("bilp");
                if (serverOnly) break;
                
                appendFuncs ~= delegate void (apdr) {
                    apdr.put(`
<!DOCTYPE html>
<html>
  <head>
    <title>Basic Internet LaunchPad</title>
    <style type="text/css">
      /*<![CDATA[*/`~
      import("bootstrap.min.css")~
      import("bilp.css")~`
      /*]]>*/
    </style>
    <script type="text/javascript">
      //<![CDATA[`
      ~import("bootstrap.min.js")~`
      //]]>
    </script>
  </head>
  <body>
    <div class="container">
`);
                };
                onEnd = {
                    appendFuncs ~= delegate void (apdr) {
                        apdr.err();
                        apdr.put(`
    </div>
  </body>
</html>
`);                 };
                };
                break;

            case "row":
                parentShouldBe("column", "layout");
                if (serverOnly) break;
                
                append(`<div class="row">`);
                onEnd = { append(`</div>`); };
                break;
            
            case "column":
                parentShouldBe("row", "layout");
                if (serverOnly) break;
                
                ubyte width = 1;
                expect(
                    "width", delegate (string strWidth) {
                        if (strWidth is null) {
                            warn("width not given, 1 assumed");
                        } else try {
                            width = strWidth.to!ubyte;
                        } catch (ConvException ce) {
                            warn(ce.msg);
                        }
                    }); 
                
                appendFuncs ~= delegate void (apdr) {
                    apdr.put(`<div class="span`);
                    apdr.put(to!string(width));
                    apdr.put(`">`);
                };
                
                onEnd = { append(`</div>`); };
                break;
            
            
                // program asynchronously, then separate into tasks
                // which performs better?
            case "blogs":
                parentShouldBe("row", "column");
                if (serverOnly) break;
                
                string ids;
                uint num = 3;
                expect(
                    "ids", delegate void (string ids_) {
                        if (ids_ is null) {
                            err("ids required for <blogs>");
                        }
                        ids = ids_;
                    },
                    "num", delegate void (string strNum) {
                        if (strNum !is null) {
                            num = to!uint(strNum);
                        }
                    });
                
                auto items = new LimitedHeap!RssItem(num);
                foreach(id; splitter(ids, ";")) {
                    id = id.strip;
                    if (auto l = id in links) {
                        try {
                            parseRssItems(l.url, this, &items.attemptInsert);
                        } catch (Exception e) {
                            warn("error parsing "~l.url~": "~e.toString);
                        }
                    } else {
                        warn("unknown id '"~id~"'");
                    }
                }
                
                appendFuncs ~= delegate void (apdr) {
                    apdr.put(`<div class="blogs">`);
                    foreach(item; items.contents.retro) {
                        apdr.put(`<div class="blog_item">`);
                        apdr.put(`<a class="blog_title" href="`);
                        apdr.put(item.link);
                        apdr.put(`">`);
                        apdr.put(item.title);
                        apdr.put(`</a>`);
                        apdr.put(`<p class="blog_description">`);
                        apdr.put(item.desc);
                        apdr.put(`</p>`);
                        apdr.put(`</div>`);
                    }
                    apdr.put(`</div>`);
                };
                break;
                
            case "clips":
                parentShouldBe("row", "column");
                if (serverOnly) break;

                string ids;
                uint num = 3;
                expect(
                    "ids", delegate void (string ids_) {
                        if (ids_ is null) {
                            err("ids required for <clips>");
                        }
                        ids = ids_;
                    },
                    "num", delegate void (string num_) {
                        if (num_ !is null) {
                            num = to!int(num_);
                        }
                    }
                );

                auto clips = new LimitedHeap!Clip(num);
                foreach(id; splitter(ids, ";")) {
                    id = id.strip;
                    if (auto l = id in links) {
                        try {
                            downloadClips(*l, 
                                          delegate void(Clip c) {
                                              clips.attemptInsert(c);
                                          });
                        } catch (Exception e) {
                            warn("error clipping from "~l.url~": "~e.toString);
                        }
                    } else {
                        warn("unknown id '"~id~"'");
                    }
                }

                appendFuncs ~= delegate void (apdr) {
                    apdr.put(`<div class="clips">`);
                    foreach(clip; clips.contents.retro) {
                        apdr.put(`<div class="clip">`);
                        apdr.put(`<a class="clip_title" href="`);
                        apdr.put(clip.url);
                        apdr.put(`">`);
                        apdr.put(clip.title);
                        apdr.put(`</a>`);
                        apdr.put(`<p class="clip_description">`);
                        apdr.put(clip.desc);
                        apdr.put(`</p>`);
                        apdr.put(`</div>`);
                    }
                    apdr.put(`</div>`);
                };

                break;
            
            case "handy_links":
                parentShouldBe("row", "column");
                if (serverOnly) break;

                string ids;
                expect(
                    "ids", delegate void (string ids_) {
                        if (ids_ is null) {
                            err("ids required for <blogs>");
                        }
                        ids = ids_;
                    }
                );

                onEnd = {
                    strip;
                    appendFuncs ~= delegate void (apdr) {
                        apdr.put(`<div class="well handy_links"><h3>`);
                        apdr.put(content);
                        apdr.put(`</h3><ul class="unstyled">`);
                        foreach(id; splitter(ids, ";")) {
                            id = id.strip;
                            if (auto l = id in links) {
                                apdr.put(`<li>`);
                                apdr.put(`<a href="`);
                                apdr.put(l.url);
                                apdr.put(`">`);
                                apdr.put(l.title == "" ? l.url : l.title);
                                apdr.put(`</a></li>`);
                            } else {
                                warn("unknown id '"~id~"'");
                                continue;
                            }
                        }
                        apdr.put(`</ul></div>`);
                    };
                };
                break;

            default:
                warn("unknown element '"~name~"'");
        }
    }

    // -- parsing helpers --
    alias AppendFunc = void delegate(Apdr);
    AppendFunc[] appendFuncs;
    
    void append(string str) {
        appendFuncs ~= delegate void (apdr) {
            apdr.put(str);
        };
    }
    
    class Apdr {
        string str;
        
        this() {
            str = "";
        }
        
        void put(dchar c) {
            put(toUTF8([c]));
        }
        
        void put(string s) {
            str ~= s;
        }
        
        void err() {
            bool errSep = parsingException !is null || warnings.length;
            if (errSep) put(`<div class="row">`);
            if (parsingException !is null) {
                if (auto bpe = cast(BilpParsingException)parsingException) {
                    warnings = bpe.warnings ~ warnings;
                }
                put(`<div class="alert alert-error">`);
                filterHTMLEscape(this, parsingException.msg);
                put(`</div>`);
            }
            foreach(wrn; warnings) {
                put(`<div class="alert">`);
                filterHTMLEscape(this, wrn);
                put(`</div>`);
            }
            if (errSep) put(`</div>`);
        }
        
        @property string result() {
            return str;
        }
    }

    // -- link functions --

    /+
    string getLinkUrl(string id) {
        if (auto p = id in links) {
            return p.url;
        } else {
            return null;
        }
    }

    string getLinkTitle(string id) {
        if (auto p = id in links) {
            return p.title;
        } else {
            return null;
        }
    }

    string getLinkMatch(string id) {
        if (auto p = id in links) {
            return p.match;
        } else {
            return null;
        }
    }
+/
  public:
    // -- error handlers --
    void err(string msg) {
        throw new BilpParsingException(msg, warnings);
    }
    
    string[] warnings;
    void warn(string msg) {
        logWarn("%s", msg);
        warnings ~= msg;
    }
}

class LinkInfo {
    static string[] mdSels = ["title", "description", "pubDate"];
    MdAlg[string] mdalgs;

    alias MdAlg = string delegate(string);

    ConfigFile cf;
    string url, title, match;

    this(ConfigFile cf) {
        this.cf = cf;
    }

    void addMdAlg(string selector, string alg) {
        if (selector == "default") {
            foreach(sel; mdSels) {
                if (sel !in mdalgs) {
                    createAlg(sel, alg);
                }
            }
        } else if (mdSels.canFind(selector)) {
            createAlg(selector, alg);
        } else {
            cf.warn("bad selector "~selector);
        }
    }

    void createAlg(string sel, string alg) {
        if (alg.startsWith("ogp")) {
            mdalgs[sel] = delegate string(string html) {
                // parse from ogp html
                foreach (captures; std.regex.match(html, ctRegex!(`<meta[^>]+property=["']og:(\S+)["'][^>]+content=("[^"]+"|'[^']+')`, `gi`))) {
                    if (sel == captures[1]) {
                        return fromEntity(captures[2][1..$-1]);
                    } else if (sel == "pubDate" && captures[1] == "article:published_time") {
                        return fromEntity(captures[2][1..$-1]);
                    }
                }
                return null;
            };
        } else if (alg.startsWith("search ")) {
            auto pattern = alg[7 .. $];
            size_t starLoc = countUntil(pattern, '*');
            if (starLoc == -1) {
                cf.warn("bad search pattern "~pattern);
            } else {
                string pre = pattern[0 .. starLoc];
                string post = pattern[starLoc+1 .. $];

                mdalgs[sel] = delegate string(string html) {
                    auto beg = countUntil(html, pre);
                    if (beg == -1) return null;
                    auto len = countUntil(html[beg .. $], post);
                    if (len == -1) return null;

                    return html[beg .. beg+len];
                };
            }
        } else {
            cf.warn("unknown alg "~splitter(alg, " ").front);
        }
    }
}

// Exception with warnings
class BilpParsingException : Exception {
    string[] warnings;
    this(string msg, string[] warnings, 
         string file=__FILE__, int line=__LINE__) {
        super(msg, file, line);
        this.warnings = warnings;
    }
}
