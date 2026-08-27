# Graph Report - AWS_Academy_Kiro-Workshop  (2026-08-26)

## Corpus Check
- 50 files · ~42,344 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 473 nodes · 613 edges · 36 communities (27 shown, 9 thin omitted)
- Extraction: 82% EXTRACTED · 18% INFERRED · 0% AMBIGUOUS · INFERRED: 108 edges (avg confidence: 0.92)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `0c766eee`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- jquery-3.6.0.min.js
- Security Defaults
- Graphify Skill
- package.json
- aws-architecture-diagram skill
- supplier.controller.js
- footer.html
- Application Analysis & AWS Architecture Recommendation
- mcp.json
- UserdataScript.sh
- Amazon DocumentDB Serverless
- FalkorDB Export
- SVG Export
- Wiki Export
- CLAUDE.md Integration
- Thai Language Communication
- Cost Estimation Patterns
- aws-architecture-diagram/SKILL.md
- AWS Group and Edge Style Templates
- deploy-kiro-lab.sh
- deploy-kiro-lab.ps1
- Kiro-LAB: EC2 Instance for Remote SSH Development
- Deployment Guide: Student Management Web Application
- Technology to Shape Mapping
- AWS Reference Architecture Style Guide
- Layout Guidelines
- XML Generation Rules
- XML Templates — Examples
- XML Templates — Core Structure
- draw.io CLI Export Reference
- Diagram Templates — Basic
- AWS4 Sub-Resource and Misc Shapes
- Diagram Templates — Advanced
- AWS4 Service Icon Shapes
- post-processing.md
- userdata-kiro-lab.sh

## God Nodes (most connected - your core abstractions)
1. `Graphify Skill` - 16 edges
2. `AWS Group and Edge Style Templates` - 13 edges
3. `Deployment Guide: Student Management Web Application` - 12 edges
4. `main()` - 11 edges
5. `AWS Reference Architecture Style Guide` - 11 edges
6. `Kiro-LAB: EC2 Instance for Remote SSH Development` - 11 edges
7. `Write-Info()` - 10 edges
8. `Main()` - 10 edges
9. `info()` - 10 edges
10. `se()` - 10 edges

## Surprising Connections (you probably didn't know these)
- `o()` --indirect_call--> `me()`  [INFERRED]
  src/public/js/bootstrap.min.js → src/public/js/jquery-3.6.0.min.js
- `Watch Mode` --conceptually_related_to--> `Incremental Update`  [INFERRED]
  .kiro/skills/graphify/references/add-watch.md → .kiro/skills/graphify/references/update.md
- `Post-Commit Hook` --conceptually_related_to--> `Incremental Update`  [INFERRED]
  .kiro/skills/graphify/references/hooks.md → .kiro/skills/graphify/references/update.md
- `Graphify Query Steering` --references--> `Graphify Skill`  [INFERRED]
  .kiro/steering/graphify.md → .kiro/skills/graphify/SKILL.md
- `b()` --indirect_call--> `i()`  [INFERRED]
  src/public/js/jquery-3.6.0.min.js → src/public/js/bootstrap.min.js

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Deploy Skill Security Stack** — _kiro_skills_deploy_references_security_encryption, _kiro_skills_deploy_references_security_vpc_placement, _kiro_skills_deploy_references_security_iam_least_privilege, _kiro_skills_deploy_references_security_security_groups, _kiro_skills_deploy_references_security_secrets_manager [EXTRACTED 1.00]
- **Graphify Pipeline Stages** — _kiro_skills_graphify_skill_ast_extraction, _kiro_skills_graphify_skill_semantic_extraction, _kiro_skills_graphify_skill_community_detection, _kiro_skills_graphify_skill_god_nodes, _kiro_skills_graphify_skill_graph_report [EXTRACTED 1.00]
- **Project Technology and Deployment Context** — _kiro_steering_tech_express, _kiro_steering_tech_nodejs, _kiro_steering_product_aurora_mysql, _kiro_steering_product_ec2_deployment, _kiro_steering_tech_aws_secrets_manager [INFERRED 0.85]
- **hyper_diagram_generation_workflow** — _kiro_skills_aws_architecture_diagram_skill_md, _kiro_skills_aws_architecture_diagram_references_xml_rules_md, _kiro_skills_aws_architecture_diagram_references_style_guide_md, _kiro_skills_aws_architecture_diagram_references_xml_templates_structure_md, _kiro_skills_aws_architecture_diagram_references_layout_guidelines_md, _kiro_skills_aws_architecture_diagram_references_post_processing_md [INFERRED]
- **shared_layout_partials** — src_views_header, src_views_footer, src_views_nav [INFERRED]
- **hyper_deploy_workflow** — _kiro_skills_deploy_skill_md, _kiro_skills_deploy_references_cost_estimation_md, concept_mcp_server, concept_infrastructure_as_code [INFERRED]
- **frontend_asset_stack** — bootstrap_css, bootstrap_js, jquery, base_css [INFERRED]
- **student_crud_views** — src_views_supplier_add, src_views_supplier_update, src_views_supplier_list_all, src_views_supplier_form_fields [INFERRED]

