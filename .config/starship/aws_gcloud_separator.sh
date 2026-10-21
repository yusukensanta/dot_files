#!/usr/bin/env bash
# Prints the separator between the AWS and gcloud segments. Always, and
# independent of either segment's state (signed in, signed out, expired, or
# gcloud not configured) so the split never moves or disappears.
# No trailing space: gcloud_session.sh's own output already starts with one.
# The leading space lives here rather than in starship.toml's format string
# because starship renders a format string's static text even when $output
# is empty — but that no longer matters now that this never prints nothing.
printf ' │'
