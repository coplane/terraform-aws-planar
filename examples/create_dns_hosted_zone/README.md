# Delegated Planar DNS zone

This example creates a Route 53 hosted zone for a Planar tenant domain.

After applying it:

1. Read the `name_servers` output.
2. Add those name servers as NS records in the parent DNS zone.
3. Pass `hosted_zone_id` and the delegated domain to each Planar module instance.

The parent-zone delegation is intentionally outside this example because it is commonly managed in another AWS account or DNS provider.
