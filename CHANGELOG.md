# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Remove custon sigil_U

## [1.0.0] - 2025-12-02

### Changed

- Fixed warnings for elixir 1.19
- Bump minimum versions to elixir 1.15 and otp 24
- Move canonical documentation to readme + updates
- No crash on nil datetime input

## [0.1.3] - 2021-02-26

### Added

- GitHub CI
- Changelog

### Changed

- Prevent compile time warning about timezone db in tests by using config
- Make tests run on elixir 1.8 by creating a custon sigil_U for it
- Updated ex_doc and make it `runtime: false` and `only: :dev`

### Removed

- Unlocked unused deps

## [0.1.2] - 2019-10-04

### Added

- Compile time warning when using the elixir default timezone db
- Add optional handling of incompatible calendars

### Changed

- Fixed incorrect hardcoded field name

## [0.1.1] - 2019-09-08

### Changed

- Fixed change and therefore error detection within the changeset handling

## [0.1.0] - 2019-09-08

### Added

- Initial release

[Unreleased]: https://github.com/madeitGmbH/tz_datetime/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/madeitGmbH/tz_datetime/compare/v0.1.3...v1.0.0
[0.1.3]: https://github.com/madeitGmbH/tz_datetime/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/madeitGmbH/tz_datetime/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/madeitGmbH/tz_datetime/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/madeitGmbH/tz_datetime/releases/tag/v0.1.0
