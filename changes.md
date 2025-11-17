# Architecture Delta Analysis: Microsoft Learn Article vs. Codebase

This document identifies differences between the updated Microsoft Learn article and the current implementation in the codebase.

## 1. Container Apps Environment - Zone Redundancy ✅ COMPLETED

**Current State:**
- ~~`environment.bicep` sets `zoneRedundant: false`~~ **FIXED:** Now set to `true`

**Article Requirement:**
- Article states: "Deploy all resources, including Container Apps, using a multi-zone topology" and "Set the minimum replica count for nontransient applications to at least one replica per availability zone"

**Changes Made:**
- ✅ Updated `environment.bicep` to set `zoneRedundant: true`
- ✅ Updated README quota section to specify "zone-redundant environment"
- ✅ Added note in README about region availability zone requirements

**Note:** Minimum replica count updates are tracked separately in item #3

---

## 2. Container Apps Environment - Custom Virtual Network

**Current State:**
- `environment.bicep` sets `vnetConfiguration: null` (using Microsoft-managed vnet)

**Article Requirement:**
- Article explicitly states: "The example uses an automatically generated virtual network, which should be improved by using a custom virtual network. It gives you more security control such as Network Security Groups and UDR-based routing through Azure Firewall"

**Recommended Change:**
- Add custom VNet deployment to `environment.bicep` or `workload-stamp.bicep`
- Configure `vnetConfiguration` with custom subnet
- Add Network Security Group (NSG) resources
- Document this as a recommended improvement in README

---

## 3. Container Apps - Minimum Replica Count

**Current State:**
- `container-http.bicep` sets `minReplicas: 1` and `maxReplicas: 1` for all services

**Article Requirement:**
- Article states: "Set the minimum replica count for nontransient applications to at least one replica per availability zone"
- With 3 availability zones, minimum should be 3 for zone-redundant deployments

**Recommended Change:**
- Update `container-http.bicep` scale configuration to support parameterized min/max replicas
- Set `minReplicas: 3` for zone-redundant services
- Allow `maxReplicas` to be configurable based on workload needs

---

## 4. Container Apps - Autoscaling Rules

**Current State:**
- `container-http.bicep` sets `rules: null` (no autoscaling configured)

**Article Requirement:**
- Article states: "Enable autoscaling rules to meet demand as traffic and workloads increase"
- Article mentions: "The default autoscaler is based on HTTP requests"

**Recommended Change:**
- Add HTTP-based autoscaling rules to `container-http.bicep`
- Make autoscaling rules configurable via parameters
- Document that workflow service could use Service Bus queue depth scaling

---

## 5. Container Apps - Health Probes

**Current State:**
- No health probes configured in `container-http.bicep`

**Article Requirement:**
- Article states: "Use health and readiness probes to handle slow-starting containers and avoid sending traffic before they're ready. The Kubernetes implementation already had these endpoints. Continue using them if they're effective signals"

**Recommended Change:**
- Add health probe configuration to `container-http.bicep` template
- Include startup, liveness, and readiness probes
- Make probe paths configurable via parameters

---

## 6. Container Apps - Resiliency Policies

**Current State:**
- No resiliency policies configured in container apps

**Article Requirement:**
- Article states: "Use resiliency policies to handle timeouts and introduce circuit breaker logic without needing to further adjust the code"

**Recommended Change:**
- Add service discovery resiliency policies to container apps that call downstream services (especially workflow service)
- Configure timeout and circuit breaker policies

---

## 7. Managed Identity - Separate Identity for ACR Pull

**Current State:**
- Each container app uses its own user-assigned managed identity for both ACR pull and workload operations (same identity)

**Article Requirement:**
- Article states: "Use one, dedicated, user-assigned, managed identity for Container Registry access. Container Apps supports the use of a different managed identity for workload operation than container registry access"

**Recommended Change:**
- Create a single shared user-assigned managed identity for ACR pull operations
- Keep separate user-assigned identities for each workload
- Update `container-http.bicep` to accept two identity parameters: one for ACR, one for workload
- Assign ACR pull rights to the shared identity only

---

## 8. Managed Identity - Use System-Assigned for Workloads

**Current State:**
- All services use user-assigned managed identities

**Article Requirement:**
- Article states: "Use system-assigned managed identities for workload identities, tying the identity lifecycle to the workload component lifecycle"

