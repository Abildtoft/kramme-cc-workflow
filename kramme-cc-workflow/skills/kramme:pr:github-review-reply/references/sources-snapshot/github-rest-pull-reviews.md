REST API endpoints for pull request reviews - GitHub Docs

[Skip to main content](#main-content)

The REST API is now versioned. For more information, see "[About API versioning](/rest/overview/api-versions)."

# REST API endpoints for pull request reviews

Use the REST API to interact with pull request reviews.

## [About pull request reviews](#about-pull-request-reviews)

Pull Request Reviews are groups of pull request review comments on a pull request, grouped together with a state and optional body comment.

## [List reviews for a pull request](#list-reviews-for-a-pull-request)

Lists all reviews for a specified pull request. The list of reviews returns in chronological order.

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github-commitcomment.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github-commitcomment.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github-commitcomment.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github-commitcomment.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "List reviews for a pull request"](#list-reviews-for-a-pull-request--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Pull requests" repository permissions (read)

This endpoint can be used without authentication or the aforementioned permissions if only public resources are requested.

### [Parameters for "List reviews for a pull request"](#list-reviews-for-a-pull-request--parameters)

Headers

| Name, Type, Description  |

|

`accept` string

Setting to `application/vnd.github+json` is recommended.

  |

Path parameters

| Name, Type, Description  |

|

`owner` string Required

The account owner of the repository. The name is not case sensitive.

  |

|

`repo` string Required

The name of the repository without the `.git` extension. The name is not case sensitive.

  |

|

`pull_number` integer Required

The number that identifies the pull request.

  |

Query parameters

| Name, Type, Description  |

|

`per_page` integer

The number of results per page (max 100). For more information, see "[Using pagination in the REST API](https://docs.github.com/rest/using-the-rest-api/using-pagination-in-the-rest-api)."

Default: `30`  |

|

`page` integer

The page number of the results to fetch. For more information, see "[Using pagination in the REST API](https://docs.github.com/rest/using-the-rest-api/using-pagination-in-the-rest-api)."

Default: `1`  |

### [HTTP response status codes for "List reviews for a pull request"](#list-reviews-for-a-pull-request--status-codes)

| Status code | Description  |

| `200` |

The list of reviews returns in chronological order.  |

### [Code samples for "List reviews for a pull request"](#list-reviews-for-a-pull-request--code-samples)

#### Request example

get/repos/{owner}/{repo}/pulls/{pull_number}/reviews

-
-
-

Copy to clipboard curl request example

`curl -L \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/pulls/PULL_NUMBER/reviews`

####

The list of reviews returns in chronological order.

-
-

`Status: 200`

`[ { "id": 80, "node_id": "MDE3OlB1bGxSZXF1ZXN0UmV2aWV3ODA=", "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "body": "Here is the body for the review.", "state": "APPROVED", "html_url": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80", "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/12", "_links": { "html": { "href": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80" }, "pull_request": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/12" } }, "submitted_at": "2019-11-17T17:43:43Z", "commit_id": "ecdd80bb57125d7ba9641ffaa4d7d2c19d3f3091", "author_association": "COLLABORATOR" } ]`

## [Create a review for a pull request](#create-a-review-for-a-pull-request)

Creates a review on a specified pull request.

This endpoint triggers [notifications](https://docs.github.com/github/managing-subscriptions-and-notifications-on-github/about-notifications). Creating content too quickly using this endpoint may result in secondary rate limiting. For more information, see "[Rate limits for the API](https://docs.github.com/rest/using-the-rest-api/rate-limits-for-the-rest-api#about-secondary-rate-limits)" and "[Best practices for using the REST API](https://docs.github.com/rest/guides/best-practices-for-using-the-rest-api)."

Pull request reviews created in the `PENDING` state are not submitted and therefore do not include the `submitted_at` property in the response. To create a pending review for a pull request, leave the `event` parameter blank. For more information about submitting a `PENDING` review, see "[Submit a review for a pull request](https://docs.github.com/rest/pulls/reviews#submit-a-review-for-a-pull-request)."

Note

 To comment on a specific line in a file, you need to first determine the position of that line in the diff. To see a pull request diff, add the `application/vnd.github.v3.diff` media type to the `Accept` header of a call to the [Get a pull request](https://docs.github.com/rest/pulls/pulls#get-a-pull-request) endpoint.

The `position` value equals the number of lines down from the first "@@" hunk header in the file you want to add a comment. The line just below the "@@" line is position 1, the next line is position 2, and so on. The position in the diff continues to increase through lines of whitespace and additional hunks until the beginning of a new file.

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github-commitcomment.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github-commitcomment.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github-commitcomment.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github-commitcomment.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "Create a review for a pull request"](#create-a-review-for-a-pull-request--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Pull requests" repository permissions (write)

### [Parameters for "Create a review for a pull request"](#create-a-review-for-a-pull-request--parameters)

Headers

| Name, Type, Description  |

|

`accept` string

Setting to `application/vnd.github+json` is recommended.

  |

Path parameters

| Name, Type, Description  |

|

`owner` string Required

The account owner of the repository. The name is not case sensitive.

  |

|

`repo` string Required

The name of the repository without the `.git` extension. The name is not case sensitive.

  |

|

`pull_number` integer Required

The number that identifies the pull request.

  |

Body parameters

| Name, Type, Description  |

|

`commit_id` string

The SHA of the commit that needs a review. Not using the latest commit SHA may render your review comment outdated if a subsequent commit modifies the line you specify as the `position`. Defaults to the most recent commit in the pull request when you do not specify a value.

  |

|

`body` string

Required when using `REQUEST_CHANGES` or `COMMENT` for the `event` parameter. The body text of the pull request review.

  |

|

`event` string

The review action you want to perform. The review actions include: `APPROVE`, `REQUEST_CHANGES`, or `COMMENT`. By leaving this blank, you set the review action state to `PENDING`, which means you will need to [submit the pull request review](https://docs.github.com/rest/pulls/reviews#submit-a-review-for-a-pull-request) when you are ready.

Can be one of: `APPROVE`, `REQUEST_CHANGES`, `COMMENT`   |

|

`comments` array of objects

Use the following table to specify the location, destination, and contents of the draft review comment.

  |

| Properties of `comments`

| Name, Type, Description  |

|

`path` string Required

The relative path to the file that necessitates a review comment.

  |

|

`position` integer

The position in the diff where you want to add a review comment. Note this value is not the same as the line number in the file. The `position` value equals the number of lines down from the first "@@" hunk header in the file you want to add a comment. The line just below the "@@" line is position 1, the next line is position 2, and so on. The position in the diff continues to increase through lines of whitespace and additional hunks until the beginning of a new file.

  |

|

`body` string Required

Text of the review comment.

  |

|

`line` integer

  |

|

`side` string

  |

|

`start_line` integer

  |

|

`start_side` string

  |
  |

### [HTTP response status codes for "Create a review for a pull request"](#create-a-review-for-a-pull-request--status-codes)

| Status code | Description  |

| `200` |

OK  |

| `403` |

Forbidden  |

| `422` |

Validation failed, or the endpoint has been spammed.  |

### [Code samples for "Create a review for a pull request"](#create-a-review-for-a-pull-request--code-samples)

#### Request example

post/repos/{owner}/{repo}/pulls/{pull_number}/reviews

-
-
-

Copy to clipboard curl request example

`curl -L \ -X POST \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/pulls/PULL_NUMBER/reviews \ -d '{"commit_id":"ecdd80bb57125d7ba9641ffaa4d7d2c19d3f3091","body":"This is close to perfect! Please address the suggested inline change.","event":"REQUEST_CHANGES","comments":[{"path":"file.md","position":6,"body":"Please add more information here, and fix this typo."}]}'`

####

Response

-
-

`Status: 200`

`{ "id": 80, "node_id": "MDE3OlB1bGxSZXF1ZXN0UmV2aWV3ODA=", "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "body": "This is close to perfect! Please address the suggested inline change.", "state": "CHANGES_REQUESTED", "html_url": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80", "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/12", "_links": { "html": { "href": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80" }, "pull_request": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/12" } }, "submitted_at": "2019-11-17T17:43:43Z", "commit_id": "ecdd80bb57125d7ba9641ffaa4d7d2c19d3f3091", "author_association": "COLLABORATOR" }`

## [Get a review for a pull request](#get-a-review-for-a-pull-request)

Retrieves a pull request review by its ID.

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github-commitcomment.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github-commitcomment.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github-commitcomment.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github-commitcomment.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "Get a review for a pull request"](#get-a-review-for-a-pull-request--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Pull requests" repository permissions (read)

This endpoint can be used without authentication or the aforementioned permissions if only public resources are requested.

### [Parameters for "Get a review for a pull request"](#get-a-review-for-a-pull-request--parameters)

Headers

| Name, Type, Description  |

|

`accept` string

Setting to `application/vnd.github+json` is recommended.

  |

Path parameters

| Name, Type, Description  |

|

`owner` string Required

The account owner of the repository. The name is not case sensitive.

  |

|

`repo` string Required

The name of the repository without the `.git` extension. The name is not case sensitive.

  |

|

`pull_number` integer Required

The number that identifies the pull request.

  |

|

`review_id` integer Required

The unique identifier of the review.

  |

### [HTTP response status codes for "Get a review for a pull request"](#get-a-review-for-a-pull-request--status-codes)

| Status code | Description  |

| `200` |

OK  |

| `404` |

Resource not found  |

### [Code samples for "Get a review for a pull request"](#get-a-review-for-a-pull-request--code-samples)

#### Request example

get/repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}

-
-
-

Copy to clipboard curl request example

`curl -L \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/pulls/PULL_NUMBER/reviews/REVIEW_ID`

####

Response

-
-

`Status: 200`

`{ "id": 80, "node_id": "MDE3OlB1bGxSZXF1ZXN0UmV2aWV3ODA=", "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "body": "Here is the body for the review.", "state": "APPROVED", "html_url": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80", "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/12", "_links": { "html": { "href": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80" }, "pull_request": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/12" } }, "submitted_at": "2019-11-17T17:43:43Z", "commit_id": "ecdd80bb57125d7ba9641ffaa4d7d2c19d3f3091", "author_association": "COLLABORATOR" }`

## [Update a review for a pull request](#update-a-review-for-a-pull-request)

Updates the contents of a specified review summary comment.

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github-commitcomment.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github-commitcomment.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github-commitcomment.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github-commitcomment.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "Update a review for a pull request"](#update-a-review-for-a-pull-request--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Pull requests" repository permissions (write)

### [Parameters for "Update a review for a pull request"](#update-a-review-for-a-pull-request--parameters)

Headers

| Name, Type, Description  |

|

`accept` string

Setting to `application/vnd.github+json` is recommended.

  |

Path parameters

| Name, Type, Description  |

|

`owner` string Required

The account owner of the repository. The name is not case sensitive.

  |

|

`repo` string Required

The name of the repository without the `.git` extension. The name is not case sensitive.

  |

|

`pull_number` integer Required

The number that identifies the pull request.

  |

|

`review_id` integer Required

The unique identifier of the review.

  |

Body parameters

| Name, Type, Description  |

|

`body` string Required

The body text of the pull request review.

  |

### [HTTP response status codes for "Update a review for a pull request"](#update-a-review-for-a-pull-request--status-codes)

| Status code | Description  |

| `200` |

OK  |

| `422` |

Validation failed, or the endpoint has been spammed.  |

### [Code samples for "Update a review for a pull request"](#update-a-review-for-a-pull-request--code-samples)

#### Request example

put/repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}

-
-
-

Copy to clipboard curl request example

`curl -L \ -X PUT \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/pulls/PULL_NUMBER/reviews/REVIEW_ID \ -d '{"body":"This is close to perfect! Please address the suggested inline change. And add more about this."}'`

####

Response

-
-

`Status: 200`

`{ "id": 80, "node_id": "MDE3OlB1bGxSZXF1ZXN0UmV2aWV3ODA=", "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "body": "This is close to perfect! Please address the suggested inline change. And add more about this.", "state": "CHANGES_REQUESTED", "html_url": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80", "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/12", "_links": { "html": { "href": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80" }, "pull_request": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/12" } }, "submitted_at": "2019-11-17T17:43:43Z", "commit_id": "ecdd80bb57125d7ba9641ffaa4d7d2c19d3f3091", "author_association": "COLLABORATOR" }`

## [Delete a pending review for a pull request](#delete-a-pending-review-for-a-pull-request)

Deletes a pull request review that has not been submitted. Submitted reviews cannot be deleted.

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github-commitcomment.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github-commitcomment.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github-commitcomment.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github-commitcomment.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "Delete a pending review for a pull request"](#delete-a-pending-review-for-a-pull-request--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Pull requests" repository permissions (write)

### [Parameters for "Delete a pending review for a pull request"](#delete-a-pending-review-for-a-pull-request--parameters)

Headers

| Name, Type, Description  |

|

`accept` string

Setting to `application/vnd.github+json` is recommended.

  |

Path parameters

| Name, Type, Description  |

|

`owner` string Required

The account owner of the repository. The name is not case sensitive.

  |

|

`repo` string Required

The name of the repository without the `.git` extension. The name is not case sensitive.

  |

|

`pull_number` integer Required

The number that identifies the pull request.

  |

|

`review_id` integer Required

The unique identifier of the review.

  |

### [HTTP response status codes for "Delete a pending review for a pull request"](#delete-a-pending-review-for-a-pull-request--status-codes)

| Status code | Description  |

| `200` |

OK  |

| `404` |

Resource not found  |

| `422` |

Validation failed, or the endpoint has been spammed.  |

### [Code samples for "Delete a pending review for a pull request"](#delete-a-pending-review-for-a-pull-request--code-samples)

#### Request example

delete/repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}

-
-
-

Copy to clipboard curl request example

`curl -L \ -X DELETE \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/pulls/PULL_NUMBER/reviews/REVIEW_ID`

####

Response

-
-

`Status: 200`

`{ "id": 80, "node_id": "MDE3OlB1bGxSZXF1ZXN0UmV2aWV3ODA=", "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "body": "This is close to perfect! Please address the suggested inline change.", "state": "CHANGES_REQUESTED", "html_url": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80", "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/12", "_links": { "html": { "href": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80" }, "pull_request": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/12" } }, "submitted_at": "2019-11-17T17:43:43Z", "commit_id": "ecdd80bb57125d7ba9641ffaa4d7d2c19d3f3091", "author_association": "COLLABORATOR" }`

## [List comments for a pull request review](#list-comments-for-a-pull-request-review)

Lists comments for a specific pull request review.

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github-commitcomment.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github-commitcomment.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github-commitcomment.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github-commitcomment.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "List comments for a pull request review"](#list-comments-for-a-pull-request-review--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Pull requests" repository permissions (read)

This endpoint can be used without authentication or the aforementioned permissions if only public resources are requested.

### [Parameters for "List comments for a pull request review"](#list-comments-for-a-pull-request-review--parameters)

Headers

| Name, Type, Description  |

|

`accept` string

Setting to `application/vnd.github+json` is recommended.

  |

Path parameters

| Name, Type, Description  |

|

`owner` string Required

The account owner of the repository. The name is not case sensitive.

  |

|

`repo` string Required

The name of the repository without the `.git` extension. The name is not case sensitive.

  |

|

`pull_number` integer Required

The number that identifies the pull request.

  |

|

`review_id` integer Required

The unique identifier of the review.

  |

Query parameters

| Name, Type, Description  |

|

`per_page` integer

The number of results per page (max 100). For more information, see "[Using pagination in the REST API](https://docs.github.com/rest/using-the-rest-api/using-pagination-in-the-rest-api)."

Default: `30`  |

|

`page` integer

The page number of the results to fetch. For more information, see "[Using pagination in the REST API](https://docs.github.com/rest/using-the-rest-api/using-pagination-in-the-rest-api)."

Default: `1`  |

### [HTTP response status codes for "List comments for a pull request review"](#list-comments-for-a-pull-request-review--status-codes)

| Status code | Description  |

| `200` |

OK  |

| `404` |

Resource not found  |

### [Code samples for "List comments for a pull request review"](#list-comments-for-a-pull-request-review--code-samples)

#### Request example

get/repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}/comments

