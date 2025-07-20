Feature: API Gateway Integration
  As a developer
  I want to access tournament services through a unified API gateway
  So that I can have consistent authentication, rate limiting, and monitoring

  Background:
    Given the API gateway is configured and running
    And the tournament microservices are registered with the gateway
    And I have valid API credentials

  Scenario: Access tournament API through gateway
    Given I want to retrieve tournament information
    When I make a GET request to "/api/v1/tournaments/spring-2024"
    And I include my API key in the Authorization header
    Then the gateway should authenticate my request
    And the request should be routed to the tournament-api service
    And I should receive a JSON response with tournament details:
      | Field           | Value                    |
      | id              | "spring-2024"            |
      | name            | "Spring Championship 2024" |
      | status          | "active"                 |
      | start_date      | "2024-03-15"             |
      | end_date        | "2024-04-15"             |
    And the response should include CORS headers
    And the request should be logged for monitoring

  Scenario: Rate limiting enforcement
    Given I am making multiple API requests
    When I exceed the rate limit of 100 requests per minute
    Then the gateway should return HTTP 429 (Too Many Requests)
    And the response should include retry-after header
    And my subsequent requests should be blocked until the limit resets
    And the rate limiting should be applied per API key
    And the violation should be logged for security monitoring

  Scenario: API versioning and backward compatibility
    Given I am using API version v1
    When I make a request to "/api/v1/leaderboard"
    Then I should receive the v1 response format
    When I make a request to "/api/v2/leaderboard"
    Then I should receive the v2 response format with additional fields
    And both versions should be supported simultaneously
    And deprecated endpoints should include deprecation warnings

  Scenario: Request/Response transformation
    Given I am submitting a match result
    When I send a POST request to "/api/v1/matches" with:
      | Field           | Value                    |
      | winner          | "Alpha Squad"            |
      | loser           | "Beta Warriors"          |
      | score           | "3-1"                    |
    Then the gateway should transform the request to the internal format
    And the response should be transformed back to the public format
    And sensitive internal fields should be removed from the response
    And the transformation should be logged for debugging

  Scenario: Circuit breaker pattern
    Given the ELO service is experiencing high latency
    When I make multiple requests to "/api/v1/elo/calculate"
    And the service response time exceeds 5 seconds
    Then the circuit breaker should open
    And subsequent requests should return cached or fallback responses
    And the gateway should not forward requests to the failing service
    And the circuit breaker should attempt to close after 30 seconds
    And the failure should be logged and monitored

  Scenario: API documentation and discovery
    Given I want to explore the available API endpoints
    When I access "/api/docs" or "/swagger-ui"
    Then I should see interactive API documentation
    And all available endpoints should be listed with:
      | Information     | Description           |
      | HTTP Method     | GET, POST, PUT, DELETE |
      | Endpoint Path   | /api/v1/resource      |
      | Parameters      | Required and optional |
      | Response Format | JSON schema           |
      | Rate Limits     | Requests per minute   |
    And I should be able to test endpoints directly from the documentation

  Scenario: API analytics and monitoring
    Given the API gateway is processing requests
    When I check the analytics dashboard
    Then I should see metrics for:
      | Metric           | Description           |
      | Request Count    | Total API calls       |
      | Response Time    | Average latency       |
      | Error Rate       | Percentage of errors  |
      | Top Endpoints    | Most used APIs        |
      | Geographic Data  | Request origins       |
    And the data should be available in real-time
    And historical trends should be displayed
    And alerts should be configured for anomalies

  Scenario: Security and authentication
    Given I am accessing protected tournament endpoints
    When I make a request without authentication
    Then the gateway should return HTTP 401 (Unauthorized)
    And the request should be blocked before reaching the service
    When I use an expired API key
    Then the gateway should return HTTP 403 (Forbidden)
    And the security violation should be logged
    And the incident should trigger security alerts 