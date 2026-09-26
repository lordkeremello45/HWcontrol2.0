# Google Forms → GitHub Beta Feedback

This integration replaces third-party automation with a native Google Apps Script trigger.

## Data flow

Google Form → Google Sheets response tab → Apps Script (on form submit) → GitHub Issue → GitHub Actions → GitLab Mirror

The existing GitHub Actions and GitLab mirror workflows remain independent and unchanged.

## Setup

1. Open the Google Form's response spreadsheet, then **Extensions → Apps Script**.
2. Add the contents of `Code.gs` to the Apps Script project.
3. In **Project Settings → Script Properties**, add:
   - `SPREADSHEET_ID`: the response spreadsheet ID from its URL.
   - `GITHUB_TOKEN`: a fine-grained token scoped only to `lordkeremello45/HWcontrol2.0`, with **Issues: Read and write**. Keep this secret in Script Properties; never paste it into source code or commit it.
4. Run `setupFeedbackTrigger()` once and approve the requested Google permissions.
5. Submit one real test response. The script creates a GitHub issue and writes its URL into a `GitHub Issue URL` column in the response sheet.
6. Confirm the resulting issue triggers the repository's normal Actions and mirror workflows.

## Operational behavior

- Uses an installable spreadsheet form-submit trigger; no polling or Make scenario.
- Adds a `GitHub Issue URL` column and skips rows already linked to an issue.
- Excludes fields whose headings indicate email, phone, contact, name, or personal contact details from issue bodies.
- API failures are thrown to Apps Script execution logs; the sheet is not marked as processed, allowing a controlled retry.
- The script does not upload diagnostic attachments. Do not include secrets or private credentials in feedback.
