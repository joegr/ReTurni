Feature: Notification System
  As a tournament system
  I want to send timely notifications to users
  So that I can keep all participants informed of important events and updates

  Background:
    Given the notification system is enabled
    And users have configured their notification preferences
    And the system has access to user contact information

  Scenario: Send match result notifications
    Given a match result has been approved
    When the result is processed:
      | Winner          | "Alpha Squad"            |
      | Loser           | "Beta Warriors"          |
      | Score           | "3-1"                    |
      | Tournament      | "Spring Championship 2024" |
    Then notifications should be sent to:
      | Recipient       | Notification Type | Content                    |
      | Alpha Squad     | Win Notification  | "Congratulations! You won 3-1" |
      | Beta Warriors   | Loss Notification | "Match result: Lost 3-1"   |
      | Tournament Admin| Result Summary    | "Match completed: Alpha vs Beta" |
    And the notifications should include match details and ELO changes
    And the notifications should be sent via configured channels (email, SMS, app)

  Scenario: Send tournament status updates
    Given a tournament status has changed
    When the tournament "Spring Championship 2024" is paused
    Then all participants should receive a status update notification:
      | Recipient Type  | Notification Content                    |
      | All Teams       | "Tournament paused - check for updates" |
      | Referees        | "Tournament paused - no new assignments" |
      | Administrators  | "Tournament paused by admin"            |
    And the notification should include the reason for the pause
    And the notification should indicate when the tournament will resume
    And users should be able to acknowledge the notification

  Scenario: Send match schedule notifications
    Given a new match has been scheduled
    When match "Alpha Squad vs Beta Warriors" is scheduled for "2024-03-20 14:00"
    Then the following notifications should be sent:
      | Recipient       | Timing    | Content                    |
      | Alpha Squad     | Immediate | "New match scheduled"      |
      | Beta Warriors   | Immediate | "New match scheduled"      |
      | Alpha Squad     | 24h prior | "Match reminder tomorrow"  |
      | Beta Warriors   | 24h prior | "Match reminder tomorrow"  |
      | Alpha Squad     | 1h prior  | "Match starts in 1 hour"   |
      | Beta Warriors   | 1h prior  | "Match starts in 1 hour"   |
    And the notifications should include match details and venue information
    And users should be able to confirm or request reschedule

  Scenario: Send ELO rating change notifications
    Given an ELO rating has been updated
    When "Alpha Squad" ELO changes from 1500 to 1520
    Then the team should receive an ELO update notification:
      | Field           | Value                    |
      | Current ELO     | 1520                     |
      | Previous ELO    | 1500                     |
      | Change          | +20                      |
      | Match           | "vs Beta Warriors"       |
      | Tournament Rank | 2 (up from 3)            |
    And the notification should include the impact on tournament standings
    And the notification should show the team's current position
    And the notification should be sent immediately after the update

  Scenario: Send review workflow notifications
    Given a match result is submitted for review
    When "Alpha Squad vs Beta Warriors" result is submitted
    Then the following notifications should be sent:
      | Recipient       | Notification Type | Content                    |
      | Tournament Manager | Review Request | "New result needs review"  |
      | Alpha Squad     | Pending Review   | "Result submitted for review" |
      | Beta Warriors   | Pending Review   | "Result submitted for review" |
    When the result is approved by the manager
    Then notifications should be sent:
      | Recipient       | Notification Type | Content                    |
      | Alpha Squad     | Result Approved  | "Match result approved"     |
      | Beta Warriors   | Result Approved  | "Match result approved"     |
      | Both Teams      | ELO Updated      | "ELO ratings updated"       |

  Scenario: Send system maintenance notifications
    Given system maintenance is scheduled
    When maintenance is planned for "2024-03-25 02:00-04:00 UTC"
    Then advance notifications should be sent:
      | Timing          | Recipient Type | Content                    |
      | 1 week prior    | All Users      | "Scheduled maintenance notice" |
      | 24h prior       | All Users      | "Maintenance tomorrow"     |
      | 1h prior        | All Users      | "Maintenance in 1 hour"    |
    And the notifications should include:
      | Information     | Description           |
      | Duration        | Expected downtime     |
      | Impact          | Services affected     |
      | Contact         | Support information   |
    And users should be able to check maintenance status

  Scenario: Send tournament deadline notifications
    Given tournament deadlines are approaching
    When registration deadline is "2024-03-15"
    Then deadline notifications should be sent:
      | Timing          | Recipient Type | Content                    |
      | 1 week prior    | All Users      | "Registration closes in 1 week" |
      | 3 days prior    | All Users      | "Registration closes in 3 days" |
      | 1 day prior     | All Users      | "Registration closes tomorrow" |
      | 6h prior        | All Users      | "Registration closes in 6 hours" |
    And the notifications should include the deadline and consequences
    And users should be able to complete registration directly from the notification

  Scenario: Handle notification preferences
    Given users have different notification preferences
    When a notification is triggered
    Then the system should respect user preferences:
      | User Type       | Email | SMS | App Push | Frequency |
      | Team Captain    | Yes   | Yes | Yes      | Immediate |
      | Team Member     | Yes   | No  | Yes      | Daily     |
      | Tournament Admin| Yes   | Yes | Yes      | Immediate |
      | Referee         | Yes   | No  | No       | Weekly    |
    And users should be able to update their preferences
    And the system should track notification delivery status
    And failed notifications should be retried with exponential backoff 