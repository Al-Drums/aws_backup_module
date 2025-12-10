# 🎯 Solved Scenario
## 🔐 SCENARIO 2: Secure API Architecture


### 1. Weaknesses in the Current Architecture

- All APIs are public by design, even internal ones, which unnecessarily increases the attack surface.
- Lack of segmentation between public and private APIs, exposing internal services to the Internet unnecessarily.
- Sole reliance on WAF/Shield as a protection layer, without defense in depth at the regional or service level.
- Risk of direct attack on regional API Gateway endpoints if an attacker discovers the regional URL, bypassing CloudFront and the global WAF.
- Potential performance degradation for internal calls, which must go out to the Internet and back in through CloudFront → API Gateway.
- Centralized authorization management in a single Lambda Authorizer, which can become a bottleneck or single point of failure.
- Lack of granular visibility and control between internal and external traffic.

### 2. New Architecture to Separate Internal and Mixed APIs

Proposal for a segmented architecture:

1. **Public/Mixed APIs** (external and/or internal use):
   - Maintain current exposure: `api.allianz-trade.com` → CloudFront → WAF → Regional API Gateway → Backend.

2. **Internal APIs** (internal use only):
   - Move to API Gateway VPC Endpoints (Private API).
   - Create private APIs in API Gateway with a VPC Endpoint (`execute-api`).
   - Expose them to the internal network via AWS PrivateLink.
   - Internal calls are made within the VPC, without going out to the Internet.
   - They can continue using the same internal domain (e.g., `api-internal.allianz-trade.priv`) with Route 53 Resolver.

3. **Optimization of Internal Traffic to Mixed APIs:**
   - To prevent internal traffic from going over the Internet, configure Route 53 Resolver to redirect `api.allianz-trade.com` from the VPC to a closer CloudFront Regional Datacenter.
   - Another option: use API Gateway Private Integration for certain internal routes.

**Resulting Architecture:**

External → CloudFront → Public API Gateway → Backend
Internal → VPC Endpoint → Private API Gateway → Backend (Internal APIs)
Internal → Route53 Resolver → CloudFront (local edge) → Public API Gateway → Backend (Mixed APIs)


### 3. Configuring CloudFront for Path-Based Routing

Use Behaviors in CloudFront:

1. Create CloudFront distributions that point to the regional API Gateway as the origin.

2. Define multiple behaviors with different path patterns:

Path Pattern: /team1/* → Origin: api-gw-team1.execute-api.region.amazonaws.com
Path Pattern: /team2/* → Origin: api-gw-team2.execute-api.region.amazonaws.com
Path Pattern: /team3/* → Origin: api-gw-team3.execute-api.region.amazonaws.com
Default (*) → Main origin


3. Configure the origin in CloudFront as a Custom Origin with:
- Protocol: HTTPS
- Origin Domain: API Gateway endpoint
- Origin Path: (optional) for prefixes
- Headers: Enable Host header forwarding so API Gateway validates correctly.

4. Use Lambda@Edge if route transformation or more complex routing logic is needed.

### 4. Protecting Regional API Gateway Endpoints

To prevent direct traffic that bypasses CloudFront/WAF:

1. **Use API Gateway Resource Policy** to restrict access only from:
- The CloudFront distribution (CloudFront IP ranges).
- Internal networks/VPC (for controlled direct access).

Example policy:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": "*",
            "Action": "execute-api:Invoke",
            "Resource": "execute-api:/*",
            "Condition": {
                "IpAddress": {
                    "aws:SourceIp": ["CloudFront IP ranges", "Internal IPs"]
                }
            }
        }
    ]
}
```

Validation with custom headers:

Configure CloudFront to add a secret header (e.g., X-Origin-Verify).

In API Gateway, create a Lambda Authorizer or Request Validation that rejects requests without that header.

OAuth Scopes or API Keys:

Require an API Key for direct access (if necessary for some clients).

CloudFront can send the API Key automatically.

Additional regional WAF:

Associate AWS WAF also at the regional API Gateway level for defense in depth.

Custom Domains:

Use only Custom Domain Names in API Gateway and do not expose the execute-api... domain.

Configure CloudFront as the sole public entry point.

Final Recommendation:
Implement AWS Network Firewall or Security Groups at the VPC level to filter outgoing/internal traffic and ensure that only authorized services can connect to API Gateway from the internal network.

