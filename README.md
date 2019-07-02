**The EveryPolitician project is currently on hold. See [this blog post](https://www.mysociety.org/2019/06/26/placing-everypolitician-on-hold/) for more information.**

# everypolitician-data

This is the data repo for EveryPolitician. It contains the data powering [EveryPolitician.org](http://everypolitician.org/), and other sites such as [Gender-Balance.org](http://www.gender-balance.org/).

## Want to use the data?

* [general information about how to _use_ the data](http://everypolitician.org/technical.html)
* if you want to download it, get it from:
  - human? go via the [EveryPolitician website](http://everypolitician.org)
  - program? use the RawGit CDN, via links in `countries.json`, which we [explain here](http://docs.everypolitician.org/repo_structure.html)
* [what's in the data?](http://docs.everypolitician.org/data_summary.html)

## Want to contribute data?

* [high-level information about how to contribute](http://everypolitician.org/contribute.html)

This repo is where we store the data, but we have a process for adding it — please don't
submit Pull Requests with data. Instead, if you know of data or data sources we are not
using, please get in touch: here's
[how to contribute](http://everypolitician.org/contribute.html). The bottom line is: we use
[multiple online sources](http://docs.everypolitician.org/sources.html), and we regularly
retrieve data from those sources so we can automatically keep up-to-date if and when they change.
If you can help us by providing more sources, great!

This document is for developers actively working _on_ the project, rather than consuming data from it.

## Building the data for a legislature

1. From within the directory for the legislature it should usually be enough to run `bundle exec rake clean default`.

    * To re-refetch the data from a given source first, set the REBUILD_SOURCE environment variable to something matching the filename of the required source: e.g. `REBUILD_SOURCE=official bundle exec rake clean default`

    * If you want to fetch fresh data from *all* existing sources, you can use `bundle exec rake clobber default` instead.

    * Note that if you're fetching any data from Morph, you'll also need to specify your [morph.io API key](https://morph.io/documentation/api) in the environment variable `MORPH_API_KEY`, e.g. `MORPH_API_KEY=my_secret_key bundle exec rake clean default`

2. Make sure that the changes look sensible, and then commit the new/refreshed data. Please commit human-edited files separately to data fetched from a remote source or generated as part of the build.
