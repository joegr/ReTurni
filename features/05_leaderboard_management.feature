Feature: Leaderboard Management
  As a player
  I want to view and track tournament standings
  So that I can see my team's performance and ranking

  Background:
    Given I am authenticated as a player
    And I have access to the leaderboard view
    And there are active tournaments with teams and matches

  Scenario: View tournament leaderboard
    Given I am viewing the "Spring Championship 2024" leaderboard
    When the leaderboard loads
    Then I should see teams ranked by their current standings:
      | Rank | Team Name      | Wins | Losses | ELO Rating | Points |
      | 1    | Gamma Elite    | 8    | 1      | 1650       | 24     |
      | 2    | Alpha Squad    | 7    | 2      | 1580       | 21     |
      | 3    | Beta Warriors  | 6    | 3      | 1520       | 18     |
      | 4    | Delta Force    | 5    | 4      | 1480       | 15     |
    And the leaderboard should update in real-time

  Scenario: Filter leaderboard by tournament
    Given I am on the leaderboard page
    When I select "Summer League 2024" from the tournament dropdown
    Then the leaderboard should show only teams from "Summer League 2024"
    And the rankings should be specific to that tournament
    And the ELO ratings should be tournament-specific

  Scenario: Sort leaderboard by different criteria
    Given I am viewing the tournament leaderboard
    When I click on the "ELO Rating" column header
    Then the leaderboard should be sorted by ELO rating in descending order
    And "Gamma Elite" should appear first with ELO 1650
    When I click on the "Wins" column header
    Then the leaderboard should be sorted by wins in descending order
    And teams with the most wins should appear first

  Scenario: View team performance history
    Given I am viewing the leaderboard
    When I click on "Alpha Squad" team name
    Then I should see their detailed performance history:
      | Match Date       | Opponent        | Result | ELO Change |
      | 2024-03-01      | Beta Warriors   | W 3-1  | +16        |
      | 2024-03-08      | Gamma Elite     | L 1-3  | -24        |
      | 2024-03-15      | Delta Force     | W 3-0  | +12        |
    And I should see their ELO rating progression over time

  Scenario: Real-time leaderboard updates
    Given I am viewing the live leaderboard
    When a new match result is approved:
      | Winner          | "Beta Warriors"          |
      | Loser           | "Delta Force"            |
      | Score           | "3-2"                    |
    Then the leaderboard should automatically update
    And "Beta Warriors" should move up in the rankings
    And "Delta Force" should move down in the rankings
    And the ELO ratings should be updated immediately
    And I should see a notification of the update

  Scenario: View leaderboard with tiebreakers
    Given there are teams with identical records:
      | Team Name      | Wins | Losses | ELO Rating |
      | Alpha Squad    | 6    | 3      | 1580       |
      | Beta Warriors  | 6    | 3      | 1580       |
    When I view the leaderboard
    Then the teams should be ranked using tiebreaker criteria:
      | Criterion      | Priority |
      | Head-to-Head   | 1        |
      | Game Win %     | 2        |
      | ELO Rating     | 3        |
    And the tiebreaker should be clearly indicated

  Scenario: Export leaderboard data
    Given I am viewing the tournament leaderboard
    When I click "Export Leaderboard"
    Then I should be able to download the data in multiple formats:
      | Format | Description           |
      | CSV    | Comma-separated values |
      | JSON   | JavaScript Object     |
      | PDF    | Printable document    |
    And the exported data should include all current standings and statistics

  Scenario: View historical leaderboards
    Given I am on the leaderboard page
    When I select a past date "2024-02-15"
    Then I should see the leaderboard as it appeared on that date
    And the rankings should reflect the state at that time
    And I should be able to compare with current standings 