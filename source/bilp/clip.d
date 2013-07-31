// Written in the D programming language.

// bilp.clip - takes clips from news websites
// Part of bilp, the Basic Internet LaunchPad
// Copyright (C) 2013 Nathan M. Swan
// Distributed under the GNU General Public License
// (See accompanying file ../../LICENSE)

module bilp.clip;

import bilp.config;

import std.array;
import std.ascii;
import std.conv;
import std.datetime;
import std.regex;
import std.uni;

import vibe.d;

alias isDigit = std.ascii.isDigit; // dmd issue 1238 

alias ClipHandler = void delegate(Clip);
struct Clip {
    string url, title, desc;
    Date pubDate;

    int opCmp(const Clip c) const {
        return pubDate.opCmp(c.pubDate);
    }
}

void downloadClips(LinkInfo link, ClipHandler handler) {
    if (link.match is null) {
        link.cf.warn("link doesn't have match");
        return;
    }

    auto clipManager = new ClipManager(link, handler);
    clipManager.readClips();
}

class ClipManager {
    string homeURL;
    Regex!char pattern;
    ConfigFile cf;
    ClipHandler clipHandler;
    LinkInfo.MdAlg[string] mdalgs;

    this(LinkInfo link, ClipHandler handler) {
        logInfo("clipping from %s", link.url);
        this.homeURL = link.url;
        this.pattern = regex(link.match);
        this.cf = link.cf;
        this.clipHandler = handler;
        this.mdalgs = link.mdalgs;
    }

    void readClips() {
        string homeHTML = cf.download(homeURL);
        foreach(captures; match(homeHTML, ctRegex!(`<a\s+href=["'](\S+)["']`, `gi`))) {
            string url = captures[1];
            if (!match(url, pattern).empty) {
                try {
                    clipArticle(makeAbsolute(url));
                } catch (Exception e) {
                    cf.warn("error reading article "~url~": "~e.toString);
                }
            }
        }
    }

    void clipArticle(string articleURL) {
        logInfo("clipping article %s", articleURL);

        string html = cf.download(articleURL);

        string field(string sel, string def) {
            if (auto alg = sel in mdalgs) {
                auto result = (*alg)(html);
                if (result !is null) return result;
            }
            return def;
        }

        Clip clip;
        clip.title = field("title", "(Untitled)");
        clip.url = articleURL;
        clip.desc = field("description", "(no description)");
        clip.pubDate = field("pubDate", "0001-01-01").parseDate;
        clipHandler(clip);
    }

    string makeAbsolute(string url) {
        if (url.canFind("://")) {
            // absolute, don't change
            return url;
        } else if (url.startsWith("/")) {
            // relative to index
            auto r = URL(homeURL);
            r.localURI = url;
            return r.toString;
        } else {
            // relative to this page
            auto home = URL(homeURL);
            return (home.parentURL ~ Path(url)).toString;
        }
    }

   
}

Date parseDate(string dt) {
    Date r;
    auto dt_init = dt; // save for error messages
    auto cantParse = new DateTimeException("Can't parse date "~dt_init);
    size_t year_i = 0;
    // find year
    {
        size_t i = dt.map!isDigit().countUntil([true, true, true, true]);
        if (i == -1) {
            throw cantParse;
        }
        year_i = i;
        r.year = to!short(dt[i .. i + 4]);
        dt = dt[0 .. i] ~ dt[i+4 .. $];
    }
    
    // find month name
    bool foundMonth = false;
    {
        // method 1: names
        static string[] mnames = ["jan", "feb", "mar", "apr", "may",
                                  "jun", "jul", "aug", "sep", "nov", "dec"];
        auto nb = dt.toLower();
        foreach(n, mon; mnames) {
            size_t i = nb.indexOf(mon);
            if (i == -1) continue;
            r.month = cast(Month) cast(ubyte) (n+1);
            dt = dt[0 .. i] ~ dt[i+3 .. $];
            foundMonth = true;
            break;
        }
    }
    if (foundMonth) {
        // find day number
        size_t i = dt.map!isDigit().countUntil([true, true]);
        if (i == -1) {
            i = dt.map!isDigit().countUntil(true);
            if (i == -1) {
                throw cantParse;
            }
        }
        dt = dt[i .. $];
        r.day = parse!ubyte(dt);
    } else {
        // guess if ISO (YYYY-MM-DD), otherwise declare ambiguity
        size_t i = countUntil!isDigit(dt);
        if (i == -1) throw cantParse;
        if (i < year_i) {
            throw new DateTimeException(
                "Can't distinguish between MM/DD and DD/MM: "~dt_init);
        }

        auto m = dt.match(ctRegex!`(\d?\d).*(\d?\d)`);
        if (m.empty) throw cantParse;
        r.month = cast(Month) m.front[1].to!ubyte();
        r.day = m.front[2].to!ubyte();
    }
    return r;
}
