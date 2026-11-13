#!/usr/bin/env bash
# Usage: pub_version_exists.sh <package> <version>
#
# Prints "true" when <package> <version> is on pub.dev and "false" when
# pub.dev answers 404 for it. Any other outcome (network error, timeout, 5xx,
# rate limit) is retried, then fails the step, so publication state is never
# guessed: publishing an immutable version twice fails, and skipping one that
# is missing loses the release.
set -euo pipefail

package="$1"
version="$2"
url="${PUB_HOSTED_URL:-https://pub.dev}/api/packages/${package}/versions/${version}"
attempts="${PUB_LOOKUP_ATTEMPTS:-5}"
delay="${PUB_LOOKUP_DELAY:-10}"

for attempt in $(seq 1 "$attempts"); do
  status=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 30 "$url") || status="${status:-000}"
  case "$status" in
    200)
      echo true
      exit 0
      ;;
    404)
      echo false
      exit 0
      ;;
  esac
  echo "pub.dev lookup for $package $version returned $status (attempt $attempt/$attempts)" >&2
  if [ "$attempt" -lt "$attempts" ]; then
    sleep "$delay"
  fi
done

echo "::error::Could not determine whether $package $version is on pub.dev" >&2
exit 1
