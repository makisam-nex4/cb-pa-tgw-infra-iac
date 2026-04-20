#!/bin/bash

# 1. Fetch Subnets (Needed to map Subnet IDs to Name tags)
echo "Fetching subnets..."
aws ec2 describe-subnets \
  --profile cb-pa \
  --region ap-southeast-1 \
  --output json > /tmp/subnets.json

# 2. Fetch Route Tables
echo "Fetching route tables..."
aws ec2 describe-route-tables \
  --profile cb-pa \
  --region ap-southeast-1 \
  --output json > /tmp/rtb.json

# 3. Process with jq and export to CSV
echo "Generating CSV..."
jq -r --slurpfile subnets /tmp/subnets.json '
  # Build a lookup dictionary of SubnetId -> Subnet Name Tag
  ($subnets[0].Subnets | map({
    (.SubnetId): (if .Tags then (.Tags[]? | select(.Key=="Name").Value) else "" end)
  }) | add) as $subnet_names |

  # Print the CSV Header row
  ["RouteTableName", "RouteTableId", "SubnetId", "SubnetName", "Destination", "NextHop"],

  # Iterate through all route tables
  (.RouteTables[] |
    . as $rt |
    # Get Route Table Name Tag
    (if .Tags then (.Tags[]? | select(.Key=="Name").Value) else "" end) as $rt_name |
    
    # Iterate through Subnet Associations (or create a blank one if none exist)
    (if (.Associations | length) > 0 then .Associations[] else {SubnetId: ""} end) |
    .SubnetId as $subnet_id |
    
    # Iterate through all routes in this route table
    $rt.Routes[]? |
    [
      $rt_name,
      $rt.RouteTableId,
      $subnet_id,
      ($subnet_names[$subnet_id] // ""),
      (.DestinationCidrBlock // .DestinationPrefixListId // .DestinationIpv6CidrBlock // ""),
      (.TransitGatewayId // .GatewayId // .NatGatewayId // .NetworkInterfaceId // .VpcEndpointId // .VpcPeeringConnectionId // .InstanceId // "local")
    ]
  ) | @csv
' /tmp/rtb.json > route-table-export.csv

echo "Success! Data exported to route-table-export.csv".