Feature: ELO Rating System
  As a tournament system
  I want to track and update team ratings
  So that I can maintain accurate relative strength rankings

  Background:
    Given the ELO rating system is enabled
    And there are teams with existing ELO ratings:
      | Team Name      | Current ELO | Tournament |
      | Alpha Squad    | 1500        | Spring 2024 |
      | Beta Warriors  | 1450        | Spring 2024 |
      | Gamma Elite    | 1600        | Spring 2024 |
      | Delta Force    | 1400        | Spring 2024 |

  Scenario: Calculate ELO rating change after a match
    Given team "Alpha Squad" (ELO: 1500) plays against team "Beta Warriors" (ELO: 1450)
    When "Alpha Squad" wins the match
    And the match result is submitted with timestamp "2024-03-15T14:30:00Z"
    Then the ELO rating change should be calculated using the standard formula
    And "Alpha Squad" ELO should increase by approximately 16 points
    And "Beta Warriors" ELO should decrease by approximately 16 points
    And the rating change should be recorded with the match timestamp

  Scenario: Handle unexpected upsets in ELO calculation
    Given team "Delta Force" (ELO: 1400) plays against team "Gamma Elite" (ELO: 1600)
    When "Delta Force" wins the match (upset victory)
    And the match result is submitted with timestamp "2024-03-15T16:45:00Z"
    Then "Delta Force" ELO should increase by approximately 32 points
    And "Gamma Elite" ELO should decrease by approximately 32 points
    And the rating change should reflect the unexpected outcome

  Scenario: Update ELO ratings across multiple tournaments
    Given a team "Alpha Squad" participates in multiple tournaments
    And their ELO ratings are tracked separately per tournament
    When they win a match in "Spring Championship 2024"
    And they lose a match in "Summer League 2024"
    Then their ELO should increase in "Spring Championship 2024"
    And their ELO should decrease in "Summer League 2024"
    And the ratings should remain independent between tournaments

  Scenario: Handle ELO rating for new teams
    Given a new team "Omega Newcomers" joins a tournament
    When they play their first match against "Alpha Squad" (ELO: 1500)
    And "Omega Newcomers" wins the match
    Then "Omega Newcomers" should be assigned an initial ELO rating
    And their rating should be calculated based on the opponent's strength
    And the rating should be recorded in the tournament database

  Scenario: ELO rating with K-factor variation
    Given the tournament has different K-factors based on match importance:
      | Match Type        | K-Factor |
      | Regular Season    | 32       |
      | Playoff           | 40       |
      | Championship      | 50       |
    When "Alpha Squad" wins a championship match against "Gamma Elite"
    Then the ELO change should use K-factor 50
    And the rating change should be larger than a regular season match 