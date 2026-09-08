# Upstream provenance

Swizzle is a monorepo: every tweak is vendored as a plain directory. We do not
use submodules — our edits are Swizzle-specific build patches that are never
sent upstream.

To review what changed upstream, add the remote once and diff against the
recorded base commit:

These remotes are already configured (`git remote`). Refresh and compare:

```bash
git fetch --multiple up-bhinstagram up-bhtiktok up-bhtwitter up-tiktokpp up-scinsta
git log --oneline cd7be91..up-bhinstagram/main      # new upstream commits
git diff up-bhinstagram/main HEAD:BHInstagram        # upstream vs our copy
```

`git diff <tree-ish> <tree-ish>` works across remotes because everything shares
one object store. Replace the tree on the right for other tweaks.

| Tweak | Remote | Branch | Vendored at (base commit) |
|---|---|---|---|
| SCInsta | `up-scinsta` SoCuul/SCInsta | main | primary project, heavily modified |
| BHInstagram | `up-bhinstagram` BandarHL/BHInstagram | main | `cd7be9107881450426306bdc954a53bca97dd29a` |
| BHTikTok | `up-bhtiktok` BandarHL/BHTikTok | main | `18b4477ee29581aa99d0851776a58b008b78ede9` (= upstream HEAD) |
| TikTokPlusPlus | `up-tiktokpp` raulsaeed/BHTikTokPlusPlus | main | `af562bf9fc74185c299435b4af0a69ffe0d363f1` |
| BHTwitter | `up-bhtwitter` BandarHL/BHTwitter | **master** | `acd1b84` |
| BHLinkedin | scaffolded from BandarHL/BHTikTok | - | `2c0c815` |
| Hinge | scaffolded from BandarHL/BHTikTok | - | `2c0c815` |
| */libflex/FLEX | FLEXTool/FLEX | - | vendored per tweak; SCInsta at `079f2d8` |

## FLEX copies

Three genuinely different FLEX versions are in use (Hinge+BHLinkedin share one
byte-identical copy, BHTwitter and SCInsta each have their own). They are NOT
collapsed into a single shared copy: the versions have drifted and each tweak's
libflex wrapper builds against its own. Git stores the identical copies once.
