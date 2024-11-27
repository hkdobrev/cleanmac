# cleanmac
Clean your macOS with a script, not an expensive app

## Overview
`cleanmac.sh` is a shell script designed to help you clean up unnecessary files on your macOS system. It removes cache files, logs, temporary files, and more, freeing up valuable disk space and improving system performance.

## Features
- Removes system and user cache files
- Cleans application logs
- Clears temporary files
- Empties Trash
- Cleans Safari caches
- Cleans XCode derived data and archives
- Cleans Node.js cache (npm, yarn)
- Cleans unused Docker images and containers
- Purges system memory cache
- Supports dry-run mode to preview changes

## Options
```shell
Usage: cleanmac.sh [OPTIONS] [DAYS]

Clean up unnecessary macOS files.

Options:
  -h, --help      Show this help message
  -d, --dry-run   Show what would be deleted without deleting

Arguments:
  DAYS            Number of days of cache to keep (default: 7)
```

## Installation
1. Clone the repository:
  ```shell
  git clone https://github.com/hkdobrev/cleanmac.git
  ```
2. Navigate to the script directory:
  ```shell
  cd cleanmac
  ```

## Usage
- Run the script with default settings (7 days):
  ```shell
  ./cleanmac.sh
  ```
- Run the script and keep cache files for the last 30 days:
  ```shell
  ./cleanmac.sh 30
  ```
- Perform a dry run to see what would be deleted:
  ```shell
  ./cleanmac.sh --dry-run
  ```

## Contributing
Contributions are welcome! Please open an issue or submit a pull request on GitHub.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
Clean your macOS with a script, not an expensive app
