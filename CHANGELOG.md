# Changelog for LeastPrivilegedMSGraph

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- PSFramework
- - Utilizing the logging functionality along with the runspaces.
- - This change will also provide results much faster and with the the fix implemented below it is still 2x faster with more data

### Fixed
- Interactive command reference with searchable documentation in GitHub Pages
- Issue with missing results from applicaiton with a lot of activity example an app with 19 mil requests would fail in the gathering of activity and just return 0 results. 
- - This is no longer the case the command has been updated to split the datetime range out

Huge thanks to @FriedrichWeinmann For his sparing and assistance on this implementation

[Unreleased]: https://github.com/YourUsername/Least_Privileged_MSGraph/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/YourUsername/Least_Privileged_MSGraph/releases/tag/v0.1.0
