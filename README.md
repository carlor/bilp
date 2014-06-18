# bilp - Basic Internet LaunchPad #

`bilp` is a simple tool for creating an internet homepage with easy access to
your favorite blogs, links, and news sites.

It is available under the GNU General Public License.

## Usage ##
### 1. Build ###
If you have a binary, it should work out-of-the-box. Copy it to an accessible
location, and you're ready for step 2.

To compile from source, you need to install [dub](http://code.dlang.org/download).

Then just run:

    $ dub build

And the executable `bilp` will be generated. Copy it to an accessible location.

### 2. Setup ###
Create a file `config_bilp.xml` in your home directory. This will be used for
all configuration of `bilp`.

It will be an XML document like this example:

    <bilp version="0.1">
      <server>
        <port>3000</port>
        <reload_interval minutes="30" />
      </server>
      <sites>
        <link id="blog1" url="http://example.com/blog.rss" />
        <link id="blog2" url="http://example.com/dev_blog.rss" />
        <link id="news1" url="http://example.com/news" />
        <link id="handy1" url="http://example.com" />
      </sites>
      <layout>
        <row>
          <column width="6">
            <blogs ids="blog1;blog2" num="5" />
          </column>
          <column width="6">
          	<clips ids="news1" />
          	<handy_links ids="handy1">Links here:</handy_links>
          </column>
        </row>
      </layout>
    </bilp>

While the server is running, you can change the `sites` and `layout`, though to
change the `server` element you must restart the server.

Lets explain the elements:
    
- `port`: the TCP port at which the server will run.
- `reload_interval`: how often `bilp` will check the configuration file
  and update the blogs and clips.
- `link`: a unique id-url pairing
- `row`/`column`: these can be placed inside each other to create whichever
  layout you desire. The `width` attribute of the column is `1/12` of the
  screen, so `column`s in the same `row` should add up to `12`.
- `blogs`: excerpts the most recent entries from the specified RSS 2.0
  blogs. You can optionally specify how many entries with the `num`
  attribute.
- `clips`: clips articles from the specified news sites.
- `handy_links`: lists the links. Specify the heading for the list as the
  element content.
      
### 3. Running ###
Now, just run the `bilp` program, and you should be able to access your homepage
at `localhost:[port]`, with the port specified in your configuration file.

## License ##

    bilp, the Basic Internet LaunchPad
    Copyright (C) 2013 Nathan M. Swan

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
