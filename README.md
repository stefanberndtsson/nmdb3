NoCrew Movie Database
=====================

Description
-----------

NMDb uses the openly available data files from IMDb, parsed into a PostgreSQL database
using my other project nmdb3-build.

This is a Rails 3.0 application.


Requirements
------------

The following gems are required (in the Gemfile, just run bundle install):

* pg
* nokogiri
* riddle
* redis
* wikipedia-client
* levenshtein-ffi
* unicode_utils
* will_paginate
* iso-639

Riddle is a Sphinxsearch client used for the searching part. The search index used is
setup by the build project. By default the Sphinx server is expected to be located on
the same server as the PostgreSQL database (the Sphinx hostname is taken from the
database.yml config).

Redis is used for caching data not coming from IMDb but fetched or created through other
means. It is **not** used for the user, user settings and movie data. This is stored in
the PostgreSQL database along with the processed IMDb data.

Wikipedia-client is used for fetching images, extra plot data, and some other things.



Installation
------------

You need to create a config/database.yml file. There is a database.yml.sample provided.
If you have an API-key for TheMovieDB.org, rename config/initializers/themoviedb_key.rb.sample and
fill it in there to use images from TMDB.

Redis needs to be installed on the server running the Rails application.