-
-
-

Copy to clipboard curl request example

`curl -L \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/pulls/PULL_NUMBER/reviews/REVIEW_ID/comments`

####

Response

-
-

`Status: 200`

`[ { "url": "https://api.github.com/repos/octocat/Hello-World/pulls/comments/1", "pull_request_review_id": 42, "id": 10, "node_id": "MDI0OlB1bGxSZXF1ZXN0UmV2aWV3Q29tbWVudDEw", "diff_hunk": "@@ -16,33 +16,40 @@ public class Connection : IConnection...", "path": "file1.txt", "position": 1, "original_position": 4, "commit_id": "6dcb09b5b57875f334f61aebed695e2e4193db5e", "original_commit_id": "9c48853fa3dc5c1c3d6f1f1cd1f2743e72652840", "in_reply_to_id": 8, "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "body": "Great stuff!", "created_at": "2011-04-14T16:00:49Z", "updated_at": "2011-04-14T16:00:49Z", "html_url": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1", "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/1", "author_association": "NONE", "_links": { "self": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/comments/1" }, "html": { "href": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1" }, "pull_request": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/1" } } } ]`

## [Dismiss a review for a pull request](#dismiss-a-review-for-a-pull-request)

Dismisses a specified review on a pull request.

Note

 To dismiss a pull request review on a [protected branch](https://docs.github.com/rest/branches/branch-protection), you must be a repository administrator or be included in the list of people or teams who can dismiss pull request reviews.

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github-commitcomment.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github-commitcomment.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github-commitcomment.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github-commitcomment.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "Dismiss a review for a pull request"](#dismiss-a-review-for-a-pull-request--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Pull requests" repository permissions (write)

### [Parameters for "Dismiss a review for a pull request"](#dismiss-a-review-for-a-pull-request--parameters)

Headers

| Name, Type, Description  |

|

`accept` string

Setting to `application/vnd.github+json` is recommended.

  |

Path parameters

| Name, Type, Description  |

|

`owner` string Required

The account owner of the repository. The name is not case sensitive.

  |

|

`repo` string Required

The name of the repository without the `.git` extension. The name is not case sensitive.

  |

|

`pull_number` integer Required

The number that identifies the pull request.

  |

|

`review_id` integer Required

The unique identifier of the review.

  |

Body parameters

| Name, Type, Description  |

|

`message` string Required

The message for the pull request review dismissal

  |

|

`event` string

Value: `DISMISS`   |

### [HTTP response status codes for "Dismiss a review for a pull request"](#dismiss-a-review-for-a-pull-request--status-codes)

| Status code | Description  |

| `200` |

OK  |

| `404` |

Resource not found  |

| `422` |

Validation failed, or the endpoint has been spammed.  |

### [Code samples for "Dismiss a review for a pull request"](#dismiss-a-review-for-a-pull-request--code-samples)

#### Request example

put/repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}/dismissals

