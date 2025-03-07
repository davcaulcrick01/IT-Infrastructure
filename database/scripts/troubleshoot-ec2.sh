#!/bin/bash
# EC2 Instance Connectivity Troubleshooter

if [ -z "$1" ]; then
  echo "Usage: $0 <instance-id>"
  exit 1
fi

INSTANCE_ID="$1"
echo "Troubleshooting instance $INSTANCE_ID..."

# Check if instance exists and is running
echo "Checking instance status..."
INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].State.Name" --output text 2>/dev/null)

if [ -z "$INSTANCE_STATE" ]; then
  echo "ERROR: Instance $INSTANCE_ID not found!"
  exit 1
fi

if [ "$INSTANCE_STATE" != "running" ]; then
  echo "ERROR: Instance $INSTANCE_ID is not running (current state: $INSTANCE_STATE)"
  echo "Wait for the instance to enter 'running' state or check AWS Console for issues"
  exit 1
fi

echo "✅ Instance is in 'running' state"

# Get subnet and VPC information
SUBNET_ID=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].SubnetId" --output text)

VPC_ID=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].VpcId" --output text)

echo "Subnet ID: $SUBNET_ID, VPC ID: $VPC_ID"

# Check public IP
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

if [ "$PUBLIC_IP" = "None" ] || [ -z "$PUBLIC_IP" ]; then
  echo "⚠️ WARNING: Instance has no public IP address!"
  echo "Check if 'associate_public_ip_address' is set to true in your terraform file"
  echo "Subnet might be private or auto-assign public IP is disabled"
else
  echo "✅ Public IP assigned: $PUBLIC_IP"
fi

# Check if subnet has route to Internet Gateway
echo "Checking if subnet has route to Internet Gateway..."

ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=$SUBNET_ID" \
  --query "RouteTables[0].RouteTableId" --output text)

if [ -z "$ROUTE_TABLE_ID" ] || [ "$ROUTE_TABLE_ID" = "None" ]; then
  echo "⚠️ No specific route table associated with this subnet."
  echo "Checking for main route table..."
  
  ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" \
    --query "RouteTables[0].RouteTableId" --output text)
fi

if [ -z "$ROUTE_TABLE_ID" ] || [ "$ROUTE_TABLE_ID" = "None" ]; then
  echo "❌ ERROR: Could not find route table for subnet $SUBNET_ID"
  exit 1
fi

echo "Route table: $ROUTE_TABLE_ID"

INTERNET_ROUTE=$(aws ec2 describe-route-tables --route-table-ids "$ROUTE_TABLE_ID" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
  --output text)

if [[ "$INTERNET_ROUTE" == igw-* ]]; then
  echo "✅ Subnet has route to Internet Gateway: $INTERNET_ROUTE"
else
  echo "❌ ERROR: Subnet does not have a route to an Internet Gateway!"
  echo "This is likely a private subnet. You need to use a public subnet or create NAT Gateway."
  exit 1
fi

# Check security group rules
echo "Checking security group rules..."
SECURITY_GROUPS=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].SecurityGroups[*].GroupId" --output text)

for SG_ID in $SECURITY_GROUPS; do
  echo "Security Group: $SG_ID"
  
  SSH_RULES=$(aws ec2 describe-security-groups --group-ids "$SG_ID" \
    --query "SecurityGroups[0].IpPermissions[?ToPort==\`22\`].IpRanges[*].CidrIp" \
    --output text)
  
  if [ -z "$SSH_RULES" ]; then
    echo "❌ ERROR: No inbound rules for SSH (port 22) found in security group $SG_ID"
  else
    echo "✅ SSH access is allowed from: $SSH_RULES"
  fi
done

# Suggest next steps
echo ""
echo "==== TROUBLESHOOTING SUMMARY ===="
echo ""
if [ "$INSTANCE_STATE" = "running" ] && [[ "$INTERNET_ROUTE" == igw-* ]] && [ -n "$PUBLIC_IP" ] && [ -n "$SSH_RULES" ]; then
  echo "✅ Basic connectivity requirements are met, but SSH is still failing."
  echo "Possible issues:"
  echo "1. Instance is still initializing (userdata script still running)"
  echo "2. SSH daemon is not running on the instance"
  echo "3. Firewall on the instance is blocking port 22"
  echo "4. Network ACLs might be blocking traffic"
  
  echo ""
  echo "Try connecting using a different method:"
  echo "1. Use EC2 Connect feature in AWS Console"
  echo "2. Use AWS Systems Manager Session Manager"
  echo "3. Stop and start the instance (not just reboot)"
else
  echo "❌ There are network configuration issues preventing SSH access."
  echo "Fix the issues identified above and try again."
fi

echo ""
echo "For manual SSH connection, try:"
echo "ssh -v -i your-key.pem ec2-user@$PUBLIC_IP" 