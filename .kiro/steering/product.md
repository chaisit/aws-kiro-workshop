# Product Overview

This is a **Student Management Web Application** built as part of an AWS Academy capstone workshop. The app allows users to track student inquiries through a simple CRUD interface.

## Core Functionality
- List all students
- Add new students (name, address, city, state, phone)
- Update existing student records
- Delete students

## Deployment Context
- Designed to run on an AWS EC2 instance (Amazon Linux 2023)
- Uses AWS Aurora MySQL as the backing database (table: `students` in database `STUDENTS`)
- Database credentials are sourced from AWS Secrets Manager (`Mydbsecret`) with local fallback defaults
- The app runs on port 80 in production (configurable via `APP_PORT` env var, defaults to 3000 locally)

## Naming Note
The codebase uses "supplier" in file/class names but the domain is actually **students**. This is a legacy naming mismatch — the database table is `students` and the UI references students throughout.