**Recommended Change:**
- Change container apps to use system-assigned managed identities for workload operations
- Retain user-assigned identity only for shared ACR access
- Update Key Vault role assignments to use system-assigned identity principal IDs (requires two-phase deployment)

---

## 9. Cosmos DB - Availability Zones

**Current State:**
- Cosmos DB accounts in `workload-stamp.bicep` have single location with `failoverPriority: 0`
- No explicit zone redundancy configuration

**Article Requirement:**
- Article states: "Deploy all resources, including Container Apps, using a multi-zone topology"

**Recommended Change:**
- Verify Cosmos DB accounts are deployed with availability zone support (enabled by default in most regions)
- Document that Cosmos DB Standard tier includes availability zone support
- Consider adding secondary region for geo-redundancy if needed

---

## 10. Azure Managed Redis - Naming and Service

**Current State:**
- Using `Microsoft.Cache/Redis` resources
- Named as "Azure Redis Cache"

**Article Requirement:**
- Article consistently refers to "Azure Managed Redis" (the updated branding)

**Recommended Change:**
- Update all references in bicep comments, tags, and documentation from "Redis Cache" to "Azure Managed Redis"
- No resource type change needed (Microsoft.Cache/Redis is correct)

---

## 11. Service Bus - Zone Redundancy

**Current State:**
- Service Bus Premium namespace deployed without explicit zone redundancy configuration

**Article Requirement:**
- Article implies all resources should be zone-redundant
- Service Bus Premium supports zone redundancy

**Recommended Change:**
- Add `zoneRedundant: true` property to Service Bus namespace in `workload-stamp.bicep`
- Verify Premium tier supports zone redundancy in target region

---

## 12. Ingress - WAF and DDoS Protection

**Current State:**
- Uses built-in external ingress for ingestion service
- No WAF or DDoS protection

**Article Requirement:**
- Article states: "Front all web-facing workloads with a web application firewall"
- Article optimization section: "you should disable the built-in public ingress and add Application Gateway or Azure Front Door"
- Article notes: "Gateways require meaningful health probes, which means the ingress service is effectively kept alive, preventing the ability to dynamically scale to zero"

**Recommended Change:**
- Document in README that current implementation uses built-in ingress (acceptable for brownfield migration)
- Add guidance on adding Application Gateway or Front Door as post-migration optimization
- Note the trade-off between WAF protection and scale-to-zero capability

---

## 13. Workflow Service - Job-Based Implementation

**Current State:**
- Workflow service deployed as a container app in single revision mode

**Article Requirement:**
- Article optimization states: "The workflow service is implemented as a long-running container app. But it can also run as a job in Container Apps"
- Article suggests: "migrating the service to run as an Container Apps job, based on work available in the queue, might be a reasonable approach to explore"

**Recommended Change:**
- Document current implementation uses container app (correct for brownfield)
- Add guidance in README about potential optimization to Container Apps jobs
- Note this as a future optimization requiring code evaluation

---

## 14. Container Registry - Naming Consistency

**Current State:**
- Bicep uses "Azure Container Registry" terminology
- Variable names use "acr" prefix

**Article Requirement:**
- Article consistently refers to "Container Registry" (official service name)

**Recommended Change:**
- Update bicep comments to use "Container Registry" instead of "ACR" or "Azure Container Registry"
- Keep variable names as `acr` (common abbreviation is fine)

---

## 15. Secrets Management - Hybrid Approach Documentation

**Current State:**
- Delivery and Drone Scheduler services use managed identity + Key Vault
- Other services (Ingestion, Package, Workflow) use Container Apps environment secrets

**Article Requirement:**
- Article explicitly acknowledges: "The workload uses a hybrid approach to managing secrets. Managed identities are used in the services where the change required no code modifications"
- Article optimization: "A better approach is to update all code to support managed identities, using the app or job identity instead of environment-provided secrets"

**Recommended Change:**
- Document in README that current hybrid approach is intentional for brownfield migration
- Note which services use managed identity (Delivery, DroneScheduler) vs environment secrets (Ingestion, Package, Workflow)
- Add optimization guidance to migrate remaining services to managed identity + Key Vault

---

## 16. Authentication - Easy Auth Not Implemented

**Current State:**
- Ingestion service handles its own authorization (in application code)

