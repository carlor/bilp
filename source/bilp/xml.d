// Written in the D programming language.

// bilp.xml - utility for easy XML parsing
// Part of bilp, the Basic Internet LaunchPad
// Copyright (C) 2013 Nathan M. Swan
// Distributed under the GNU General Public License
// (See accompanying file ../../LICENSE)

module bilp.xml;

import tango.text.xml.SaxParser;
import tango.text.xml.DocEntity;
import std.array;
import std.exception;
import std.string;
import std.stdio;

public:
import tango.text.xml.DocEntity : fromEntity;

alias kstr = const(char)[];
alias Attr = Attribute!char;


class XmlParser : SaxHandler!char, ErrorHandler!char {
  private:
    SaxParser!char sp;
    XmlErrorHandler errHandler;
    void delegate(Element) elHandler;
    Element elem = null;
    
  public:
    this() {
        sp = new SaxParser!char();
        sp.setErrorHandler(this);
        sp.setSaxHandler(this);
    }

    void setErrorHandler(XmlErrorHandler errHandler) {
        this.errHandler = errHandler;
    }
    
    void parse(string str) {
        try {
            sp.parse(str);
        } catch (Exception e) {
            errHandler.err(e.msg);
        }
    }
    
    void cancel() {
        sp.cancel();
    }
    
    void onStartElement(void delegate(Element) handler) {
        this.elHandler = handler;
    }
    
  override:
    // -- SaxHandler!char --
    void startElement(kstr uri, kstr lName, kstr qName, Attr[] attrs) {
        auto child = new Element(this);
        child.parent = elem;
        child.name = lName.idup;
        child.content = "";
        child.atts = attrs;
        foreach(ref att; child.atts) {
            att.value = fromEntity(att.value);
        }
        elem = child;

        try {
            elHandler(elem);
        } catch (Exception e) {
            errHandler.err(e.toString);
            cancel();
        }
    }
    
    void characters(kstr ch) {
        elem.content ~= fromEntity(ch).idup;
    }
    
    void ignorableWhitespace(char[] ch) {
        elem.content ~= ch.idup;
    }
    
    void endElement(kstr uri, kstr lName, kstr qName) {
        try {
            enforce(elem !is null, "element mismatch");
            elem.onEnd();
            elem = elem.parent;
        } catch (Exception e) {
            errHandler.err(e.toString);
            cancel();
        }
    }
        
    
    // -- ErrorHandler!char --
    void warning(SAXException e) {
        errHandler.warn(e.msg);
    }
    
    void error(SAXException e) {
        errHandler.err(e.msg);
    }
    
    void fatalError(SAXException e) {
        errHandler.err(e.msg);
    }

}

interface XmlErrorHandler {
    void warn(string msg);
    void err(string msg);
}

class Element {
    XmlParser parser;
    
    Element parent = null;
    
    string name;
    Attr[] atts;
    string content = null;
    
    void delegate() onEnd;
    
    this(XmlParser parser) {
        this.parser = parser;
        onEnd = {};
    }
    
    void strip() {
        content = std.string.strip(content);
    }

    override string toString() const {
        return format("<%s>%s</%s> <- %s",
                       name, content, name,
                       parent is null ? "null" : parent.toString());
    }

    void expect(T...)(string name, void delegate(string) rec, T tail) {
        static if (tail.length) {
            expect(name, rec);
            expect(tail);
        } else {
            foreach(attr; atts) {
                if (attr.localName == name) {
                    rec(attr.value.idup);
                    return;
                }
            }
            rec(null);
        }
    }
    
    void parentShouldBe(string[] names...) {
        if (parent is null) {
            parser.errHandler.err("unexpected root tag '"~name~"'");
            assert(0);
        }
        
        foreach(name; names) {
            if (parent.name == name) return;
        }
        // if none match...
        parser.errHandler.err("unexpected '"~name~"' in '"~parent.name~"'");
    }
    
    void writeParentage() {
        if (parent is null) {
            writefln("%s(root)", name);
        } else {
            writef("%s <- ", name);
        }
    }
}
