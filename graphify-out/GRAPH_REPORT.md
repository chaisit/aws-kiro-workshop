# Graph Report - AWS_Academy_Kiro-Workshop  (2026-08-22)

## Corpus Check
- Corpus is ~33,333 words - fits in a single context window. You may not need a graph.

## Summary
- 240 nodes · 329 edges · 16 communities (10 shown, 6 thin omitted)
- Extraction: 67% EXTRACTED · 33% INFERRED · 0% AMBIGUOUS · INFERRED: 108 edges (avg confidence: 0.92)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Frontend JS Libraries
- AWS Deploy & Security
- Graphify Pipeline
- Express App Dependencies
- Architecture Diagrams
- Student CRUD Controllers
- View Templates & Assets
- Bootstrap JS Internals
- MCP Server Config
- EC2 Userdata Script
- DocumentDB Serverless
- FalkorDB Export
- SVG Export
- Wiki Export
- CLAUDE.md Integration
- Thai Communication

## God Nodes (most connected - your core abstractions)
1. `Graphify Skill` - 16 edges
2. `se()` - 10 edges
3. `i()` - 9 edges
4. `Security Defaults` - 9 edges
5. `o()` - 8 edges
6. `l()` - 8 edges
7. `Elastic Beanstalk Skill` - 8 edges
8. `e()` - 7 edges
9. `r()` - 7 edges
10. `xe()` - 7 edges

## Surprising Connections (you probably didn't know these)
- `l()` --indirect_call--> `i()`  [INFERRED]
  src/public/js/jquery-3.6.0.min.js → src/public/js/bootstrap.min.js
- `o()` --indirect_call--> `me()`  [INFERRED]
  src/public/js/bootstrap.min.js → src/public/js/jquery-3.6.0.min.js
- `l()` --indirect_call--> `o()`  [INFERRED]
  src/public/js/jquery-3.6.0.min.js → src/public/js/bootstrap.min.js
- `se()` --indirect_call--> `n()`  [INFERRED]
  src/public/js/jquery-3.6.0.min.js → src/public/js/bootstrap.min.js
- `r()` --indirect_call--> `at()`  [INFERRED]
  src/public/js/bootstrap.min.js → src/public/js/jquery-3.6.0.min.js

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **hyper_diagram_generation_workflow** — _kiro_skills_aws_architecture_diagram_skill_md, _kiro_skills_aws_architecture_diagram_references_xml_rules_md, _kiro_skills_aws_architecture_diagram_references_style_guide_md, _kiro_skills_aws_architecture_diagram_references_xml_templates_structure_md, _kiro_skills_aws_architecture_diagram_references_layout_guidelines_md, _kiro_skills_aws_architecture_diagram_references_post_processing_md [INFERRED]
- **hyper_deploy_workflow** — _kiro_skills_deploy_skill_md, _kiro_skills_deploy_references_cost_estimation_md, concept_mcp_server, concept_infrastructure_as_code [INFERRED]
- **Deploy Skill Security Stack** — _kiro_skills_deploy_references_security_encryption, _kiro_skills_deploy_references_security_vpc_placement, _kiro_skills_deploy_references_security_iam_least_privilege, _kiro_skills_deploy_references_security_security_groups, _kiro_skills_deploy_references_security_secrets_manager [EXTRACTED 1.00]
- **Graphify Pipeline Stages** — _kiro_skills_graphify_skill_ast_extraction, _kiro_skills_graphify_skill_semantic_extraction, _kiro_skills_graphify_skill_community_detection, _kiro_skills_graphify_skill_god_nodes, _kiro_skills_graphify_skill_graph_report [EXTRACTED 1.00]
- **Project Technology and Deployment Context** — _kiro_steering_tech_express, _kiro_steering_tech_nodejs, _kiro_steering_product_aurora_mysql, _kiro_steering_product_ec2_deployment, _kiro_steering_tech_aws_secrets_manager [INFERRED 0.85]
- **shared_layout_partials** — src_views_header, src_views_footer, src_views_nav [INFERRED]
- **student_crud_views** — src_views_supplier_add, src_views_supplier_update, src_views_supplier_list_all, src_views_supplier_form_fields [INFERRED]
- **frontend_asset_stack** — bootstrap_css, bootstrap_js, jquery, base_css [INFERRED]

