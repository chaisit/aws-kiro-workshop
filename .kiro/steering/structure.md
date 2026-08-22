# Project Structure

```
src/             # Main application directory
├── index.js                  # Express app entry point, route definitions, middleware setup
├── package.json              # Dependencies and start script
├── app/
│   ├── config/
│   │   └── config.js         # Database configuration (Secrets Manager + env vars + defaults)
│   ├── controller/
│   │   └── supplier.controller.js  # Route handlers with validation (CRUD for students)
│   └── models/
│       └── supplier.model.js       # Data access layer — raw SQL queries via mysql2
├── views/                    # Mustache HTML templates
│   ├── home.html             # Landing page
│   ├── supplier-add.html     # Add student form
│   ├── supplier-update.html  # Edit student form
│   ├── supplier-list-all.html # Student list view
│   ├── supplier-form-fields.html  # Shared form partial
│   ├── header.html           # Shared HTML head partial
│   ├── footer.html           # Shared footer partial
│   ├── nav.html              # Navigation partial
│   ├── 404.html              # Not found page
│   └── 500.html              # Server error page
└── public/                   # Static assets served by Express
    ├── css/                  # Bootstrap + custom styles
    ├── js/                   # Bootstrap + jQuery
    └── img/                  # Images and favicon
```

## Architecture Pattern
- **MVC (Model-View-Controller)** without a formal framework — manually structured
- **Model** (`app/models/`): Constructor functions with static methods for DB operations. Each method opens its own connection.
- **View** (`views/`): Mustache templates rendered server-side. Partials are included via `{{>partialName}}`.
- **Controller** (`app/controller/`): Express route handlers with inline validation arrays (express-validator).
- **Routes**: Defined directly in `index.js` (no separate router files).

## Workspace-level Files
- `UserdataScript.sh` — EC2 userdata script for provisioning the server (installs deps, creates DB, starts app)
- `aws-credentials/` — Contains AWS access keys and SSH key pair for workshop use
- `tmp/code.zip` — Archived source code
