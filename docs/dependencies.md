# Dependency licensing

Rook's original source is [MIT](../LICENSE). Dependencies keep their own
licenses; the project's license does not relicense them.

`cargo deny check` evaluates the complete resolved Rust graph, including
binding-generation tools, against explicit SPDX allowances. UniFFI's eight
existing MPL-2.0 packages have named exceptions, not a general allowance for
arbitrary new copyleft dependencies. Local path dependencies are allowed
without publishable version constraints because this workspace is unpublished.

## Important embedded and generated components

| Component | Resolved version | License / origin |
| --- | --- | --- |
| UniFFI | 0.32.2 | MPL-2.0; [upstream source](https://github.com/mozilla/uniffi-rs/tree/v0.32.2) |
| rusqlite / libsqlite3-sys | 0.40.2 / 0.38.2 | MIT wrappers; bundled database source has its own license |
| SQLCipher | Source shipped by libsqlite3-sys 0.38.2 | BSD-3-Clause, Zetetic; [upstream](https://github.com/sqlcipher/sqlcipher) |
| openssl-src | 300.6.1+3.6.3 | Wrapper MIT/Apache-2.0; bundled OpenSSL 3.6.3 Apache-2.0 |
| age | 0.12.1 | MIT/Apache-2.0; [upstream](https://github.com/str4d/rage) |

The SQLCipher license was checked in the bundled source, rather than inferred
from the MIT license of its Rust wrapper. The bundled OpenSSL license is
Apache-2.0. These licenses permit combination with Rook's MIT source, subject
to each dependency's obligations. MPL-2.0 is file-level: do not relabel UniFFI
source or modifications to MPL-covered files as MIT.

No vendor source or compiled Rust/Swift libraries is included in the initial
Git source inventory; Cargo fetches the pinned dependency versions.
Generated bindings are reproducible and ignored, not manually patched.

**Before distributing an app binary**, assemble and ship complete applicable
copyright, license, attribution, and source-availability notices for all
included dependencies, including SQLCipher, OpenSSL, and UniFFI. This document
is not a complete binary-distribution notices bundle or legal certification.
Maintain generated-code notices, review any MPL-covered modifications, and
make the corresponding upstream/versioned source available as required.

Build-only lint tools are not components shipped inside the iPhone app.
Documentation tooling is locked separately in `package-lock.json`; Rust
license/advisory checks do not assess those npm packages.

## Updates

Change dependencies through reviewed PRs with `Cargo.lock` updated. Run
`cargo deny check`, the declared Rust-minimum check, and native binding tests.
Do not copy another repository's ignored advisories or loosen license policy
just to make a failing check pass. Document a justified exception and its scope
before accepting one.