## Communities (16 total, 6 thin omitted)

### Community 0 - "Frontend JS Libraries"
Cohesion: 0.07
Nodes (32): a(), c(), A(), at(), be(), ce(), e(), Ee() (+24 more)

### Community 1 - "AWS Deploy & Security"
Cohesion: 0.05
Nodes (44): AWS Amplify Hosting, Aurora Serverless v2, CDK TypeScript Default IaC, Elastic Beanstalk Default, AWS Fargate, AWS Lambda, Service Defaults, Encryption at Rest (+36 more)

### Community 2 - "Graphify Pipeline"
Cohesion: 0.07
Nodes (29): Add URL to Corpus, Watch Mode, MCP Server Export, Neo4j Export, Confidence Scoring Rules, Extraction Subagent Spec, Node ID Format, Cross-Repo Graph Merge (+21 more)

### Community 3 - "Express App Dependencies"
Cohesion: 0.08
Nodes (23): body-parser, cors, express, express-validator, mustache-express, mysql2, serve-favicon, author (+15 more)

### Community 4 - "Architecture Diagrams"
Cohesion: 0.16
Nodes (21): AWS4 Sub-Resource Shapes Reference, AWS4 Service Icon Shapes Reference, draw.io CLI Export Reference, Diagram Templates Advanced, Diagram Templates Basic, General Architecture Icons Reference, AWS Group and Edge Style Templates, Layout Guidelines (+13 more)

### Community 5 - "Student CRUD Controllers"
Cohesion: 0.10
Nodes (12): config, {body, validationResult}, Supplier, dbConfig, mysql, app, bodyParser, cors (+4 more)

### Community 6 - "View Templates & Assets"
Cohesion: 0.20
Nodes (18): base.css, Bootstrap CSS, Bootstrap JS, jQuery 3.6.0, Mustache Partials, caps.jpeg, espresso.jpg, 404.html (+10 more)

### Community 7 - "Bootstrap JS Internals"
Cohesion: 0.37
Nodes (12): e(), i(), l(), n(), o(), r(), s(), t() (+4 more)

### Community 8 - "MCP Server Config"
Cohesion: 0.43
Nodes (6): FASTMCP_LOG_LEVEL, aws-docs, awsiac, awsknowledge, awspricing, uvx

### Community 9 - "EC2 Userdata Script"
Cohesion: 0.29
Nodes (6): APP_DB_HOST, APP_DB_NAME, APP_DB_PASSWORD, APP_DB_USER, APP_PORT, UserdataScript.sh script

## Knowledge Gaps
- **77 isolated node(s):** `awsknowledge`, `UserdataScript.sh script`, `APP_DB_HOST`, `APP_DB_USER`, `APP_DB_PASSWORD` (+72 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Are the 14 inferred relationships involving `aws-architecture-diagram skill` (e.g. with `AWS4 Service Icon Shapes Reference` and `draw.io CLI Export Reference`) actually correct?**
  _`aws-architecture-diagram skill` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Are the 6 inferred relationships involving `se()` (e.g. with `a()` and `c()`) actually correct?**
  _`se()` has 6 INFERRED edges - model-reasoned connections that need verification._
- **Are the 6 inferred relationships involving `i()` (e.g. with `e()` and `n()`) actually correct?**
  _`i()` has 6 INFERRED edges - model-reasoned connections that need verification._
- **What connects `awsknowledge`, `UserdataScript.sh script`, `APP_DB_HOST` to the rest of the system?**
  _77 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Frontend JS Libraries` be split into smaller, more focused modules?**
  _Cohesion score 0.07346938775510205 - nodes in this community are weakly interconnected._
- **Should `AWS Deploy & Security` be split into smaller, more focused modules?**
  _Cohesion score 0.049682875264270614 - nodes in this community are weakly interconnected._
- **Should `Graphify Pipeline` be split into smaller, more focused modules?**
  _Cohesion score 0.07142857142857142 - nodes in this community are weakly interconnected._