# Requirements: Email Attachments Support (#154)

## Overview

Add support for email attachments to notification emails. Currently, users must override the mailer to add attachments. This feature provides a clean API following the same pattern as the existing CC feature (#107).

## Requirements

### R1: Global Attachment Configuration

As a developer, I want to configure default attachments for all notification emails at the gem level.

1. `config.mailer_attachments` in the initializer applies attachments to all notification emails
2. Supports Hash (single), Array of Hash (multiple), Proc (dynamic), or nil (none)
3. When Proc, called with notification key as parameter
4. When nil or empty, no attachments added

### R2: Target-Level Attachment Configuration

As a developer, I want to define attachments at the target model level.

1. When target defines `mailer_attachments` method, those attachments are used
2. Returns Array of attachment specs, single Hash, or nil
3. When nil, falls back to global configuration

### R3: Notifiable-Level Attachment Override

As a developer, I want to override attachments per notification type in the notifiable model.

1. When notifiable defines `overriding_notification_email_attachments(target, key)`, used with highest priority
2. Receives target and notification key as parameters
3. When nil, falls back to target-level or global configuration

### R4: Attachment Resolution Priority

1. Priority order: notifiable override > target method > global configuration
2. When higher-priority returns nil, fall back to next level
3. When all return nil, send email without attachments

### R5: Attachment Format

1. Hash with `:filename` (required) and `:content` (binary data)
2. Hash with `:filename` (required) and `:path` (local file path)
3. Optional `:mime_type` key; inferred from filename if not provided
4. Exactly one of `:content` or `:path` must be provided
5. Multiple attachments as Array of Hashes

### R6: Error Handling

1. Missing `:filename` raises ArgumentError
2. Missing both `:content` and `:path` raises ArgumentError
3. Non-existent file path raises ArgumentError
4. Non-Hash spec raises ArgumentError

### R7: Backward Compatibility

1. No attachments when `mailer_attachments` is not configured
2. No database migrations required
3. Existing mailer customizations continue to work

### R8: Batch Notification Attachments

1. Batch notification emails support attachments using the same configuration
2. Same resolution priority applies
