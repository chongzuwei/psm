# PSM User Roles and User Stories (Normalized)

This document restructures the provided role requirements into a consistent, build-ready backlog.

## 1. Roles and Core Needs

### Admin (Headmaster)
- Manage user accounts.
- Manage schedule availability.
- Delete learning material modules.
- Receive payment notifications from parents.
- Access learning materials.

### Student
- Register, log in, and edit profile.
- Play quizzes.
- Access learning materials.
- View achievements.
- Ask AI questions about quiz topics.

### Teacher
- Register, log in, and edit profile.
- Send and receive messages with parents.
- View student feedback.
- Manage quizzes.
- Upload and manage learning resources.
- Track student progress analytics.
- Delete learning material modules.
- Access learning materials.

### Parent
- Register, log in, and edit profile.
- Send and receive messages with teachers.
- Receive notifications.
- Track child progress.
- Make payments.

## 2. Normalized User Story List

The original text repeats some IDs (for example US003, US004, US006) across role sections. The table below keeps one canonical definition per story ID.

| ID | User Story | Primary Roles |
|---|---|---|
| US001 | As an admin, I want to manage user accounts so that I can maintain accurate and up-to-date system access control. | Admin |
| US002 | As an admin, I want to manage schedule availability so that learning sessions or bookings are organized without conflicts. | Admin |
| US003 | As an admin and teacher, we want to delete learning material modules so that outdated or incorrect content can be removed. | Admin, Teacher |
| US004 | As a student, teacher, and parent, we want to register, log in, and edit our user profiles so that we can securely manage personal information. | Student, Teacher, Parent |
| US005 | As a student, I want to play quizzes so that I can test understanding and improve knowledge. | Student |
| US006 | As a student, teacher, and admin, we want to access learning materials so that we can prepare for quizzes or lessons. | Student, Teacher, Admin |
| US007 | As a student, I want to view my achievements so that I can track my learning progress and performance. | Student |
| US008 | As a teacher and parent, we want to send messages to each other so that we can communicate progress and important updates. | Teacher, Parent |
| US009 | As a teacher, I want to view feedback from students so that I can improve teaching methods. | Teacher |
| US010 | As a teacher, I want to manage quizzes so that I can assess student learning effectively. | Teacher |
| US011 | As a teacher, I want to upload learning resources so that students can access study materials. | Teacher |
| US012 | As a parent and teacher, we want to track student/child progress so that academic performance and improvement can be monitored. | Parent, Teacher |
| US013 | As a student, I want to ask AI questions so that I can get help understanding quiz answers. | Student |

## 3. Role-to-Feature Permission Matrix

| Feature | Admin | Teacher | Student | Parent |
|---|---|---|---|---|
| Auth + Profile | View/manage all users (US001), own profile (US004) | Own profile (US004) | Own profile (US004) | Own profile (US004) |
| User Management | Full CRUD | No | No | No |
| Schedule Availability | Full CRUD | Optional view/update (if assigned) | View own schedule | View child schedule |
| Learning Materials | Access + delete (US003, US006) | Upload/manage/delete/access (US003, US006, US011) | Access (US006) | Optional view |
| Quiz | Oversight/reporting | Create/edit/publish (US010) | Attempt quizzes (US005) | View child results |
| Achievement | View reports | View class reports | View own achievements (US007) | View child achievements |
| Messaging | Optional monitor/moderate | Message parent (US008) | Optional future | Message teacher (US008) |
| Feedback | Oversight | View and respond (US009) | Submit feedback | Optional view |
| Progress Analytics | Global dashboards | Class/student dashboards (US012) | Own progress | Child progress (US012) |
| Payments + Notifications | Receive payment notifications | No | No | Make payment + receive receipt |
| AI Q&A | Optional monitoring | Optional support mode | Ask AI (US013) | No |

## 4. MVP Build Order (Recommended)

### Phase 1: Foundation
- US004 authentication and profile by role.
- US001 basic admin user management (list users, edit role, disable account).
- Role-based navigation and route guards.

### Phase 2: Learning Core
- US011 learning resource upload and listing.
- US006 role-based access to learning materials.
- US003 delete/archive learning modules (soft delete recommended).

### Phase 3: Assessment
- US010 teacher quiz management.
- US005 student quiz play flow.
- US007 achievement and score history.

### Phase 4: Communication and Tracking
- US008 teacher-parent messaging.
- US009 teacher feedback viewer.
- US012 progress tracking dashboards.

### Phase 5: Payment + AI
- Parent payment flow and admin notification.
- US013 AI question support for students.

## 5. Suggested Firestore Collections

- `users`: profile, role, status, createdAt, lastLoginAt.
- `schedules`: timeslot, ownerRole, classId, availabilityStatus.
- `materials`: title, subject, fileUrl, uploadedBy, isDeleted.
- `quizzes`: metadata, questions, teacherId, publishStatus.
- `attempts`: quizId, studentId, score, submittedAt.
- `achievements`: studentId, badge/level, earnedAt.
- `messages`: threadId, senderId, receiverId, content, sentAt.
- `feedback`: studentId, teacherId, text, rating, createdAt.
- `progress`: studentId, metrics, updatedAt.
- `payments`: parentId, studentId, amount, status, paidAt.
- `notifications`: recipientId, type, payload, readAt.
- `ai_questions`: studentId, question, answer, createdAt.

## 6. Acceptance Criteria Samples

### US001 Admin Manage Users
- Admin can view all users with role and status.
- Admin can update role for non-admin users.
- Admin can deactivate/reactivate user access.

### US005 Student Play Quiz
- Student can start an assigned quiz.
- Student can submit answers and receive a score.
- Attempt is recorded and appears in achievement/progress views.

### US008 Teacher-Parent Messaging
- Teacher can open a thread with a parent.
- Parent can reply in the same thread.
- Both users see ordered message history with timestamps.

### US013 Student Ask AI
- Student can ask a question from quiz context.
- System returns an answer and stores question history.
- Teacher/admin can optionally review logs for quality/safety.
