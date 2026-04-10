# Tasks: Email Attachments Support (#154)

## Task 1: Configuration
- [ ] Add `mailer_attachments` attr_accessor to Config class
- [ ] Initialize to `nil` in Config#initialize
- [ ] Add YARD documentation

## Task 2: Attachment Validation
- [ ] Add `validate_attachment_spec!(spec)` private method to Mailers::Helpers
  - Validate spec is Hash
  - Validate `:filename` present
  - Validate exactly one of `:content` or `:path` present
  - Validate file exists when `:path` provided
  - Raise ArgumentError with descriptive messages

## Task 3: Attachment Resolution
- [ ] Add `mailer_attachments(target)` method (same pattern as `mailer_cc`)
- [ ] Add `resolve_attachments(key)` method (notifiable override > target > global)
- [ ] Add `process_attachments(mail_obj, specs)` method

## Task 4: Mailer Integration
- [ ] Modify `headers_for` to call `resolve_attachments` and store in headers
- [ ] Modify `send_mail` to extract and process attachments

## Task 5: Generator Template
- [ ] Add `config.mailer_attachments` example to initializer template

## Task 6: Tests
- [ ] Config attribute tests (nil default, Hash/Array/Proc/nil assignment)
- [ ] `validate_attachment_spec!` tests (valid specs, missing filename, missing content/path, both content and path, non-Hash, non-existent path)
- [ ] `mailer_attachments(target)` resolution tests (target method, global Hash, global Proc, nil fallback)
- [ ] `resolve_attachments` priority tests (notifiable override > target > global, nil fallback at each level)
- [ ] `process_attachments` tests (single Hash, Array, nil, empty, with/without mime_type)
- [ ] Integration: notification email with attachments (single, multiple, no attachments)
- [ ] Integration: batch notification email with attachments
- [ ] Backward compatibility: existing emails without attachments unchanged
- [ ] Verify 100% coverage
