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
const STATUS_HEADER = "GitHub Status";
const ATTEMPTS_HEADER = "GitHub Attempts";
const LAST_ERROR_HEADER = "GitHub Last Error";
const FEEDBACK_ID_HEADER = "GitHub Feedback ID";

const MAX_RETRIES = 3;
const RETRY_DELAYS_MS = [1000, 3000, 7000];

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
    const columns = ensureTrackingColumns_(sheet);

    const existingUrl = String(sheet.getRange(row, columns.issueUrl).getValue() || "").trim();
    const existingStatus = String(sheet.getRange(row, columns.status).getValue() || "").trim();

    // Fast duplicate protection: a successfully processed row is never submitted again.
    if (existingUrl || existingStatus === "SUCCESS") return;

    const feedbackId = getOrCreateFeedbackId_(sheet, row, columns.feedbackId);
    sheet.getRange(row, columns.status).setValue("PROCESSING");
    sheet.getRange(row, columns.lastError).clearContent();

    const values = sheet.getRange(row, 1, 1, sheet.getLastColumn()).getValues()[0];
    const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0]
      .map(value => String(value || "").trim());

    const entries = [];
    headers.forEach((header, index) => {
      if (!header || isTrackingHeader_(header)) return;
      if (/e-?mail|phone|contact|name|kişisel|iletişim/i.test(header)) return;
      const value = String(values[index] == null ? "" : values[index]).trim();
      if (value) entries.push("### " + header + "\n" + value);
    });

    const answerMap = {};
    headers.forEach((header, index) => {
      if (header) answerMap[header] = values[index];
    });

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
      "Automated intake: Google Sheets → Apps Script → GitHub Issues.",
      "",
      "<!-- HWCONTROL-FEEDBACK-ID: " + feedbackId + " -->"
    ].join("\n");

    // Recovery protection: if a previous attempt created the Issue but failed before
    // writing the URL back to Sheets, find that Issue instead of creating a duplicate.
    const existingIssue = findGitHubIssueByFeedbackId_(feedbackId);
    if (existingIssue) {
      sheet.getRange(row, columns.issueUrl).setValue(existingIssue.html_url);
      sheet.getRange(row, columns.status).setValue("SUCCESS");
      return;
    }

    let issue = null;
    let lastError = "";

    for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
      sheet.getRange(row, columns.attempts).setValue(attempt);

      try {
        issue = createGitHubIssue_(title, body);
        break;
      } catch (error) {
        lastError = error instanceof Error ? error.message : String(error);

        if (attempt < MAX_RETRIES) {
          Utilities.sleep(RETRY_DELAYS_MS[attempt - 1]);
        }
      }
    }

    if (!issue) {
      sheet.getRange(row, columns.status).setValue("FAILED");
      sheet.getRange(row, columns.lastError).setValue(lastError.slice(0, 5000));
      throw new Error("GitHub Issue creation failed after " + MAX_RETRIES + " attempts: " + lastError);
    }

    sheet.getRange(row, columns.issueUrl).setValue(issue.html_url);
    sheet.getRange(row, columns.status).setValue("SUCCESS");
    sheet.getRange(row, columns.lastError).clearContent();
  } finally {
    lock.releaseLock();
  }
}

function ensureTrackingColumns_(sheet) {
  let lastColumn = Math.max(sheet.getLastColumn(), 1);
  let headers = sheet.getRange(1, 1, 1, lastColumn).getValues()[0]
    .map(value => String(value || "").trim());

  const required = [
    ISSUE_URL_HEADER,
    STATUS_HEADER,
    ATTEMPTS_HEADER,
    LAST_ERROR_HEADER,
    FEEDBACK_ID_HEADER
  ];

  required.forEach(header => {
    if (headers.indexOf(header) === -1) {
      lastColumn++;
      sheet.getRange(1, lastColumn).setValue(header);
      headers.push(header);
    }
  });

  return {
    issueUrl: headers.indexOf(ISSUE_URL_HEADER) + 1,
    status: headers.indexOf(STATUS_HEADER) + 1,
    attempts: headers.indexOf(ATTEMPTS_HEADER) + 1,
    lastError: headers.indexOf(LAST_ERROR_HEADER) + 1,
    feedbackId: headers.indexOf(FEEDBACK_ID_HEADER) + 1
  };
}

function isTrackingHeader_(header) {
  return [
    ISSUE_URL_HEADER,
    STATUS_HEADER,
    ATTEMPTS_HEADER,
    LAST_ERROR_HEADER,
    FEEDBACK_ID_HEADER
  ].indexOf(header) !== -1;
}

function getOrCreateFeedbackId_(sheet, row, column) {
  const existing = String(sheet.getRange(row, column).getValue() || "").trim();
  if (existing) return existing;

  const spreadsheetId = PropertiesService.getScriptProperties().getProperty("SPREADSHEET_ID");
  const sheetId = sheet.getSheetId();
  const feedbackId = spreadsheetId + ":" + sheetId + ":" + row;
  sheet.getRange(row, column).setValue(feedbackId);
  return feedbackId;
}

function findGitHubIssueByFeedbackId_(feedbackId) {
  const token = PropertiesService.getScriptProperties().getProperty("GITHUB_TOKEN");
  if (!token) throw new Error("Missing Script Property: GITHUB_TOKEN");

  const query = encodeURIComponent(
    "repo:" + GITHUB_OWNER + "/" + GITHUB_REPO + ' "HWCONTROL-FEEDBACK-ID:' + feedbackId + '" in:body'
  );
  const url = "https://api.github.com/search/issues?q=" + query;

  const response = UrlFetchApp.fetch(url, {
    method: "get",
    headers: {
      Authorization: "Bearer " + token,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28"
    },
    muteHttpExceptions: true
  });

  const status = response.getResponseCode();
  const responseBody = response.getContentText();

  if (status < 200 || status >= 300) {
    throw new Error("GitHub Issue search returned HTTP " + status + ": " + responseBody);
  }

  const result = JSON.parse(responseBody);
  return result.items && result.items.length ? result.items[0] : null;
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
  if (!issue.html_url) {
    throw new Error("GitHub API response did not include issue URL.");
  }

  return issue;
}