-
-
-

Copy to clipboard curl request example

`curl -L \ -X PUT \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/pulls/PULL_NUMBER/reviews/REVIEW_ID/dismissals \ -d '{"message":"You are dismissed","event":"DISMISS"}'`

####

Response

-
-

`Status: 200`

`{ "id": 80, "node_id": "MDE3OlB1bGxSZXF1ZXN0UmV2aWV3ODA=", "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "body": "Here is the body for the review.", "state": "DISMISSED", "html_url": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80", "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/12", "_links": { "html": { "href": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80" }, "pull_request": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/12" } }, "submitted_at": "2019-11-17T17:43:43Z", "commit_id": "ecdd80bb57125d7ba9641ffaa4d7d2c19d3f3091", "author_association": "COLLABORATOR" }`

## [Submit a review for a pull request](#submit-a-review-for-a-pull-request)

Submits a pending review for a pull request. For more information about creating a pending review for a pull request, see "[Create a review for a pull request](https://docs.github.com/rest/pulls/reviews#create-a-review-for-a-pull-request)."

This endpoint supports the following custom media types. For more information, see "[Media types](https://docs.github.com/rest/using-the-rest-api/getting-started-with-the-rest-api#media-types)."

- `application/vnd.github-commitcomment.raw+json`: Returns the raw markdown body. Response will include `body`. This is the default if you do not pass any specific media type.
- `application/vnd.github-commitcomment.text+json`: Returns a text only representation of the markdown body. Response will include `body_text`.
- `application/vnd.github-commitcomment.html+json`: Returns HTML rendered from the body's markdown. Response will include `body_html`.
- `application/vnd.github-commitcomment.full+json`: Returns raw, text, and HTML representations. Response will include `body`, `body_text`, and `body_html`.