## Communities (36 total, 9 thin omitted)

### Community 0 - "jquery-3.6.0.min.js"
Cohesion: 0.07
Nodes (44): a(), c(), e(), i(), l(), n(), o(), r() (+36 more)

### Community 1 - "Security Defaults"
Cohesion: 0.05
Nodes (44): AWS Amplify Hosting, Aurora Serverless v2, CDK TypeScript Default IaC, Elastic Beanstalk Default, AWS Fargate, AWS Lambda, Service Defaults, Encryption at Rest (+36 more)

### Community 2 - "Graphify Skill"
Cohesion: 0.07
Nodes (29): Add URL to Corpus, Watch Mode, MCP Server Export, Neo4j Export, Confidence Scoring Rules, Extraction Subagent Spec, Node ID Format, Cross-Repo Graph Merge (+21 more)

### Community 3 - "package.json"
Cohesion: 0.08
Nodes (23): body-parser, cors, express, express-validator, mustache-express, mysql2, serve-favicon, author (+15 more)

### Community 4 - "aws-architecture-diagram skill"
Cohesion: 0.16
Nodes (21): AWS4 Sub-Resource Shapes Reference, AWS4 Service Icon Shapes Reference, draw.io CLI Export Reference, Diagram Templates Advanced, Diagram Templates Basic, General Architecture Icons Reference, AWS Group and Edge Style Templates, Layout Guidelines (+13 more)

### Community 5 - "supplier.controller.js"
Cohesion: 0.10
Nodes (12): config, {body, validationResult}, Supplier, dbConfig, mysql, app, bodyParser, cors (+4 more)

### Community 6 - "footer.html"
Cohesion: 0.20
Nodes (18): base.css, Bootstrap CSS, Bootstrap JS, jQuery 3.6.0, Mustache Partials, caps.jpeg, espresso.jpg, 404.html (+10 more)

### Community 7 - "Application Analysis & AWS Architecture Recommendation"
Cohesion: 0.09
Nodes (21): 1. Application Summary, 2. Recommended AWS Architecture, 3. Cost Estimate (Monthly, us-east-1, On-Demand), 4. Security Considerations, 5. Deployment Steps (Overview), 6. Deployment Issues & Fixes, 7. File Structure Reference, 8. Next Steps (+13 more)

### Community 8 - "mcp.json"
Cohesion: 0.43
Nodes (6): FASTMCP_LOG_LEVEL, aws-docs, awsiac, awsknowledge, awspricing, uvx

### Community 9 - "UserdataScript.sh"
Cohesion: 0.29
Nodes (6): APP_DB_HOST, APP_DB_NAME, APP_DB_PASSWORD, APP_DB_USER, APP_PORT, UserdataScript.sh script

### Community 16 - "Cost Estimation Patterns"
Cohesion: 0.10
Nodes (19): Amazon DocumentDB Serverless Pricing, Aurora Serverless v2 Pricing, Cost Estimation Patterns, Elastic Beanstalk Pricing, Fargate Pricing, Presenting Estimates, Quick Reference Estimates, Service Codes (+11 more)

### Community 17 - "aws-architecture-diagram/SKILL.md"
Cohesion: 0.11
Nodes (18): CRITICAL: XML Well-Formedness, Defaults, Diagram Types, Error Handling, File Naming, Important Rules, Key Principles, Layout Guidelines (+10 more)

### Community 18 - "AWS Group and Edge Style Templates"
Cohesion: 0.11
Nodes (17): Account, Auto Scaling Group, Availability Zone, AWS Cloud, AWS Group and Edge Style Templates, Bidirectional, Dashed (async/optional), Edge Styles (+9 more)

### Community 19 - "deploy-kiro-lab.sh"
Cohesion: 0.38
Nodes (16): check_prerequisites(), configure_ssh(), create_security_group(), error(), find_ssh_key(), get_instance_dns(), get_ubuntu_ami(), info() (+8 more)

### Community 20 - "deploy-kiro-lab.ps1"
Cohesion: 0.42
Nodes (15): Find-SSHKey(), Get-InstanceDNS(), Get-UbuntuAMI(), Install-AWSCLI(), New-SecurityGroup(), Get-Userdata(), Main(), Set-SSHConfig() (+7 more)

