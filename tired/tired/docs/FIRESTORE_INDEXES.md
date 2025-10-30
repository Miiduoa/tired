# Firestore Composite Indexes (suggested)

Create these composite indexes for better performance and to satisfy ordered queries:

1) Conversations by participant + updatedAt
- Collection: conversations
- Fields: participantIds (array-contains), updatedAt (desc)

2) Messages by createdAt
- Collection group: messages (subcollection `conversations/{id}/messages`)
- Fields: createdAt (desc)

3) Posts filters
- Collection: posts
- Fields:
  - createdAt (desc)
  - category (asc), createdAt (desc) — if filtering by category
  - visibility (asc), createdAt (desc) — if filtering by visibility
  - sourceType (asc), createdAt (desc) — if filtering organization/personal

Note: Firestore auto-indexes single fields. Only add composites when console warns or you need ordered filtering on multiple fields.