### [Fine-grained access tokens for "Submit a review for a pull request"](#submit-a-review-for-a-pull-request--fine-grained-access-tokens)

This endpoint works with the following fine-grained token types:

- [GitHub App user access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
- [GitHub App installation access tokens](/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [Fine-grained personal access tokens](/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)

The fine-grained token must have the following permission set:

- "Pull requests" repository permissions (write)

### [Parameters for "Submit a review for a pull request"](#submit-a-review-for-a-pull-request--parameters)

Headers

| Name, Type, Description  |

|

`accept` string

Setting to `application/vnd.github+json` is recommended.

  |

Path parameters

| Name, Type, Description  |

|

`owner` string Required

The account owner of the repository. The name is not case sensitive.

  |

|

`repo` string Required

The name of the repository without the `.git` extension. The name is not case sensitive.

  |

|

`pull_number` integer Required

The number that identifies the pull request.

  |

|

`review_id` integer Required

The unique identifier of the review.

  |

Body parameters

| Name, Type, Description  |

|

`body` string

The body text of the pull request review

  |

|

`event` string Required

The review action you want to perform. The review actions include: `APPROVE`, `REQUEST_CHANGES`, or `COMMENT`. When you leave this blank, the API returns HTTP 422 (Unrecognizable entity) and sets the review action state to `PENDING`, which means you will need to re-submit the pull request review using a review action.

Can be one of: `APPROVE`, `REQUEST_CHANGES`, `COMMENT`   |

### [HTTP response status codes for "Submit a review for a pull request"](#submit-a-review-for-a-pull-request--status-codes)

| Status code | Description  |

| `200` |

OK  |

| `403` |

Forbidden  |

| `404` |

Resource not found  |

| `422` |

Validation failed, or the endpoint has been spammed.  |

### [Code samples for "Submit a review for a pull request"](#submit-a-review-for-a-pull-request--code-samples)

#### Request example

post/repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}/events

-
-
-

Copy to clipboard curl request example

`curl -L \ -X POST \ -H "Accept: application/vnd.github+json" \ -H "Authorization: Bearer <YOUR-TOKEN>" \ -H "X-GitHub-Api-Version: 2026-03-10" \ https://api.github.com/repos/OWNER/REPO/pulls/PULL_NUMBER/reviews/REVIEW_ID/events \ -d '{"body":"Here is the body for the review.","event":"REQUEST_CHANGES"}'`

####

Response

-
-

`Status: 200`

`{ "id": 80, "node_id": "MDE3OlB1bGxSZXF1ZXN0UmV2aWV3ODA=", "user": { "login": "octocat", "id": 1, "node_id": "MDQ6VXNlcjE=", "avatar_url": "https://github.com/images/error/octocat_happy.gif", "gravatar_id": "", "url": "https://api.github.com/users/octocat", "html_url": "https://github.com/octocat", "followers_url": "https://api.github.com/users/octocat/followers", "following_url": "https://api.github.com/users/octocat/following{/other_user}", "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}", "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}", "subscriptions_url": "https://api.github.com/users/octocat/subscriptions", "organizations_url": "https://api.github.com/users/octocat/orgs", "repos_url": "https://api.github.com/users/octocat/repos", "events_url": "https://api.github.com/users/octocat/events{/privacy}", "received_events_url": "https://api.github.com/users/octocat/received_events", "type": "User", "site_admin": false }, "body": "Here is the body for the review.", "state": "APPROVED", "html_url": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80", "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/12", "_links": { "html": { "href": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80" }, "pull_request": { "href": "https://api.github.com/repos/octocat/Hello-World/pulls/12" } }, "submitted_at": "2019-11-17T17:43:43Z", "commit_id": "ecdd80bb57125d7ba9641ffaa4d7d2c19d3f3091", "author_association": "COLLABORATOR" }`
