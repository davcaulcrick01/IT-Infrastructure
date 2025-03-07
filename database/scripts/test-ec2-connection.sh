#!/bin/bash
# Test EC2 connectivity using multiple methods

if [ -z "$1" ]; then
  echo "Usage: $0 <public-ip> [ssh-key-file]"
  exit 1
fi

PUBLIC_IP="$1"
KEY_FILE="$2"

echo "Testing connectivity to $PUBLIC_IP..."

# Test 1: Basic ping
echo "Test 1: Ping..."
ping -c 3 "$PUBLIC_IP"
PING_RESULT=$?

# Test 2: TCP connection test to SSH port
echo "Test 2: Testing TCP connection to SSH port..."
nc -zv -w 5 "$PUBLIC_IP" 22
NC_RESULT=$?

# Test 3: SSH connection
if [ -n "$KEY_FILE" ]; then
  echo "Test 3: Testing SSH connection..."
  ssh -v -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes -i "$KEY_FILE" ec2-user@"$PUBLIC_IP" echo "Success"
  SSH_RESULT=$?
else
  echo "No SSH key provided, skipping SSH test"
  SSH_RESULT=1
fi

echo ""
echo "===== TEST RESULTS ====="
[ $PING_RESULT -eq 0 ] && echo "✅ Ping successful" || echo "❌ Ping failed"
[ $NC_RESULT -eq 0 ] && echo "✅ TCP port 22 is open" || echo "❌ TCP port 22 is closed or blocked"
[ $SSH_RESULT -eq 0 ] && echo "✅ SSH connection successful" || echo "❌ SSH connection failed"

if [ $PING_RESULT -ne 0 ] && [ $NC_RESULT -ne 0 ]; then
  echo ""
  echo "DIAGNOSIS: The host is completely unreachable. Likely causes:"
  echo "1. Instance is not running"
  echo "2. Public IP is incorrect"
  echo "3. Instance is in a private subnet with no public connectivity"
  echo "4. Security group blocks all inbound traffic"
  echo "5. Network ACLs block all inbound traffic"
elif [ $PING_RESULT -ne 0 ] && [ $NC_RESULT -eq 0 ]; then
  echo ""
  echo "DIAGNOSIS: Instance is reachable on port 22 but doesn't respond to ICMP ping."
  echo "This is normal if ICMP is blocked but SSH is allowed."
elif [ $PING_RESULT -eq 0 ] && [ $NC_RESULT -ne 0 ]; then
  echo ""
  echo "DIAGNOSIS: Instance responds to ping but SSH port is closed or blocked."
  echo "Likely causes:"
  echo "1. SSH service is not running on the instance"
  echo "2. Security group doesn't allow port 22"
  echo "3. Instance firewall blocks port 22"
elif [ $SSH_RESULT -ne 0 ]; then
  echo ""
  echo "DIAGNOSIS: Can connect to port 22 but SSH authentication failed."
  echo "Likely causes:"
  echo "1. Wrong SSH key"
  echo "2. Wrong username (tried 'ec2-user')"
  echo "3. SSH service misconfiguration"
fi

echo ""
echo "AWS Console: https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#Instances:instanceId=$INSTANCE_ID" 