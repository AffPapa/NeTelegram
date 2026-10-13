# Website source

The OpenAI Site is a buildless, pre-rendered static website. Its editable route content and metadata live in `content/`; `build_site.py` renders every page through one shared semantic shell into `dist/`. Shared navigation, canonical/OG metadata, responsive menu and footer are edited once in that generator; page-specific prose stays in the matching content fragment.

Run `python3 build_site.py` followed by `python3 validate_site.py` to regenerate and check all eight routes. The validator checks route shell, one H1, active navigation, canonical metadata, local links and required assets. Output remains HTML/CSS with no JavaScript dependency.

`dist/` mirrors the current published development Site and contains no app downloads until a verified release exists. The Site uses its own OpenAI Sites project/source checkout and Git remote. Never change this application's Git `origin` to the Site helper remote; publish through the supported Sites workflow after synchronizing the exact source commit.
