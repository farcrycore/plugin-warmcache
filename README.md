# Warm Cache plugin

This plugin provides tools for pre-loading data into Object Broker. This is
intended to reduce the performance hit of clearing Object Broker after large
updates (e.g. imports).

## Webtop tool

Admin > Developer Utilities > Cache Tools > Warm Cache

This tool allows a developer to trigger a warm from the UI, and also shows
example code for each content type.

## Running in code

To warm the cache from code, use the following command:

    application.fc.lib.warmcache.warmCache(id, type);

Currently only content object warming is supported, e.g.

    application.fc.lib.warmcache.warmCache("dmHTML", "contenttype")
