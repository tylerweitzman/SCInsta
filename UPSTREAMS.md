# Upstream provenance

Swizzle is a monorepo: every tweak is vendored as a plain directory. We do not
use submodules — our edits are Swizzle-specific build patches that are never
sent upstream.

To review what changed upstream, add the remote once and diff against the
recorded base commit:

```bash
git remote add up-bhinstagram https://github.com/BandarHL/BHInstagram
git fetch up-bhinstagram
git log --oneline cd7be91..up-bhinstagram/main      # new upstream commits
git diff up-bhinstagram/main HEAD:BHInstagram        # upstream vs our copy
```

`git diff <tree-ish> <tree-ish>` works across remotes because everything shares
one object store. Replace the tree on the right for other tweaks.

| Tweak | Upstream | Vendored at (base commit) |
|---|---|---|
| SCInsta | github.com/SoCuul/SCInsta | primary project, heavily modified |
| BHInstagram | github.com/BandarHL/BHInstagram | `cd7be9107881450426306bdc954a53bca97dd29a` |
| BHTikTok | github.com/BandarHL/BHTikTok | `18b4477ee29581aa99d0851776a58b008b78ede9` |
| TikTokPlusPlus | github.com/raulsaeed/BHTikTokPlusPlus | `af562bf9fc74185c299435b4af0a69ffe0d363f1` |
| BHTwitter | github.com/BandarHL/BHTwitter | `acd1b84` |
| BHLinkedin | scaffolded from BandarHL/BHTikTok | `2c0c815` |
| Hinge | scaffolded from BandarHL/BHTikTok | `2c0c815` |
| */libflex/FLEX | github.com/FLEXTool/FLEX | vendored per tweak; SCInsta at `079f2d8` |

## FLEX copies

Three genuinely different FLEX versions are in use (Hinge+BHLinkedin share one
byte-identical copy, BHTwitter and SCInsta each have their own). They are NOT
collapsed into a single shared copy: the versions have drifted and each tweak's
libflex wrapper builds against its own. Git stores the identical copies once.
