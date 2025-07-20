Feature: Audit Logging and Compliance
  As a tournament system
  I want to maintain comprehensive audit logs
  So that I can ensure transparency, security, and regulatory compliance

  Background:
    Given the audit logging system is enabled
    And all system activities are being logged
    And the logs are stored securely with encryption

  Scenario: Log tournament deployment activities
    Given an admin deploys a new tournament
    When the tournament "Spring Championship 2024" is deployed
    Then the following audit events should be logged:
      | Event Type       | User        | Action                    | Timestamp           |
      | TOURNAMENT_CREATE| admin@system| Created tournament        | 2024-03-01T10:00:00Z |
      | CONFIG_UPDATE    | admin@system| Set ELO enabled=true      | 2024-03-01T10:01:00Z |
      | CONFIG_UPDATE    | admin@system| Set hash verification=true| 2024-03-01T10:02:00Z |
      | K8S_DEPLOY       | system      | Deployed to cluster       | 2024-03-01T10:05:00Z |
    And each log entry should include:
      | Field           | Description           |
      | event_id        | Unique event identifier |
      | user_id         | User who performed action |
      | action          | Specific action taken |
      | resource        | Resource affected     |
      | old_value       | Previous value (if applicable) |
      | new_value       | New value (if applicable) |
      | ip_address      | User's IP address     |
      | user_agent      | Browser/client info   |
      | session_id      | User session identifier |

  Scenario: Log match result submissions and approvals
    Given a match result is submitted and approved
    When "Alpha Squad vs Beta Warriors" result is processed
    Then the following audit trail should be created:
      | Event Type       | User        | Action                    | Details             |
      | RESULT_SUBMIT    | referee@system| Submitted match result  | Score: 3-1         |
      | HASH_GENERATE    | system      | Generated result hash     | SHA-256: abc123... |
      | REVIEW_REQUEST   | system      | Sent for human review     | Manager notified    |
      | RESULT_APPROVE   | manager@system| Approved match result   | Reason: Valid score |
      | ELO_UPDATE       | system      | Updated ELO ratings       | Alpha: +16, Beta: -16 |
      | LEADERBOARD_UPDATE| system     | Updated leaderboard       | Rankings changed    |
    And each event should be linked to the match result
    And the audit trail should be immutable
    And the events should be searchable by match ID

  Scenario: Log ELO rating changes
    Given ELO ratings are updated for multiple teams
    When a match affects ELO ratings
    Then detailed ELO audit logs should be created:
      | Team           | Previous ELO | New ELO | Change | Match ID | Formula Used |
      | Alpha Squad    | 1500         | 1516    | +16    | match-001| Standard ELO |
      | Beta Warriors  | 1450         | 1434    | -16    | match-001| Standard ELO |
    And each ELO change should include:
      | Field           | Description           |
      | calculation_id  | Unique calculation ID |
      | k_factor        | K-factor used        |
      | expected_score  | Expected win probability |
      | actual_score    | Actual result (1 for win, 0 for loss) |
      | calculation_timestamp | When calculation performed |
    And the audit log should preserve the mathematical basis for changes

  Scenario: Log system access and authentication
    Given users access the tournament system
    When authentication events occur
    Then comprehensive access logs should be maintained:
      | Event Type       | User        | Action                    | Result    |
      | LOGIN_ATTEMPT    | user@email.com| Login attempt           | SUCCESS   |
      | LOGIN_ATTEMPT    | unknown@email.com| Login attempt         | FAILED    |
      | LOGOUT           | user@email.com| User logout             | SUCCESS   |
      | PASSWORD_CHANGE  | user@email.com| Password updated        | SUCCESS   |
      | API_ACCESS       | api@client.com| API request             | SUCCESS   |
    And failed authentication attempts should trigger security alerts
    And suspicious activity patterns should be flagged
    And access logs should be retained for compliance periods

  Scenario: Log data integrity verification
    Given data integrity checks are performed
    When hash verification is run
    Then integrity audit logs should be created:
      | Check Type       | Resource        | Status    | Hash Verified |
      | MATCH_RESULT     | match-001       | VALID     | abc123def456... |
      | ELO_RATING       | team-alpha      | VALID     | def456ghi789... |
      | LEADERBOARD      | tournament-001  | VALID     | ghi789jkl012... |
      | MATCH_RESULT     | match-002       | TAMPERED  | Original: abc123... |
    And any integrity violations should trigger immediate alerts
    And the original data should be preserved in the audit log
    And recovery procedures should be initiated automatically

  Scenario: Generate compliance reports
    Given audit logs have been collected over time
    When I generate a compliance report for "Q1 2024"
    Then the report should include:
      | Section          | Content                    |
      | User Activity    | Login/logout patterns     |
      | Data Changes     | All modifications made    |
      | Access Control   | Who accessed what when    |
      | Integrity Checks | Hash verification results |
      | Security Events  | Failed attempts, alerts   |
      | System Changes   | Configuration updates     |
    And the report should be exportable in compliance formats:
      | Format           | Purpose                    |
      | PDF              | Human readable            |
      | JSON             | Machine readable          |
      | CSV              | Data analysis             |
      | XML              | Legacy system integration |
    And the report should be digitally signed for authenticity

  Scenario: Handle audit log retention and archival
    Given audit logs are being generated continuously
    When logs reach retention thresholds
    Then the following retention policy should be applied:
      | Log Type         | Retention Period | Storage Location |
      | Authentication   | 7 years          | Encrypted archive |
      | Data Changes     | 10 years         | Encrypted archive |
      | System Events    | 5 years          | Encrypted archive |
      | Performance      | 2 years          | Compressed storage |
    And old logs should be automatically archived
    And archived logs should remain searchable
    And log integrity should be verified during archival
    And access to archived logs should require elevated permissions

  Scenario: Monitor audit log anomalies
    Given the audit logging system is monitoring activities
    When unusual patterns are detected
    Then security alerts should be triggered for:
      | Anomaly Type     | Threshold        | Action              |
      | Failed Logins    | >5 per hour      | Account lockout     |
      | Data Modifications| >100 per hour   | Review required     |
      | API Rate Limits  | >1000 per minute| Rate limiting       |
      | Hash Mismatches  | Any occurrence   | Immediate alert     |
      | Unusual Hours    | Activity 2-5 AM  | Investigation       |
    And the alerts should include context and severity levels
    And automated responses should be triggered for critical events
    And human review should be required for suspicious patterns 