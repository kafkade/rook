# Prototype privacy and recovery

Rook currently has no account, server, sync, analytics, or remote recovery
service. Local database encryption and portable backup encryption are separate
protections. This is not an independently audited implementation or a blanket
"zero knowledge" guarantee.

## Local storage

`rook-db` uses bundled SQLCipher with vendored OpenSSL, through `rusqlite`.
Opening requires a 32-byte raw key, verifies SQLCipher is present, and checks
the existing schema before performing migrations. It never falls back to
plaintext SQLite. Schema version 1 stores versioned model JSON inside encrypted
pages; these are not separate plaintext JSON files.

The iOS app generates the key using `SecRandomCopyBytes` and stores it as a
Keychain generic password with
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Normal use does not require a
master password. Existing data with a missing, invalid, or incorrect key must
fail visibly rather than be automatically reset.

The Application Support `Rook` directory uses complete file protection and is
excluded from ordinary iCloud Backup. SQLCipher uses a delete rollback journal,
full synchronization, and in-memory temporary storage. Keychain accessibility
and app file protection deliberately require the device to be unlocked.
Rest deadlines survive suspension; optional generic local notifications do not
need a background database read.

The app covers the root and private modals when inactive. Database access
closes in the background after attempting to save pending edits. Invalid
partial input cannot be treated as successfully saved.

## Portable backup format

Files use the `.rook.age` extension. They are binary **age passphrase-encrypted
files**, using the maintained `age` crate's scrypt passphrase support and
authenticated encryption, not a custom encryption protocol.

The decrypted UTF-8 JSON document has these top-level fields:

| Field | Contents |
| --- | --- |
| `version` | Integer `1` |
| `settings` | Units and local rest-alert preference |
| `routines` | Routine and exercise templates with stable UUIDs |
| `workouts` | Active and completed workout snapshots, sets, and timestamps |

The complete record schema is defined by the serde models in
`crates/rook-core/src/lib.rs`. Times are UTC milliseconds and weights are
canonical kilograms. Unknown fields and unsupported versions are rejected.
Archives are validated for record IDs, duplicates, counts, finite values,
timestamps, and at most one active workout. The device database key is never
part of the archive. An age-compatible passphrase decryption tool can recover
the JSON, but doing so creates plaintext outside Rook's protections.

Export requires at least 12 passphrase characters. Prefer multiple randomly
chosen words, store the passphrase separately from the file, and do not assume
the minimum length makes a predictable phrase strong.

Prototype limits: 64 MiB decrypted archive, 65 MiB encrypted input, and scrypt
restore work factor at most 20. Non-passphrase age files are unsupported.
Limits bound resource use; very large archives or age files using a higher work
factor require a later explicit format/resource-policy change.

## Restore and loss scenarios

Restore **replaces**, not merges, the local routines, settings, and workout
history. The user must confirm replacement. Keep a current backup before
restoring an older one.

An open engine decrypts and validates the archive before a transactional
replacement. Wrong passphrases, tampered ciphertext, invalid archives, and
unconfirmed replacements leave current records intact.

If the database cannot open, recovery builds and validates a fresh encrypted
temporary database before changing the destination or saving a new key. The
replacement uses the destination device's Keychain key; it does not require
the original device key. File/key/reopen errors are surfaced. File replacement
is atomic, but Keychain and filesystem updates are not a single cross-system
transaction; retain the portable backup until the recovered journal is open.

A lost device key cannot be recreated. A lost backup passphrase cannot be
reset. Without a readable device store or a decryptable portable backup,
there is no recovery mechanism. Ordinary iCloud device backup is intentionally
not the recovery path for this prototype.

## Boundaries and verification

Encryption protects stored contents, not every possible observation. File
names, sizes, export location, and notification presence can reveal metadata.
A compromised or unlocked device, user screenshots, and memory access are
outside the at-rest guarantee. Rust uses zeroizing buffers where practical;
guaranteed wiping of Swift strings/Data and all runtime copies is not claimed.
The user controls where encrypted exports are saved or shared.

Rust and Swift transport tests cover encrypted persistence, wrong keys,
workflow/relaunch, backup restore under a different key, wrong passphrases,
tampering, malformed archives, and rollback-journal confidentiality. Native
tests cover the workout loop, valid unfinished edit persistence, empty states,
and editor errors. Compilation is not physical-device lock or lifecycle
verification: those behaviors still need hardware testing, alongside
Keychain-loss recovery, VoiceOver, interruption/power-loss testing, and an
independent security assessment.

The repository bootstrap and private reporting endpoint are not yet verified.
Once enabled, use the repository's Security tab to report privately; do not
assume this channel is operational until confirmed. Do not put personal
workout data, keys, passphrases, or exploit details in public issues.

Prepared PR validation uses read-only tokens and no signing secrets. Dependency
advisory/license checks are not an independent security audit or comprehensive
source-level scan. Test artifacts contain isolated synthetic records only.
See `docs/ci.md` for runner, reporting, and validation boundaries.