### Community 21 - "Kiro-LAB: EC2 Instance for Remote SSH Development"
Cohesion: 0.14
Nodes (13): Cleanup, Dev Tools ที่ติดตั้งให้, EC2 Instance Specs, Kiro-LAB: EC2 Instance for Remote SSH Development, macOS / Linux, MCP Server (pre-configured), Script ทำอะไรบ้าง, Windows (PowerShell) (+5 more)

### Community 22 - "Deployment Guide: Student Management Web Application"
Cohesion: 0.15
Nodes (12): Cost Estimate (Monthly, us-east-1), Deployment Guide: Student Management Web Application, File Structure, Phase 0: Upload Application Code to S3, Phase 1: Networking, Phase 2: Database (Aurora MySQL), Phase 3: Secrets Manager, Phase 4: Application Server (EC2) (+4 more)

### Community 23 - "Technology to Shape Mapping"
Cohesion: 0.15
Nodes (12): AI and ML, Boundary Groups for Non-AWS, Compute and Runtime, Databases, External Actors (outside the system boundary), External Services and APIs, General Architecture Icons, Messaging and Streaming (+4 more)

### Community 24 - "AWS Reference Architecture Style Guide"
Cohesion: 0.15
Nodes (12): AgentCore Icons, AWS Reference Architecture Style Guide, Category Tint Colors, Dark/Light Adaptive Contrast, Font Standard, Group Shapes with Adaptive Fills, Right Sidebar Step Legend, Service Group Containers (+4 more)

### Community 25 - "Layout Guidelines"
Cohesion: 0.20
Nodes (9): Complex Diagram Scaling (13+ services), Edge Routing, Handling Overlaps, Layout Guidelines, Layout Patterns, Layout Sizing Reference, Service Placement, Spacing and Overlap Prevention (+1 more)

### Community 26 - "XML Generation Rules"
Cohesion: 0.20
Nodes (9): Adding Context to Labels, AWS4 Shape Styles, Edge Labels, Edges, External Actors, Groups and Containers, Label Placement (CRITICAL), When to Use Containers vs Flat Layout (+1 more)

### Community 27 - "XML Templates — Examples"
Cohesion: 0.25
Nodes (7): Decision Point Annotations, Edge with Explicit Waypoints, Edge with Label, Invisible Group, Region with Adaptive Fill, Swimlane Container, XML Templates — Examples

### Community 28 - "XML Templates — Core Structure"
Cohesion: 0.25
Nodes (7): Legend Panel + Step Entry, Line Styles Box, On-Diagram Step Badge, Service Group Container, Title + Subtitle Block, Users Container, XML Templates — Core Structure

### Community 29 - "draw.io CLI Export Reference"
Cohesion: 0.29
Nodes (6): draw.io CLI Export Reference, Export Command, File Naming, Locating the CLI, Opening the Result, Supported Formats

### Community 30 - "Diagram Templates — Basic"
Cohesion: 0.29
Nodes (6): CI/CD Pipeline, Data Pipeline / Analytics, Diagram Templates — Basic, Microservices on ECS/EKS, Serverless Web Application, VPC with Public/Private Subnets

### Community 31 - "AWS4 Sub-Resource and Misc Shapes"
Cohesion: 0.40
Nodes (4): AWS4 Sub-Resource and Misc Shapes, Misc Shapes, Other Sub-Resource Icons, Sub-Resource Icons

### Community 32 - "Diagram Templates — Advanced"
Cohesion: 0.40
Nodes (4): Diagram Templates — Advanced, Hybrid Architecture (On-Premises + AWS), Multi-Region Active-Active, Sizing Guidelines for Templates

## Knowledge Gaps
- **229 isolated node(s):** `awsknowledge`, `UserdataScript.sh script`, `APP_DB_HOST`, `APP_DB_USER`, `APP_DB_PASSWORD` (+224 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Elastic Beanstalk Skill` connect `Security Defaults` to `Cost Estimation Patterns`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `aws-architecture-diagram skill` (e.g. with `AWS4 Service Icon Shapes Reference` and `draw.io CLI Export Reference`) actually correct?**
  _`aws-architecture-diagram skill` has 14 INFERRED edges - model-reasoned connections that need verification._
- **What connects `awsknowledge`, `UserdataScript.sh script`, `APP_DB_HOST` to the rest of the system?**
  _229 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `jquery-3.6.0.min.js` be split into smaller, more focused modules?**
  _Cohesion score 0.0670762928827445 - nodes in this community are weakly interconnected._
- **Should `Security Defaults` be split into smaller, more focused modules?**
  _Cohesion score 0.049682875264270614 - nodes in this community are weakly interconnected._
- **Should `Graphify Skill` be split into smaller, more focused modules?**
  _Cohesion score 0.07142857142857142 - nodes in this community are weakly interconnected._
- **Should `package.json` be split into smaller, more focused modules?**
  _Cohesion score 0.08333333333333333 - nodes in this community are weakly interconnected._