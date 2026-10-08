#!/usr/bin/env bash
# Prints the separator between the AWS and gcloud segments. Always — with or
# without a session on either side, expired or not — so the split stays
# visible even while the gcloud segment is hidden (see gcloud_session.sh).
# No trailing space: gcloud_session.sh's own output already starts with one.
# The leading space lives here rather than in starship.toml's format string
# because starship renders a format string's static text even when $output
# is empty — but that no longer matters now that this never prints nothing.
printf ' │'
