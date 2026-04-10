# Tasks: Email Attachments Support (#154)

## Task 1: Configuration ✅
- [x] Add `mailer_attachments` attr_accessor to Config class
- [x] Initialize to `nil` in Config#initialize
- [x] Add YARD documentation

## Task 2: Attachment Validation ✅
- [x] Add `validate_attachment_spec!(spec)` private method to Mailers::Helpers
  - Validate spec is Hash
  - Validate `:filename` present
  - Validate exactly one of `:content` or `:path` present
  - Validate file exists when `:path` provided
  - Raise ArgumentError with descriptive messages

## Task 3: Attachment Resolution ✅
- [x] Add `mailer_attachments(target)` method (same pattern as `mailer_cc`)
- [x] Add `resolve_attachments(key)` method (notifiable override > target > global)
- [x] Add `process_attachments(mail_obj, specs)` method

## Task 4: Mailer Integration ✅
- [x] Modify `headers_for` to call `resolve_attachments` and store in headers
- [x] Modify `send_mail` to extract and process attachments

## Task 5: Generator Template ✅
- [x] Add `config.mailer_attachments` example to initializer template

## Task 6: Tests ✅
- [x] Config attribute tests (nil default, Hash/Array/Proc/nil assignment)
- [x] `validate_attachment_spec!` tests (valid specs, missing filename, missing content/path, both content and path, non-Hash, non-existent path)
- [x] `mailer_attachments(target)` resolution tests (target method, global Hash, global Proc, nil fallback)
- [x] `resolve_attachments` priority tests (notifiable override > target > global, nil fallback at each level)
- [x] `process_attachments` tests (single Hash, Array, nil, empty, with/without mime_type)
- [x] Integration: notification email with attachments (single, multiple, no attachments)
- [x] Integration: batch notification email with attachments
- [x] Backward compatibility: existing emails without attachments unchanged
- [x] Verify 100% coverage
