# Task Management App MVP

## Overview

A web-based task management application with boards, lists, and cards. Users can create boards to organize projects, add lists for workflow stages, and create cards for individual tasks.

## Objectives

- Allow users to create, read, update, and delete boards
- Support drag-and-drop reordering of lists and cards
- Provide card details with title, description, due date, and assignee
- Implement user authentication with email/password

## Scope

### In Scope
- Board, List, and Card CRUD operations
- Drag-and-drop for lists and cards
- User registration and login
- Basic role model: board owner and board member

### Out of Scope
- Real-time collaboration
- Mobile native app
- Third-party integrations

## Success Criteria

- [x] Users can sign up, log in, and manage sessions
- [x] Users can create boards and invite members
- [x] Lists can be added, reordered, and deleted within a board
- [x] Cards can be created, moved between lists, and edited
- [x] Drag-and-drop works for both lists and cards

## Technical Design

- **Frontend:** React with TypeScript, Vite bundler
- **Backend:** Node.js with Express, PostgreSQL
- **ORM:** Prisma
- **Auth:** JWT-based authentication
- **State:** React Query for server state, Zustand for UI state
- **DnD:** dnd-kit library

## Design Decisions

### Decision #1: Use Prisma over raw SQL
**Date:** 2026-03-20
**Decision:** Use Prisma with PostgreSQL for type-safe database access.
**Rationale:** Auto-generated client, good migration story, strong TypeScript support.
