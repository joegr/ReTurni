Feature: Match Scheduling
  As a tournament administrator
  I want to schedule and manage matches
  So that I can organize tournament play efficiently

  Background:
    Given I am authenticated as a tournament administrator
    And I have access to the match scheduling dashboard
    And there are approved teams in the tournament

  Scenario: Create a new match schedule
    Given I am on the match scheduling page
    When I create a new match between "Alpha Squad" and "Beta Warriors":
      | Field           | Value                    |
      | Tournament      | "Spring Championship 2024" |
      | Team 1          | "Alpha Squad"            |
      | Team 2          | "Beta Warriors"          |
      | Date            | "2024-03-20"             |
      | Time            | "14:00"                  |
      | Duration        | "2 hours"                |
      | Venue           | "Main Arena"             |
      | Referee         | "John Smith"             |
    And I click "Schedule Match"
    Then the match should be created with status "Scheduled"
    And both teams should receive match notifications
    And the match should appear in the tournament calendar
    And the match should be assigned a unique match ID
    And the schedule should be checked for conflicts

  Scenario: Auto-generate tournament brackets
    Given I have 16 teams in a single elimination tournament
    When I click "Generate Brackets"
    Then the system should create a complete bracket structure:
      | Round           | Matches | Teams per Match |
      | Round 1         | 8       | 2               |
      | Quarter Finals  | 4       | 2               |
      | Semi Finals     | 2       | 2               |
      | Finals          | 1       | 2               |
    And all matches should be scheduled with appropriate timing
    And teams should be seeded based on their ELO ratings
    And the bracket should be displayed visually
    And all teams should be notified of their match schedule

  Scenario: Handle match rescheduling
    Given there is a scheduled match between "Alpha Squad" and "Beta Warriors"
    When "Alpha Squad" requests a reschedule due to "Player availability"
    And I approve the reschedule request
    And I set the new date to "2024-03-22" at "16:00"
    Then the match should be updated with the new schedule
    And both teams should receive updated notifications
    And the tournament calendar should be updated
    And any dependent matches should be adjusted if necessary
    And the reschedule should be logged with reason

  Scenario: Manage match conflicts
    Given there are multiple matches scheduled for the same time slot
    When I review the schedule conflicts
    Then I should see a list of conflicting matches:
      | Match 1         | Match 2         | Conflict Type |
      | Alpha vs Beta   | Gamma vs Delta  | Time overlap  |
      | Team A vs Team B| Team C vs Team D| Venue overlap |
    And I should be able to resolve conflicts by:
      | Action          | Description           |
      | Reschedule      | Move one match to different time |
      | Change Venue    | Move match to different venue |
      | Cancel Match    | Cancel and reschedule later |
    And the system should suggest optimal conflict resolutions

  Scenario: Track match status and progression
    Given there are multiple matches in different states
    When I view the match status dashboard
    Then I should see the current status of all matches:
      | Match           | Status      | Next Action Required |
      | Alpha vs Beta   | Scheduled   | Teams to confirm     |
      | Gamma vs Delta  | In Progress | Referee to submit result |
      | Team A vs Team B| Completed   | Result approved      |
      | Team C vs Team D| Cancelled   | Reschedule needed    |
    And I should be able to filter matches by status
    And I should see upcoming matches highlighted
    And I should receive alerts for matches requiring attention

  Scenario: Handle match cancellations
    Given there is a scheduled match between "Alpha Squad" and "Beta Warriors"
    When the match is cancelled due to "Weather conditions"
    And I process the cancellation
    Then the match status should change to "Cancelled"
    And both teams should be notified of the cancellation
    And the reason should be recorded
    And the match should be removed from the active schedule
    And a new match should be scheduled if possible
    And the tournament progression should be updated accordingly

  Scenario: Manage referee assignments
    Given there are multiple matches requiring referees
    When I assign referees to matches
    Then each match should have an assigned referee:
      | Match           | Referee        | Availability | Experience |
      | Alpha vs Beta   | John Smith     | Available    | High       |
      | Gamma vs Delta  | Jane Doe       | Available    | Medium     |
      | Team A vs Team B| Bob Johnson    | Unavailable  | High       |
    And referees should receive assignment notifications
    And the system should check referee availability
    And backup referees should be assigned if needed
    And referee conflicts should be avoided

  Scenario: Generate match reports and statistics
    Given matches have been played and results recorded
    When I generate a tournament match report
    Then I should see comprehensive match statistics:
      | Metric           | Value | Description           |
      | Total Matches    | 45    | All scheduled matches |
      | Completed        | 42    | Matches with results  |
      | Cancelled        | 3     | Cancelled matches     |
      | Average Duration | 1.8h  | Average match length  |
      | Referee Coverage | 95%   | Matches with referees |
    And the report should include match-by-match details
    And the data should be exportable in multiple formats
    And the report should be available for historical reference 