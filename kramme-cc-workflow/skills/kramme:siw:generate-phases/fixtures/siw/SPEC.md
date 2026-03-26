# Task Management App MVP

## Overview

Build a web-based task management application with boards, lists, and cards. Users can create boards to organize projects, add lists for workflow stages, and create cards for individual tasks.

## Objectives

- Allow users to create, read, update, and delete boards
- Support drag-and-drop reordering of lists and cards
- Provide card details with title, description, due date, and assignee
- Implement user authentication with email/password

## Scope

### In Scope

- Board CRUD operations
- List CRUD within boards
- Card CRUD within lists
- Drag-and-drop for lists and cards
- Card detail view with fields: title, description, due date, labels, assignee
- User registration and login (email/password)
- Basic role model: board owner and board member

### Out of Scope

- Real-time collaboration / WebSocket updates
- Mobile native app
- Third-party integrations (Slack, GitHub, etc.)
- File attachments on cards
- Activity/audit log

## Success Criteria

- [ ] Users can sign up, log in, and manage sessions
- [ ] Users can create boards and invite members
- [ ] Lists can be added, reordered, and deleted within a board
- [ ] Cards can be created, moved between lists, and edited
- [ ] Drag-and-drop works for both lists and cards
- [ ] All API endpoints return proper error responses

## Technical Design

- **Frontend:** React with TypeScript, Vite bundler
- **Backend:** Node.js with Express, PostgreSQL database
- **ORM:** Prisma
- **Auth:** JWT-based authentication
- **State:** React Query for server state, Zustand for UI state
- **DnD:** dnd-kit library

## Work Context

| Attribute | Value |
|-----------|-------|
| Work Type | Production Feature |
| Priority Dimensions | Completeness, Actionability, Testability |
| Deprioritized | Value Proposition |
