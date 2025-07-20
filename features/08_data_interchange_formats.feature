Feature: Data Interchange Formats
  As a tournament system
  I want to exchange data in standardized formats
  So that I can ensure compatibility and data integrity across services

  Background:
    Given the tournament system uses standardized data formats
    And all microservices implement the same data schemas
    And data validation is enabled for all endpoints

  Scenario: Match result data format
    Given a match result is submitted
    When the result is processed
    Then it should follow the standardized JSON format:
      | Field           | Type     | Required | Description           |
      | match_id        | string   | yes      | Unique match identifier |
      | tournament_id   | string   | yes      | Tournament reference  |
      | winner          | string   | yes      | Winning team name     |
      | loser           | string   | yes      | Losing team name      |
      | score           | string   | yes      | Match score (e.g., "3-1") |
      | game_scores     | array    | no       | Individual game scores |
      | timestamp       | datetime | yes      | ISO 8601 format       |
      | hash            | string   | yes      | SHA-256 hash          |
      | status          | string   | yes      | pending/approved/rejected |
      | submitted_by    | string   | yes      | User who submitted    |
    And the data should be validated against the schema
    And any invalid data should be rejected with error details

  Scenario: ELO rating data format
    Given an ELO rating update is processed
    When the rating is calculated and stored
    Then it should follow the standardized format:
      | Field           | Type     | Required | Description           |
      | team_id         | string   | yes      | Unique team identifier |
      | tournament_id   | string   | yes      | Tournament reference  |
      | current_elo     | integer  | yes      | Current ELO rating    |
      | previous_elo    | integer  | yes      | Previous ELO rating   |
      | change          | integer  | yes      | Rating change         |
      | match_id        | string   | yes      | Match that caused change |
      | k_factor        | integer  | yes      | K-factor used         |
      | timestamp       | datetime | yes      | When rating was updated |
      | hash            | string   | yes      | Hash of rating data   |
    And the rating should be validated to ensure it's within reasonable bounds
    And the change should be calculated correctly based on the ELO formula

  Scenario: Leaderboard data format
    Given a leaderboard is generated
    When the standings are calculated
    Then it should follow the standardized format:
      | Field           | Type     | Required | Description           |
      | tournament_id   | string   | yes      | Tournament reference  |
      | standings       | array    | yes      | Array of team standings |
      | last_updated    | datetime | yes      | Last update timestamp |
      | total_teams     | integer  | yes      | Number of teams       |
      | hash            | string   | yes      | Hash of leaderboard   |
    And each team standing should include:
      | Field           | Type     | Required | Description           |
      | rank            | integer  | yes      | Current rank          |
      | team_id         | string   | yes      | Team identifier       |
      | team_name       | string   | yes      | Team name             |
      | wins            | integer  | yes      | Number of wins        |
      | losses          | integer  | yes      | Number of losses      |
      | elo_rating      | integer  | yes      | Current ELO rating    |
      | points          | integer  | yes      | Tournament points     |

  Scenario: Tournament configuration data format
    Given a tournament is created
    When the configuration is stored
    Then it should follow the standardized format:
      | Field           | Type     | Required | Description           |
      | tournament_id   | string   | yes      | Unique identifier     |
      | name            | string   | yes      | Tournament name       |
      | type            | string   | yes      | Tournament type       |
      | start_date      | date     | yes      | Start date            |
      | end_date        | date     | yes      | End date              |
      | max_teams       | integer  | yes      | Maximum teams         |
      | status          | string   | yes      | active/paused/ended   |
      | config          | object   | yes      | Tournament settings   |
      | created_at      | datetime | yes      | Creation timestamp    |
      | updated_at      | datetime | yes      | Last update timestamp |
    And the config object should include:
      | Field           | Type     | Required | Description           |
      | elo_enabled     | boolean  | yes      | ELO system enabled    |
      | hash_verification| boolean | yes      | Hash verification     |
      | human_review    | boolean  | yes      | Human review required |
      | k_factor        | integer  | yes      | ELO K-factor          |
      | initial_elo     | integer  | yes      | Initial ELO rating    |

  Scenario: API response format standardization
    Given an API request is made
    When the response is generated
    Then it should follow the standardized response format:
      | Field           | Type     | Required | Description           |
      | success         | boolean  | yes      | Request success status |
      | data            | object   | no       | Response data         |
      | error           | object   | no       | Error information     |
      | timestamp       | datetime | yes      | Response timestamp    |
      | request_id      | string   | yes      | Unique request ID     |
    And error responses should include:
      | Field           | Type     | Required | Description           |
      | code            | string   | yes      | Error code            |
      | message         | string   | yes      | Error message         |
      | details         | object   | no       | Additional details    |

  Scenario: Data validation and error handling
    Given invalid data is submitted
    When the validation is performed
    Then the system should return validation errors:
      | Field           | Validation Rule        | Error Message        |
      | match_id        | Required, unique       | "Match ID is required" |
      | score           | Format: "X-Y"          | "Invalid score format" |
      | timestamp       | ISO 8601 format        | "Invalid timestamp"   |
      | elo_rating      | Range: 100-3000        | "ELO out of range"   |
    And the error response should include all validation failures
    And the invalid data should not be processed or stored
    And the validation failure should be logged for monitoring

  Scenario: Data serialization and deserialization
    Given data needs to be exchanged between services
    When the data is serialized and transmitted
    Then it should maintain data integrity:
      | Data Type       | Serialization Format | Validation           |
      | Match Results   | JSON                 | Schema validation    |
      | ELO Ratings     | JSON                 | Numeric validation   |
      | Leaderboards    | JSON                 | Array validation     |
      | Configurations  | JSON                 | Object validation    |
    And the deserialized data should match the original
    And type conversions should be handled correctly
    And null values should be preserved appropriately 