# TacPoly FastCast2 fork

Release: **0.1.2-tacpoly.1**. Maintained at https://github.com/mojo3325/tacpoly-fastcast2.

This release starts from Wally `weenachuangkud/fastcast2@0.1.2`, upstream commit
`30b3bd100cff7352affef75374faf411ee99893c`. Every unmodified runtime file matches that
commit byte for byte. It imports the five existing TacPoly runtime corrections;
it does not upgrade to upstream 0.1.4.

- Serial event/visual queues belong to each caster, and termination clears registry data.
- Caster destruction retires active casts and releases cached objects.
- Explicit cache expansion keeps every new object available for checkout.
- Optional finite `EndAge` bounds serial simulation and high-fidelity queries at the
  exact age; terminal reasons distinguish Hit, Range and Other, without later callbacks.

`EndAge` is implemented by the serial simulation used by TacPoly. Parallel simulation
has no equivalent deadline extension and is not covered by the new regression check.

## Use and verification

Consume the tagged Git source snapshot and map `src` to a ModuleScript with Rojo.
The Git release is the distribution; this version is not published to the Wally registry.
`UPSTREAM.wally.toml` records the original package metadata.

In an isolated Roblox Studio Play session, load `tests/serial_regressions.luau` as a
ModuleScript and call its returned function with the synced FastCast2 ModuleScript.
The check covers two-caster isolation, cache lifecycle, exact deadlines at three frame
sizes and high-fidelity settings, and once-only hit/range termination. It returns a
PASS string only after every assertion completes. This is not a multiplayer or FPS benchmark.

## Notices

Upstream copyrights and source notices are retained. See `LICENSE-MIT`, and
`LICENSE-MPL-2.0` for the inherited FastCastParallel notice in `src/init.luau`.
The upstream documentation/art license remains in `LICENSE-CC-BY-NC-ND`; those assets
are not included in TacPoly's runtime snapshot. Modified MPL-covered source is available
in this repository under MPL 2.0; no upstream license notice is replaced.
