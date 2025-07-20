Feature: Team Management
  As a tournament administrator
  I want to manage teams and their participation
  So that I can organize tournaments with proper team registration and tracking

  Background:
    Given I am authenticated as a tournament administrator
    And I have access to the team management dashboard
    And there are existing tournaments in the system

  Scenario: Register a new team
    Given I am on the team registration page
    When I fill in the team details:
      | Field           | Value                    |
      | Team Name       | "Omega Newcomers"        |
      | Captain Name    | "John Smith"             |
      | Captain Email   | "john@omeganewcomers.com" |
      | Max Players     | "8"                      |
      | Tournament      | "Spring Championship 2024" |
    And I click "Register Team"
    Then the team should be created with status "Pending Approval"
    And the team should be assigned a unique team ID
    And the captain should receive a confirmation email
    And the team should appear in the tournament's team list
    And an initial ELO rating should be assigned if ELO is enabled

  Scenario: Approve team registration
    Given there is a pending team registration for "Omega Newcomers"
    When I review the team details and approve the registration
    Then the team status should change to "Approved"
    And the team should be able to participate in matches
    And the captain should receive an approval notification
    And the team should be added to the tournament leaderboard
    And the team should be assigned to tournament brackets if applicable

  Scenario: Manage team roster
    Given there is an approved team "Alpha Squad"
    When I view the team roster
    Then I should see all current team members:
      | Player Name     | Role        | Join Date    | Status    |
      | John Smith      | Captain     | 2024-01-15   | Active    |
      | Jane Doe        | Player      | 2024-01-20   | Active    |
      | Bob Johnson     | Player      | 2024-02-01   | Active    |
    When I add a new player "Alice Brown" to the roster
    Then the player should be added with status "Pending"
    And the captain should be notified of the new player request
    And the player count should not exceed the maximum allowed

  Scenario: Handle team withdrawals
    Given team "Beta Warriors" is participating in "Spring Championship 2024"
    When the team captain submits a withdrawal request
    And I approve the withdrawal
    Then the team status should change to "Withdrawn"
    And all scheduled matches should be cancelled or rescheduled
    And the team should be removed from the leaderboard
    And other teams should be notified of the withdrawal
    And the tournament brackets should be updated if necessary

  Scenario: Team performance tracking
    Given team "Gamma Elite" has played multiple matches
    When I view the team's performance statistics
    Then I should see comprehensive performance data:
      | Metric           | Value | Description           |
      | Total Matches    | 12    | All matches played    |
      | Wins             | 9     | Matches won           |
      | Losses           | 3     | Matches lost          |
      | Win Rate         | 75%   | Percentage of wins    |
      | Current ELO      | 1650  | Current rating        |
      | ELO Change       | +150  | Rating change         |
      | Tournament Rank  | 1     | Current position      |
    And the data should be updated in real-time as new results are processed

  Scenario: Team communication and notifications
    Given I need to send a message to all teams in a tournament
    When I compose and send a tournament-wide announcement
    Then all team captains should receive the notification
    And the message should be stored in the communication log
    And teams should be able to respond or ask questions
    And the communication should be archived for future reference

  Scenario: Handle team disputes and conflicts
    Given there is a dispute between "Alpha Squad" and "Beta Warriors"
    When the dispute is reported through the system
    Then the dispute should be logged with details
    And tournament administrators should be notified
    And both teams should be contacted for their side of the story
    And the dispute should be resolved through the review workflow
    And the resolution should be documented and communicated to all parties

  Scenario: Team transfer between tournaments
    Given team "Delta Force" wants to transfer from "Spring Championship" to "Summer League"
    When I process the transfer request
    Then the team should be removed from the Spring Championship
    And the team should be added to the Summer League
    And their ELO rating should be reset for the new tournament
    And their match history should be preserved but marked as from previous tournament
    And the team should be notified of the successful transfer 