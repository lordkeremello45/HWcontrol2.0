/**
 * HWcontrol2.0 Beta Feedback → GitHub Issues
 *
 * Configure Script Properties:
 *   SPREADSHEET_ID = ID of the Google Form response spreadsheet
 *   GITHUB_TOKEN   = fine-grained GitHub token with Issues: Read and write
 *
 * Run setupFeedbackTrigger() once from the Apps Script editor and authorize it.
 * Do not store tokens in this source file or commit them to Git.
 */

const GITHUB_OWNER = "lordkeremello45";
const GITHUB_REPO = "HWcontrol2.0";
const ISSUE_URL_HEADER = "GitHub Issue URL";

function setupFeedbackTrigger() {
  const props = PropertiesService.getScriptProperties();
  const spreadsheetId = props.getProperty("SPREADSHEET_ID");
  if (!spreadsheetId) throw new Error("Missing Script Property: SPREADSHEET_ID");
  if (!props.getProperty("GITHUB_TOKEN")) {
    throw new Error("Missing Script Property: GITHUB_TOKEN");
  }

  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
  ScriptApp.getProjectTriggers()
    .filter(trigger => trigger.getHandlerFunction() === "onFeedbackSubmit")
    .forEach(trigger => ScriptApp.deleteTrigger(trigger));

  ScriptApp.newTrigger("onFeedbackSubmit")
    .forSpreadsheet(spreadsheet)
    .onFormSubmit()
    .create();
}

function onFeedbackSubmit(event) {
  if (!event || !event.range) {
    throw new Error("This handler must be invoked by the spreadsheet form-submit trigger.");
  }

  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const sheet = event.range.getSheet();
    const row = event.range.getRow();
    const lastColumn = Math.max(sheet.getLastColumn(), 1);
    let headers = sheet.getRange(1, 1, 1, lastColumn).getValues()[0]
      .map(value => String(value || "").trim());

    let issueUrlColumn = headers.indexOf(ISSUE_URL_HEADER) + 1;
    if (issueUrlColumn === 0) {
      issueUrlColumn = lastColumn + 1;
      sheet.getRange(1, issueUrlColumn).setValue(ISSUE_URL_HEADER);
    }

    const existingUrl = String(sheet.getRange(row, issueUrlColumn).getValue() || "").trim();
    if (existingUrl) return;

    const values = sheet.getRange(row, 1, 1, sheet.getLastColumn()).getValues()[0];
    headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0]
      .map(value => String(value || "").trim());

    const entries = [];
    headers.forEach((header, index) => {
      if (!header || header === ISSUE_URL_HEADER) return;
      if (/e-?mail|phone|contact|name|kişisel|iletişim/i.test(header)) return;
      const value = String(values[index] == null ? "" : values[index]).trim();
      if (value) entries.push("### " + header + "\n" + value);
    });

    const answerMap = {};
    headers.forEach((header, index) => { if (header) answerMap[header] = values[index]; });
    const findAnswer = pattern => {
      const key = headers.find(header => pattern.test(header));
      return key ? String(answerMap[key] || "").trim() : "";
    };

    const os = findAnswer(/operating system|\bos\b|işletim sistemi/i) || "Unspecified OS";
    const issueType = findAnswer(/issue type|feedback type|problem type|geri bildirim türü|sorun türü/i);
    const summary = findAnswer(/what happened|issue description|problem description|description|sorun açıklaması/i);
    const titleDetail = (summary || issueType || "Feedback").replace(/\s+/g, " ").slice(0, 90);
    const title = "[Beta Feedback] " + os + " — " + titleDetail;

    const body = [
      "Submitted through the HWcontrol2.0 Beta Feedback Google Form.",
      "",
      "## Environment",
      "- OS: " + os,
      "",
      "## Feedback",
      entries.join("\n\n") || "No non-private response fields were provided.",
      "",
      "---",
      "Automated intake: Google Sheets → Apps Script → GitHub Issues."
    ].join("\n");

    const issue = createGitHubIssue_(title, body);
    sheet.getRange(row, issueUrlColumn).setValue(issue.html_url);
  } finally {
    lock.releaseLock();
  }
}

function createGitHubIssue_(title, body) {
  const token = PropertiesService.getScriptProperties().getProperty("GITHUB_TOKEN");
  if (!token) throw new Error("Missing Script Property: GITHUB_TOKEN");

  const url = "https://api.github.com/repos/" + GITHUB_OWNER + "/" + GITHUB_REPO + "/issues";
  const response = UrlFetchApp.fetch(url, {
    method: "post",
    contentType: "application/json",
    headers: {
      Authorization: "Bearer " + token,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28"
    },
    payload: JSON.stringify({
      title: title,
      body: body,
      labels: ["beta-feedback"]
    }),
    muteHttpExceptions: true
  });

  const status = response.getResponseCode();
  const responseBody = response.getContentText();
  if (status < 200 || status >= 300) {
    throw new Error("GitHub Issues API returned HTTP " + status + ": " + responseBody);
  }
  const issue = JSON.parse(responseBody);
  if (!issue.html_url) throw new Error("GitHub API response did not include issue URL.");
  return issue;
}