**Article Requirement:**
- Article optimization: "offload this responsibility to the built-in authentication and authorization feature, often referred to as 'Easy Auth'"

**Recommended Change:**
- Document in README that authorization is currently handled in application code
- Add guidance for post-migration optimization to use Container Apps Easy Auth
- Note this requires workload code changes

---

## 17. Workload Profiles

**Current State:**
- `environment.bicep` sets `workloadProfiles: null` (using consumption-only environment)

**Article Requirement:**
- Article states: "For containers that typically consume low CPU and memory amount, evaluate the consumption workload profile first"
- Article also mentions: "you could use a dedicated workload profile for components with highly predictable and stable usage"

**Recommended Change:**
- Current consumption-only setup aligns with article for brownfield migration
- Document in README the workload profile choice
- Add guidance on evaluating dedicated profiles for cost optimization

---

## 18. Defender for Containers - Limited Capability

**Current State:**
- No explicit Defender configuration in bicep

**Article Requirement:**
- Article states: "Defender for Containers in the architecture is limited to only performing vulnerability assessments of the containers in your Container Registry. Defender for Containers doesn't provide runtime protection for Container Apps"

**Recommended Change:**
- Add note to README about Defender for Containers limitations
- Document that only vulnerability assessment is available (not runtime protection)
- Mention evaluation of third-party security solutions if runtime protection is required

---

## 19. Container Apps - Separate Environments

**Current State:**
- Single Container Apps environment hosts all microservices

**Article Requirement:**
- Article states: "Don't run the workload in a shared Container Apps environment. Segment it from other workloads or components that don't need access to these microservices by creating separate Container Apps environments"

**Recommended Change:**
- Current single-environment approach is correct (all five microservices are part of same workload)
- Clarify in README that this environment should NOT be shared with other unrelated workloads
- Document that if organization has other applications, they should use separate environments

---

## 20. Deployment Approach - Container Apps Deployment

**Current State:**
- Container Apps are deployed via Bicep modules

**Article Requirement:**
- Article states: "Use infrastructure-as-code, such as Bicep or Terraform to manage all infrastructure deployments"
- Article also states: "Use an imperative approach to creating, updating, and removing container apps from the environment. It's especially important if you're dynamically adjusting traffic-shifting logic between revisions"
- Suggests using GitHub Actions or Azure Pipelines tasks

**Recommended Change:**
- Current declarative Bicep approach is acceptable for this reference implementation
- Add documentation in README about transitioning to imperative deployment for production scenarios
- Note the limitation that Bicep doesn't provide atomic "all succeed or all fail" deployment like Kubernetes manifests
- Suggest using GitHub Actions/Azure Pipelines for production deployments

---

## 21. Cosmos DB API Terminology

**Current State:**
- Bicep uses `kind: 'MongoDB'` for Package service Cosmos DB

**Article Requirement:**
- Article refers to "Azure Cosmos DB for MongoDB" API

**Recommended Change:**
- Update comments and documentation to use "Azure Cosmos DB for MongoDB" terminology
- Resource configuration is correct as-is

---

## Summary Statistics

**Total Deltas Identified:** 21

**Categories:**
- Reliability/Availability: 5 items (zone redundancy, replicas, health probes, resiliency, autoscaling)
- Security: 5 items (VNet, managed identity approach, ACR identity, WAF/DDoS, Easy Auth)
- Operations: 4 items (deployment approach, separate environments, Defender limitations, workload profiles)
- Optimizations: 4 items (workflow as job, managed identity for all services, Easy Auth, WAF/DDoS)
- Documentation/Naming: 3 items (Azure Managed Redis, Container Registry, Cosmos DB API)

**Priority Recommendations:**
1. **High Priority** - Enable zone redundancy and update replica counts (reliability foundation)
2. **High Priority** - Add custom VNet configuration (security requirement)
3. **Medium Priority** - Separate ACR pull identity from workload identities (security best practice)
4. **Medium Priority** - Add health probes and autoscaling rules (operational reliability)
5. **Low Priority** - Documentation updates for terminology consistency

**Note:** Many "optimizations" mentioned in the article are intentionally not implemented in the current codebase because this is a brownfield migration focused on minimal code changes. These should be documented as post-migration optimization opportunities rather than immediate changes.
